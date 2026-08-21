import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/checkout_profile.dart';
import '../services/checkout_vault_service.dart';

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return FlutterSecureKeyValueStore();
});

final checkoutVaultServiceProvider = Provider<CheckoutVaultService>((ref) {
  return CheckoutVaultService(ref.watch(secureKeyValueStoreProvider));
});

class CheckoutProfilesState {
  const CheckoutProfilesState({
    this.data = const CheckoutVaultData(),
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage,
  });

  final CheckoutVaultData data;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  CheckoutProfilesState copyWith({
    CheckoutVaultData? data,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckoutProfilesState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  PaymentCardProfile? get defaultCard => _findCard(data.defaultCardId);
  AddressProfile? get defaultShippingAddress =>
      _findAddress(data.defaultShippingAddressId);
  AddressProfile? get defaultBillingAddress =>
      _findAddress(data.defaultBillingAddressId);

  PaymentCardProfile? _findCard(String? id) {
    for (final card in data.cards) {
      if (card.id == id) return card;
    }
    return data.cards.isEmpty ? null : data.cards.first;
  }

  AddressProfile? _findAddress(String? id) {
    for (final address in data.addresses) {
      if (address.id == id) return address;
    }
    return data.addresses.isEmpty ? null : data.addresses.first;
  }
}

class CheckoutProfilesNotifier extends StateNotifier<CheckoutProfilesState> {
  CheckoutProfilesNotifier(this._vault) : super(const CheckoutProfilesState()) {
    reload();
  }

  final CheckoutVaultService _vault;

  Future<void> reload() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _vault.load();
      state = CheckoutProfilesState(data: data, isLoading: false);
    } catch (_) {
      state = const CheckoutProfilesState(
        isLoading: false,
        errorMessage:
            'Secure checkout storage is unavailable. Try again before adding checkout details.',
      );
    }
  }

  Future<bool> _persist(CheckoutVaultData next) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _vault.save(next);
      state = CheckoutProfilesState(data: next, isLoading: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage:
            'Your checkout details could not be saved securely. Nothing was saved.',
      );
      return false;
    }
  }

  Future<bool> saveCard(PaymentCardProfile card) {
    final cards = [...state.data.cards];
    final index = cards.indexWhere((existing) => existing.id == card.id);
    if (index < 0) {
      cards.add(card);
    } else {
      cards[index] = card;
    }
    return _persist(state.data.copyWith(
      cards: cards,
      defaultCardId: state.data.defaultCardId ?? card.id,
    ));
  }

  Future<bool> deleteCard(String id) {
    final cards = state.data.cards.where((card) => card.id != id).toList();
    final nextDefault = state.data.defaultCardId == id
        ? (cards.isEmpty ? null : cards.first.id)
        : state.data.defaultCardId;
    return _persist(state.data.copyWith(
      cards: cards,
      defaultCardId: nextDefault,
      clearDefaultCard: nextDefault == null,
    ));
  }

  Future<bool> setDefaultCard(String id) =>
      _persist(state.data.copyWith(defaultCardId: id));

  Future<bool> saveAddress(AddressProfile address) {
    final addresses = [...state.data.addresses];
    final index = addresses.indexWhere((existing) => existing.id == address.id);
    if (index < 0) {
      addresses.add(address);
    } else {
      addresses[index] = address;
    }
    return _persist(state.data.copyWith(
      addresses: addresses,
      defaultShippingAddressId:
          state.data.defaultShippingAddressId ?? address.id,
      defaultBillingAddressId: state.data.defaultBillingAddressId ?? address.id,
    ));
  }

  Future<bool> deleteAddress(String id) {
    final addresses =
        state.data.addresses.where((address) => address.id != id).toList();
    final fallback = addresses.isEmpty ? null : addresses.first.id;
    final shipping = state.data.defaultShippingAddressId == id
        ? fallback
        : state.data.defaultShippingAddressId;
    final billing = state.data.defaultBillingAddressId == id
        ? fallback
        : state.data.defaultBillingAddressId;
    return _persist(state.data.copyWith(
      addresses: addresses,
      defaultShippingAddressId: shipping,
      defaultBillingAddressId: billing,
      clearDefaultShipping: shipping == null,
      clearDefaultBilling: billing == null,
    ));
  }

  Future<bool> setDefaultShippingAddress(String id) =>
      _persist(state.data.copyWith(defaultShippingAddressId: id));

  Future<bool> setDefaultBillingAddress(String id) =>
      _persist(state.data.copyWith(defaultBillingAddressId: id));

  Future<bool> saveOrderSnapshot(
    String orderId,
    CheckoutSnapshot snapshot,
  ) {
    final snapshots = Map<String, CheckoutSnapshot>.from(
      state.data.orderSnapshots,
    )..[orderId] = snapshot;
    return _persist(state.data.copyWith(orderSnapshots: snapshots));
  }
}

final checkoutProfilesProvider =
    StateNotifierProvider<CheckoutProfilesNotifier, CheckoutProfilesState>(
        (ref) {
  return CheckoutProfilesNotifier(ref.watch(checkoutVaultServiceProvider));
});
