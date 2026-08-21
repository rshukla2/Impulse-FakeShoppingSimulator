import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/checkout_profile.dart';

abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([
    FlutterSecureStorage? storage,
  ]) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class CheckoutVaultData {
  const CheckoutVaultData({
    this.cards = const [],
    this.addresses = const [],
    this.defaultCardId,
    this.defaultShippingAddressId,
    this.defaultBillingAddressId,
    this.orderSnapshots = const {},
  });

  final List<PaymentCardProfile> cards;
  final List<AddressProfile> addresses;
  final String? defaultCardId;
  final String? defaultShippingAddressId;
  final String? defaultBillingAddressId;
  final Map<String, CheckoutSnapshot> orderSnapshots;

  CheckoutVaultData copyWith({
    List<PaymentCardProfile>? cards,
    List<AddressProfile>? addresses,
    String? defaultCardId,
    String? defaultShippingAddressId,
    String? defaultBillingAddressId,
    Map<String, CheckoutSnapshot>? orderSnapshots,
    bool clearDefaultCard = false,
    bool clearDefaultShipping = false,
    bool clearDefaultBilling = false,
  }) {
    return CheckoutVaultData(
      cards: cards ?? this.cards,
      addresses: addresses ?? this.addresses,
      defaultCardId:
          clearDefaultCard ? null : defaultCardId ?? this.defaultCardId,
      defaultShippingAddressId: clearDefaultShipping
          ? null
          : defaultShippingAddressId ?? this.defaultShippingAddressId,
      defaultBillingAddressId: clearDefaultBilling
          ? null
          : defaultBillingAddressId ?? this.defaultBillingAddressId,
      orderSnapshots: orderSnapshots ?? this.orderSnapshots,
    );
  }

  Map<String, dynamic> toJson() => {
        'cards': cards.map((card) => card.toJson()).toList(),
        'addresses': addresses.map((address) => address.toJson()).toList(),
        'default_card_id': defaultCardId,
        'default_shipping_address_id': defaultShippingAddressId,
        'default_billing_address_id': defaultBillingAddressId,
        'order_snapshots': orderSnapshots.map(
          (orderId, snapshot) => MapEntry(orderId, snapshot.toJson()),
        ),
      };

  factory CheckoutVaultData.fromJson(Map<String, dynamic> json) {
    final rawSnapshots = Map<String, dynamic>.from(
      json['order_snapshots'] as Map? ?? const {},
    );
    return CheckoutVaultData(
      cards: (json['cards'] as List? ?? const [])
          .map((value) => PaymentCardProfile.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .where((card) => card.id.isNotEmpty && card.lastFour.length == 4)
          .toList(growable: false),
      addresses: (json['addresses'] as List? ?? const [])
          .map((value) => AddressProfile.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .where((address) => address.id.isNotEmpty)
          .toList(growable: false),
      defaultCardId: json['default_card_id'] as String?,
      defaultShippingAddressId: json['default_shipping_address_id'] as String?,
      defaultBillingAddressId: json['default_billing_address_id'] as String?,
      orderSnapshots: rawSnapshots.map(
        (orderId, value) => MapEntry(
          orderId,
          CheckoutSnapshot.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
    );
  }
}

class CheckoutVaultService {
  CheckoutVaultService(this._store);

  static const storageKey = 'impulse_checkout_vault_v1';
  final SecureKeyValueStore _store;

  Future<CheckoutVaultData> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return const CheckoutVaultData();
    return CheckoutVaultData.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> save(CheckoutVaultData data) =>
      _store.write(storageKey, jsonEncode(data.toJson()));
}
