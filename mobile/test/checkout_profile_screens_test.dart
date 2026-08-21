import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/core/theme/app_theme.dart';
import 'package:impulse/providers/bootstrap_provider.dart';
import 'package:impulse/providers/checkout_profiles_provider.dart';
import 'package:impulse/providers/user_provider.dart';
import 'package:impulse/screens/settings/addresses_screen.dart';
import 'package:impulse/screens/settings/wallet_screen.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Wallet saves only a masked card profile', (tester) async {
    final store = MemorySecureStore();
    final container = ProviderContainer(
      overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const WalletScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Card'));
    await tester.pumpAndSettle();

    expect(find.text('Cardholder Name'), findsOneWidget);
    expect(find.text('Card Number'), findsOneWidget);
    expect(find.textContaining('CVV'), findsNothing);
    expect(find.textContaining('security code'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cardholder Name'),
      'Rishi Shukla',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Card Number'),
      '4242 4242 4242 4242',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Card'));
    await tester.pumpAndSettle();

    expect(find.text('Visa ending in 4242'), findsOneWidget);
    expect(store.values.values.join(), isNot(contains('4242424242424242')));
  });

  testWidgets('Addresses supports local address creation', (tester) async {
    final store = MemorySecureStore();
    final prefs = await testPreferences();
    final api = testApiClient((options, handler) {
      expect(options.path, '/bootstrap');
      resolveJson(options, handler, bootstrapJson());
    });
    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(api),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AddressesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Address'));
    await tester.pumpAndSettle();

    Future<void> enter(String label, String value) => tester.enterText(
          find.widgetWithText(TextFormField, label),
          value,
        );
    await enter('Recipient Name', 'Rishi Shukla');
    await enter('Address Line 1', '123 Main Street');
    await enter('City', 'Chicago');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Address'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('123 Main Street'), findsOneWidget);
    expect(find.textContaining('Default shipping'), findsOneWidget);
    expect(find.textContaining('Default billing'), findsOneWidget);
  });
}
