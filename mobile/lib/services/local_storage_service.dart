import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/bootstrap_data.dart';

class LocalStorageService {
  static const String _keyUserName = 'impulse_user_name';
  static const String _keyOnboarded = 'impulse_is_onboarded';
  static const String _keyCartItems = 'impulse_cart_items';
  static const String _keyOrderHistory = 'impulse_order_history';
  static const String _keyMoneySaved = 'impulse_money_saved';
  static const String _keyFakeOrdersCount = 'impulse_fake_orders_count';
  static const String _keyItemsNotBoughtCount = 'impulse_items_not_bought';
  static const String _keySelectedCountry = 'impulse_selected_country';
  static const String _keyMoneySavedUsdV2 = 'impulse_money_saved_usd_v2';
  static const String _keyLastBootstrapV1 = 'impulse_last_bootstrap_v1';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  // User Profile
  String? getUserName() => _prefs.getString(_keyUserName);
  Future<bool> setUserName(String name) => _prefs.setString(_keyUserName, name);

  bool isOnboarded() => _prefs.getBool(_keyOnboarded) ?? false;
  Future<bool> setOnboarded(bool value) => _prefs.setBool(_keyOnboarded, value);

  // Country Override
  String? getSelectedCountry() => _prefs.getString(_keySelectedCountry);
  Future<bool> setSelectedCountry(String code) =>
      _prefs.setString(_keySelectedCountry, code);

  // Cart
  List<CartItem> getCart() {
    final raw = _prefs.getString(_keyCartItems);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((item) => CartItem.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveCart(List<CartItem> items) {
    final raw = json.encode(items.map((i) => i.toJson()).toList());
    return _prefs.setString(_keyCartItems, raw);
  }

  // Orders
  List<SimulatedOrder> getOrders() {
    final raw = _prefs.getString(_keyOrderHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((item) => SimulatedOrder.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveOrders(List<SimulatedOrder> orders) {
    final raw = json.encode(orders.map((o) => o.toJson()).toList());
    return _prefs.setString(_keyOrderHistory, raw);
  }

  // Statistics
  double getLifetimeMoneySaved() => _prefs.getDouble(_keyMoneySaved) ?? 0.0;
  Future<bool> setLifetimeMoneySaved(double value) =>
      _prefs.setDouble(_keyMoneySaved, value);

  double? getLifetimeMoneySavedUsd() => _prefs.getDouble(_keyMoneySavedUsdV2);
  Future<bool> setLifetimeMoneySavedUsd(double value) =>
      _prefs.setDouble(_keyMoneySavedUsdV2, value);

  BootstrapData? getLastBootstrap() {
    final raw = _prefs.getString(_keyLastBootstrapV1);
    if (raw == null || raw.isEmpty) return null;
    try {
      return BootstrapData.fromJson(
        Map<String, dynamic>.from(json.decode(raw)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveLastBootstrap(BootstrapData data) =>
      _prefs.setString(_keyLastBootstrapV1, json.encode(data.toJson()));

  int getFakeOrdersCount() => _prefs.getInt(_keyFakeOrdersCount) ?? 0;
  Future<bool> setFakeOrdersCount(int count) =>
      _prefs.setInt(_keyFakeOrdersCount, count);

  int getItemsNotBoughtCount() => _prefs.getInt(_keyItemsNotBoughtCount) ?? 0;
  Future<bool> setItemsNotBoughtCount(int count) =>
      _prefs.setInt(_keyItemsNotBoughtCount, count);
}
