import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/local_storage_service.dart';
import 'user_provider.dart';
import 'bootstrap_provider.dart';
import '../core/utils/localized_pricing.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final LocalStorageService _storage;

  CartNotifier(this._storage) : super(_storage.getCart());

  int get totalItemCount => state.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => state.fold(0.0, (sum, item) => sum + item.subtotal);

  void addItem(Product product) {
    final existingIndex = state.indexWhere((i) => i.product.id == product.id);
    if (existingIndex >= 0) {
      final updated = List<CartItem>.from(state);
      updated[existingIndex].quantity += 1;
      state = updated;
    } else {
      state = [...state, CartItem(product: product, quantity: 1)];
    }
    _storage.saveCart(state);
  }

  void incrementQuantity(String productId) {
    final updated = state.map((item) {
      if (item.product.id == productId) {
        return CartItem(product: item.product, quantity: item.quantity + 1);
      }
      return item;
    }).toList();
    state = updated;
    _storage.saveCart(state);
  }

  void decrementQuantity(String productId) {
    final updated = <CartItem>[];
    for (final item in state) {
      if (item.product.id == productId) {
        if (item.quantity > 1) {
          updated.add(
              CartItem(product: item.product, quantity: item.quantity - 1));
        }
        // If quantity is 1 and decremented, it's removed from cart
      } else {
        updated.add(item);
      }
    }
    state = updated;
    _storage.saveCart(state);
  }

  void removeItem(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
    _storage.saveCart(state);
  }

  void clearCart() {
    state = [];
    _storage.saveCart(state);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return CartNotifier(storage);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  final bootstrap = ref.watch(bootstrapProvider).value;
  if (bootstrap == null) {
    return cart.fold(0.0, (sum, item) => sum + item.subtotal);
  }
  return localizedCartTotal(cart, bootstrap);
});

final cartBaseTotalUsdProvider = Provider<double>((ref) {
  return cartBaseTotalUsd(ref.watch(cartProvider));
});
