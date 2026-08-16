import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/core/utils/localized_pricing.dart';
import 'package:impulse/models/bootstrap_data.dart';
import 'package:impulse/models/order.dart';
import 'package:impulse/providers/bootstrap_provider.dart';
import 'package:impulse/providers/user_provider.dart';
import 'package:impulse/services/local_storage_service.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical USD savings do not drift across currency round trips',
      () async {
    final prefs = await testPreferences({
      'impulse_money_saved_usd_v2': 12.34,
    });
    final user = UserNotifier(LocalStorageService(prefs));
    const india = BootstrapData(
      countryCode: 'IN',
      countryName: 'India',
      currency: 'INR',
      currencySymbol: '₹',
      exchangeRate: 83,
      supportedCountries: [],
    );
    const us = BootstrapData(
      countryCode: 'US',
      countryName: 'United States',
      currency: 'USD',
      currencySymbol: '\$',
      exchangeRate: 1,
      supportedCountries: [],
    );

    final indiaDisplay = user.state.lifetimeMoneySavedUsd * india.exchangeRate;
    final usDisplay = user.state.lifetimeMoneySavedUsd * us.exchangeRate;

    expect(indiaDisplay, closeTo(1024.22, 0.0001));
    expect(usDisplay, 12.34);
    expect(user.state.lifetimeMoneySavedUsd, 12.34);
    expect(localizedPrice(12.34, india), 1024);
    expect(localizedPrice(12.34, us), 12.34);
  });

  test('legacy orders recover canonical savings and retain order currency',
      () async {
    final legacyOrder = {
      'id': 'legacy-1',
      'created_at': '2026-08-16T12:00:00.000',
      'items': [
        {
          'product': productJson(
            id: 'legacy-product',
            basePriceUsd: 10,
            displayPrice: 830,
            formattedPrice: '₹830',
            currency: 'INR',
            currencySymbol: '₹',
          ),
          'quantity': 2,
        },
      ],
      'total_amount': 1660.0,
      'formatted_total': '₹1,660',
      'currency': 'INR',
      'currency_symbol': '₹',
      'total_items_count': 2,
    };
    final prefs = await testPreferences({
      'impulse_order_history': jsonEncode([legacyOrder]),
      'impulse_money_saved': 999.0,
    });
    final storage = LocalStorageService(prefs);
    final state = UserNotifier(storage).state;
    final order = storage.getOrders().single;

    expect(state.lifetimeMoneySavedUsd, 20);
    expect(order.totalBaseUsd, 20);
    expect(order.currency, 'INR');
    expect(order.formattedTotal, '₹1,660');
    expect(order.items.single.product.currency, 'INR');
    expect(prefs.getDouble('impulse_money_saved_usd_v2'), 20);
  });

  test('legacy savings with no recoverable orders are treated as USD',
      () async {
    final prefs = await testPreferences({
      'impulse_money_saved': 45.5,
      'impulse_order_history': 'corrupt',
    });
    final state = UserNotifier(LocalStorageService(prefs)).state;
    expect(state.lifetimeMoneySavedUsd, 45.5);
  });

  test('offline bootstrap reuses the last success and ignores old override',
      () async {
    final saved = bootstrapJson(
      countryCode: 'GB',
      countryName: 'United Kingdom',
      currency: 'GBP',
      currencySymbol: '£',
      exchangeRate: 0.8,
    );
    final prefs = await testPreferences({
      'impulse_last_bootstrap_v1': jsonEncode(saved),
      'impulse_selected_country': 'IN',
    });
    Map<String, dynamic>? sentQuery;
    final api = testApiClient((options, handler) {
      sentQuery = Map<String, dynamic>.from(options.queryParameters);
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'offline',
        ),
      );
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.read(bootstrapProvider);
    await waitUntil(() => container.read(bootstrapProvider).hasValue);

    final bootstrap = container.read(bootstrapProvider).requireValue;
    expect(sentQuery, isEmpty);
    expect(bootstrap.countryCode, 'GB');
    expect(bootstrap.currency, 'GBP');
    expect(bootstrap.exchangeRate, 0.8);
  });

  test('order JSON remains backward and forward compatible', () {
    final order = SimulatedOrder.fromJson({
      'id': 'order-1',
      'created_at': '2026-08-16T12:00:00.000',
      'items': const [],
      'total_amount': 8.0,
      'formatted_total': '£8.00',
      'currency': 'GBP',
      'currency_symbol': '£',
      'total_items_count': 1,
      'total_base_usd': 10.0,
    });
    final restored = SimulatedOrder.fromJson(order.toJson());
    expect(restored.totalBaseUsd, 10);
    expect(restored.currency, 'GBP');
    expect(restored.formattedTotal, '£8.00');
  });
}
