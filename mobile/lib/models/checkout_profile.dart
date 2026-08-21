class PaymentCardProfile {
  const PaymentCardProfile({
    required this.id,
    required this.cardholderName,
    required this.network,
    required this.lastFour,
    required this.expiryMonth,
    required this.expiryYear,
  });

  final String id;
  final String cardholderName;
  final String network;
  final String lastFour;
  final int expiryMonth;
  final int expiryYear;

  String get maskedNumber => '$network ending in $lastFour';
  String get formattedExpiry =>
      '${expiryMonth.toString().padLeft(2, '0')}/${(expiryYear % 100).toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardholder_name': cardholderName,
        'network': network,
        'last_four': lastFour,
        'expiry_month': expiryMonth,
        'expiry_year': expiryYear,
      };

  factory PaymentCardProfile.fromJson(Map<String, dynamic> json) {
    return PaymentCardProfile(
      id: json['id'] as String? ?? '',
      cardholderName: json['cardholder_name'] as String? ?? '',
      network: json['network'] as String? ?? 'Card',
      lastFour: json['last_four'] as String? ?? '',
      expiryMonth: (json['expiry_month'] as num?)?.toInt() ?? 1,
      expiryYear: (json['expiry_year'] as num?)?.toInt() ?? 2000,
    );
  }
}

class AddressProfile {
  const AddressProfile({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    this.region = '',
    this.postalCode = '',
    required this.country,
  });

  final String id;
  final String label;
  final String recipientName;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String region;
  final String postalCode;
  final String country;

  List<String> get formattedLines => [
        recipientName,
        addressLine1,
        if (addressLine2.trim().isNotEmpty) addressLine2,
        [city, region, postalCode]
            .where((value) => value.trim().isNotEmpty)
            .join(', '),
        country,
      ].where((value) => value.trim().isNotEmpty).toList(growable: false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'recipient_name': recipientName,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'region': region,
        'postal_code': postalCode,
        'country': country,
      };

  factory AddressProfile.fromJson(Map<String, dynamic> json) {
    return AddressProfile(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Address',
      recipientName: json['recipient_name'] as String? ?? '',
      addressLine1: json['address_line_1'] as String? ?? '',
      addressLine2: json['address_line_2'] as String? ?? '',
      city: json['city'] as String? ?? '',
      region: json['region'] as String? ?? '',
      postalCode: json['postal_code'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

class CheckoutSnapshot {
  const CheckoutSnapshot({
    required this.card,
    required this.shippingAddress,
    required this.billingAddress,
    required this.billingMatchesShipping,
  });

  final PaymentCardProfile card;
  final AddressProfile shippingAddress;
  final AddressProfile billingAddress;
  final bool billingMatchesShipping;

  Map<String, dynamic> toJson() => {
        'card': card.toJson(),
        'shipping_address': shippingAddress.toJson(),
        'billing_address': billingAddress.toJson(),
        'billing_matches_shipping': billingMatchesShipping,
      };

  factory CheckoutSnapshot.fromJson(Map<String, dynamic> json) {
    return CheckoutSnapshot(
      card: PaymentCardProfile.fromJson(
        Map<String, dynamic>.from(json['card'] as Map? ?? const {}),
      ),
      shippingAddress: AddressProfile.fromJson(
        Map<String, dynamic>.from(
          json['shipping_address'] as Map? ?? const {},
        ),
      ),
      billingAddress: AddressProfile.fromJson(
        Map<String, dynamic>.from(
          json['billing_address'] as Map? ?? const {},
        ),
      ),
      billingMatchesShipping: json['billing_matches_shipping'] as bool? ?? true,
    );
  }
}

String normalizeCardNumber(String value) =>
    value.replaceAll(RegExp(r'[^0-9]'), '');

String inferCardNetwork(String digits) {
  if (RegExp(r'^4').hasMatch(digits)) return 'Visa';
  if (RegExp(r'^(5[1-5]|2(2[2-9]|[3-6][0-9]|7[01]|720))').hasMatch(digits)) {
    return 'Mastercard';
  }
  if (RegExp(r'^3[47]').hasMatch(digits)) return 'American Express';
  if (RegExp(r'^(6011|65|64[4-9])').hasMatch(digits)) return 'Discover';
  if (RegExp(r'^3(0[0-5]|[68])').hasMatch(digits)) return 'Diners Club';
  if (RegExp(r'^35').hasMatch(digits)) return 'JCB';
  if (RegExp(r'^62').hasMatch(digits)) return 'UnionPay';
  return 'Card';
}

bool isPlausibleCardNumber(String value) {
  final digits = normalizeCardNumber(value);
  return digits.length >= 12 && digits.length <= 19;
}

bool isValidExpiry(int month, int year, [DateTime? now]) {
  if (month < 1 || month > 12 || year < 2000) return false;
  final current = now ?? DateTime.now();
  return year > current.year ||
      (year == current.year && month >= current.month);
}
