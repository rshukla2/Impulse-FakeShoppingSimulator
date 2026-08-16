class BootstrapData {
  final String countryCode;
  final String countryName;
  final String currency;
  final String currencySymbol;
  final double exchangeRate;
  final List<Map<String, dynamic>> supportedCountries;

  const BootstrapData({
    required this.countryCode,
    required this.countryName,
    required this.currency,
    required this.currencySymbol,
    required this.exchangeRate,
    required this.supportedCountries,
  });

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    return BootstrapData(
      countryCode: json['country_code'] ?? 'US',
      countryName: json['country_name'] ?? 'United States',
      currency: json['currency'] ?? 'USD',
      currencySymbol: json['currency_symbol'] ?? '\$',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      supportedCountries: (json['supported_countries'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'country_code': countryCode,
        'country_name': countryName,
        'currency': currency,
        'currency_symbol': currencySymbol,
        'exchange_rate': exchangeRate,
        'supported_countries': supportedCountries,
      };
}
