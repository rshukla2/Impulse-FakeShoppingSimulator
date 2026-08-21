import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/models/checkout_profile.dart';
import 'package:impulse/providers/checkout_profiles_provider.dart';
import 'package:impulse/services/checkout_vault_service.dart';

import 'test_support.dart';

void main() {
  group('card profile normalization', () {
    test('normalizes input and identifies common networks without Luhn', () {
      expect(normalizeCardNumber('4242 4242-4242 4242'), '4242424242424242');
      expect(inferCardNetwork('4242424242424242'), 'Visa');
      expect(inferCardNetwork('5555555555554444'), 'Mastercard');
      expect(inferCardNetwork('378282246310005'), 'American Express');
      expect(inferCardNetwork('123456789012'), 'Card');
      expect(isPlausibleCardNumber('1234 5678 9012'), isTrue);
      expect(isPlausibleCardNumber('1234'), isFalse);
    });

    test('validates expiration month and current date', () {
      final now = DateTime(2026, 8, 18);
      expect(isValidExpiry(8, 2026, now), isTrue);
      expect(isValidExpiry(7, 2026, now), isFalse);
      expect(isValidExpiry(13, 2030, now), isFalse);
    });
  });

  test('secure vault round-trips profiles, defaults, and snapshots', () async {
    final store = MemorySecureStore();
    final service = CheckoutVaultService(store);
    const card = PaymentCardProfile(
      id: 'card-1',
      cardholderName: 'Rishi Shukla',
      network: 'Visa',
      lastFour: '4242',
      expiryMonth: 12,
      expiryYear: 2030,
    );
    const address = AddressProfile(
      id: 'address-1',
      label: 'Home',
      recipientName: 'Rishi Shukla',
      addressLine1: '123 Main Street',
      city: 'Chicago',
      region: 'Illinois',
      postalCode: '60601',
      country: 'United States',
    );
    const snapshot = CheckoutSnapshot(
      card: card,
      shippingAddress: address,
      billingAddress: address,
      billingMatchesShipping: true,
    );
    const data = CheckoutVaultData(
      cards: [card],
      addresses: [address],
      defaultCardId: 'card-1',
      defaultShippingAddressId: 'address-1',
      defaultBillingAddressId: 'address-1',
      orderSnapshots: {'order-1': snapshot},
    );

    await service.save(data);
    final loaded = await service.load();

    expect(loaded.cards.single.maskedNumber, 'Visa ending in 4242');
    expect(loaded.addresses.single.city, 'Chicago');
    expect(loaded.orderSnapshots['order-1']?.card.lastFour, '4242');
    final raw = store.values[CheckoutVaultService.storageKey]!;
    expect(raw, isNot(contains('4242424242424242')));
    expect(jsonDecode(raw), isA<Map<String, dynamic>>());
  });

  test('corrupt secure vault data fails instead of using plaintext fallback',
      () async {
    final service = CheckoutVaultService(MemorySecureStore({
      CheckoutVaultService.storageKey: 'not-json',
    }));
    expect(service.load(), throwsA(isA<FormatException>()));
  });

  test('checkout profile code has no backend or HTTP dependency', () {
    const paths = [
      'lib/models/checkout_profile.dart',
      'lib/providers/checkout_profiles_provider.dart',
      'lib/services/checkout_vault_service.dart',
      'lib/screens/checkout/checkout_profile_forms.dart',
      'lib/screens/settings/wallet_screen.dart',
      'lib/screens/settings/addresses_screen.dart',
    ];
    final source = paths.map((path) => File(path).readAsStringSync()).join();
    expect(source, isNot(contains('package:dio/')));
    expect(source, isNot(contains('ApiClient')));
    expect(source, isNot(contains('http://')));
    expect(source, isNot(contains('https://')));
  });

  test('deleting reusable profiles keeps completed order snapshots', () async {
    final store = MemorySecureStore();
    final container = ProviderContainer(
      overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await waitUntil(() => !container.read(checkoutProfilesProvider).isLoading);
    const card = PaymentCardProfile(
      id: 'card-1',
      cardholderName: 'Rishi Shukla',
      network: 'Visa',
      lastFour: '4242',
      expiryMonth: 12,
      expiryYear: 2030,
    );
    const address = AddressProfile(
      id: 'address-1',
      label: 'Home',
      recipientName: 'Rishi Shukla',
      addressLine1: '123 Main Street',
      city: 'Chicago',
      country: 'United States',
    );
    const snapshot = CheckoutSnapshot(
      card: card,
      shippingAddress: address,
      billingAddress: address,
      billingMatchesShipping: true,
    );
    final notifier = container.read(checkoutProfilesProvider.notifier);
    expect(await notifier.saveCard(card), isTrue);
    expect(await notifier.saveAddress(address), isTrue);
    expect(await notifier.saveOrderSnapshot('order-1', snapshot), isTrue);

    expect(await notifier.deleteCard(card.id), isTrue);
    expect(await notifier.deleteAddress(address.id), isTrue);

    final data = container.read(checkoutProfilesProvider).data;
    expect(data.cards, isEmpty);
    expect(data.addresses, isEmpty);
    expect(data.orderSnapshots['order-1']?.card.lastFour, '4242');
    expect(data.orderSnapshots['order-1']?.shippingAddress.city, 'Chicago');
  });

  test('secure write failure is surfaced and does not update profile state',
      () async {
    final store = MemorySecureStore()..writeError = StateError('unavailable');
    final container = ProviderContainer(
      overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await waitUntil(() => !container.read(checkoutProfilesProvider).isLoading);
    const card = PaymentCardProfile(
      id: 'card-1',
      cardholderName: 'Rishi Shukla',
      network: 'Visa',
      lastFour: '4242',
      expiryMonth: 12,
      expiryYear: 2030,
    );

    expect(
      await container.read(checkoutProfilesProvider.notifier).saveCard(card),
      isFalse,
    );
    final state = container.read(checkoutProfilesProvider);
    expect(state.data.cards, isEmpty);
    expect(state.errorMessage, contains('could not be saved securely'));
  });
}
