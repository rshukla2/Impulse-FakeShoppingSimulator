import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../services/local_storage_service.dart';
import 'user_provider.dart';

class OrdersNotifier extends StateNotifier<List<SimulatedOrder>> {
  final LocalStorageService _storage;

  OrdersNotifier(this._storage) : super(_storage.getOrders());

  Future<void> addOrder(SimulatedOrder order) async {
    // Newest orders first
    final updated = [order, ...state];
    state = updated;
    await _storage.saveOrders(updated);
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, List<SimulatedOrder>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return OrdersNotifier(storage);
});
