import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/bootstrap_data.dart';
import 'user_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class BootstrapNotifier extends StateNotifier<AsyncValue<BootstrapData>> {
  final ApiClient _client;
  final Ref _ref;

  BootstrapNotifier(this._client, this._ref)
      : super(const AsyncValue.loading()) {
    fetchBootstrap();
  }

  Future<void> fetchBootstrap() async {
    state = const AsyncValue.loading();
    try {
      final storage = _ref.read(localStorageServiceProvider);
      final response = await _client.dio.get('/bootstrap');

      final data = BootstrapData.fromJson(response.data);
      await storage.saveLastBootstrap(data);
      state = AsyncValue.data(data);
    } catch (_) {
      final saved = _ref.read(localStorageServiceProvider).getLastBootstrap();
      state = AsyncValue.data(
        saved ??
            const BootstrapData(
              countryCode: 'US',
              countryName: 'United States',
              currency: 'USD',
              currencySymbol: '\$',
              exchangeRate: 1.0,
              supportedCountries: [
                {
                  'code': 'US',
                  'name': 'United States',
                  'currency': 'USD',
                  'symbol': '\$'
                },
                {
                  'code': 'IN',
                  'name': 'India',
                  'currency': 'INR',
                  'symbol': '₹'
                },
                {
                  'code': 'GB',
                  'name': 'United Kingdom',
                  'currency': 'GBP',
                  'symbol': '£'
                },
                {
                  'code': 'JP',
                  'name': 'Japan',
                  'currency': 'JPY',
                  'symbol': '¥'
                },
                {
                  'code': 'DE',
                  'name': 'Germany',
                  'currency': 'EUR',
                  'symbol': '€'
                },
              ],
            ),
      );
    }
  }
}

final bootstrapProvider =
    StateNotifierProvider<BootstrapNotifier, AsyncValue<BootstrapData>>((ref) {
  final client = ref.watch(apiClientProvider);
  return BootstrapNotifier(client, ref);
});
