import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_storage_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main() via ProviderScope override');
});

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorageService(prefs);
});

class UserState {
  final String name;
  final bool isOnboarded;
  final double lifetimeMoneySavedUsd;
  final int fakeOrdersCount;
  final int itemsNotBoughtCount;

  const UserState({
    required this.name,
    required this.isOnboarded,
    required this.lifetimeMoneySavedUsd,
    required this.fakeOrdersCount,
    required this.itemsNotBoughtCount,
  });

  UserState copyWith({
    String? name,
    bool? isOnboarded,
    double? lifetimeMoneySavedUsd,
    int? fakeOrdersCount,
    int? itemsNotBoughtCount,
  }) {
    return UserState(
      name: name ?? this.name,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      lifetimeMoneySavedUsd:
          lifetimeMoneySavedUsd ?? this.lifetimeMoneySavedUsd,
      fakeOrdersCount: fakeOrdersCount ?? this.fakeOrdersCount,
      itemsNotBoughtCount: itemsNotBoughtCount ?? this.itemsNotBoughtCount,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final LocalStorageService _storage;

  UserNotifier(this._storage)
      : super(UserState(
          name: _storage.getUserName() ?? 'Shopper',
          isOnboarded: _storage.isOnboarded(),
          lifetimeMoneySavedUsd: _initialLifetimeSavedUsd(_storage),
          fakeOrdersCount: _storage.getFakeOrdersCount(),
          itemsNotBoughtCount: _storage.getItemsNotBoughtCount(),
        )) {
    if (_storage.getLifetimeMoneySavedUsd() == null) {
      _storage.setLifetimeMoneySavedUsd(state.lifetimeMoneySavedUsd);
    }
  }

  static double _initialLifetimeSavedUsd(LocalStorageService storage) {
    final storedUsd = storage.getLifetimeMoneySavedUsd();
    if (storedUsd != null) return storedUsd;

    final orders = storage.getOrders();
    if (orders.isNotEmpty) {
      return orders.fold<double>(
        0,
        (sum, order) => sum + order.totalBaseUsd,
      );
    }
    // Final compatibility fallback for legacy state with no recoverable orders.
    return storage.getLifetimeMoneySaved();
  }

  Future<void> setUserName(String name) async {
    final clean = name.trim().isEmpty ? 'Shopper' : name.trim();
    await _storage.setUserName(clean);
    await _storage.setOnboarded(true);
    state = state.copyWith(name: clean, isOnboarded: true);
  }

  Future<void> recordSimulatedOrder({
    required double orderTotalBaseUsd,
    required int itemCount,
  }) async {
    final newSaved = state.lifetimeMoneySavedUsd + orderTotalBaseUsd;
    final newOrders = state.fakeOrdersCount + 1;
    final newItems = state.itemsNotBoughtCount + itemCount;

    await _storage.setLifetimeMoneySavedUsd(newSaved);
    await _storage.setFakeOrdersCount(newOrders);
    await _storage.setItemsNotBoughtCount(newItems);

    state = state.copyWith(
      lifetimeMoneySavedUsd: newSaved,
      fakeOrdersCount: newOrders,
      itemsNotBoughtCount: newItems,
    );
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return UserNotifier(storage);
});
