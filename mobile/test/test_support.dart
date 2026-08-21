import 'package:dio/dio.dart';
import 'package:impulse/core/network/api_client.dart';
import 'package:impulse/services/checkout_vault_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef TestRequestHandler = void Function(
  RequestOptions options,
  RequestInterceptorHandler handler,
);

class MemorySecureStore implements SecureKeyValueStore {
  MemorySecureStore([Map<String, String>? values])
      : values = Map<String, String>.from(values ?? const {});

  final Map<String, String> values;
  Object? readError;
  Object? writeError;

  @override
  Future<String?> read(String key) async {
    if (readError != null) throw readError!;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (writeError != null) throw writeError!;
    values[key] = value;
  }
}

ApiClient testApiClient(TestRequestHandler onRequest) {
  final client = ApiClient(baseUrl: 'https://impulse.test');
  client.dio.interceptors.add(
    InterceptorsWrapper(onRequest: onRequest),
  );
  return client;
}

void resolveJson(
  RequestOptions options,
  RequestInterceptorHandler handler,
  Object data,
) {
  handler.resolve(
    Response<Object>(
      requestOptions: options,
      statusCode: 200,
      data: data,
    ),
  );
}

Map<String, Object> bootstrapJson({
  String countryCode = 'US',
  String countryName = 'United States',
  String currency = 'USD',
  String currencySymbol = '\$',
  double exchangeRate = 1,
}) {
  return {
    'country_code': countryCode,
    'country_name': countryName,
    'currency': currency,
    'currency_symbol': currencySymbol,
    'exchange_rate': exchangeRate,
    'supported_countries': const [],
  };
}

Map<String, Object?> productJson({
  required String id,
  String name = 'Test Product',
  String type = 'shopping',
  double basePriceUsd = 10,
  double displayPrice = 10,
  String formattedPrice = '\$10.00',
  String currency = 'USD',
  String currencySymbol = '\$',
}) {
  return {
    'id': id,
    'type': type,
    'name': name,
    'brand': 'Test Brand',
    'category': 'Test',
    'description': 'A test catalog item.',
    'source': 'local',
    'base_price_usd': basePriceUsd,
    'display_price': displayPrice,
    'formatted_price': formattedPrice,
    'currency': currency,
    'currency_symbol': currencySymbol,
    'rating': 4.5,
    'review_count': 12,
    'is_fictional': false,
  };
}

Future<SharedPreferences> testPreferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw StateError('Timed out waiting for test condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
