import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:impulse/core/network/static_demo_interceptor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StaticDemoInterceptor', () {
    late Dio dio;

    setUpAll(() async {
      // Initialize the interceptor's static data
      await StaticDemoInterceptor.init();
    });

    setUp(() {
      dio = Dio(
        BaseOptions(
          baseUrl: 'http://localhost',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      dio.interceptors.add(StaticDemoInterceptor());
    });

    test('should return healthy status for /health', () async {
      final response = await dio.get('/health');
      expect(response.statusCode, 200);
      expect(response.data['status'], 'healthy');
      expect(response.data['mode'], 'static_demo');
    });

    test('/bootstrap?country=IN returns INR', () async {
      final response = await dio.get('/bootstrap', queryParameters: {'country': 'IN'});
      expect(response.statusCode, 200);
      expect(response.data['currency'], 'INR');
      expect(response.data['currency_symbol'], '₹');
    });

    test('/shopping paginates correctly', () async {
      final response = await dio.get('/shopping', queryParameters: {'page': 1, 'limit': 20});
      expect(response.statusCode, 200);

      final data = response.data;
      expect(data['items'].length, 20);
      expect(data['page'], 1);
      expect(data['limit'], 20);
      expect(data['has_more'], true);
      expect(data['total'] > 20, true);
    });

    test('/shopping filters by category', () async {
      final response = await dio.get('/shopping', queryParameters: {'category': 'Electronics'});
      expect(response.statusCode, 200);

      final items = response.data['items'] as List;
      for (final item in items) {
        expect(item['category'], 'Electronics');
      }
    });

    test('/shopping filters by search', () async {
      final response = await dio.get('/shopping', queryParameters: {'search': 'apple'});
      expect(response.statusCode, 200);

      final items = response.data['items'] as List;
      // At least one item should contain 'apple' in name, brand, category, or description
      final hasAppleItem = items.any((item) {
        final name = ((item['name'] as String?) ?? '').toLowerCase();
        final brand = ((item['brand'] as String?) ?? '').toLowerCase();
        final cat = ((item['category'] as String?) ?? '').toLowerCase();
        final desc = ((item['description'] as String?) ?? '').toLowerCase();
        return name.contains('apple') || brand.contains('apple') || cat.contains('apple') || desc.contains('apple');
      });
      expect(hasAppleItem, true);
    });

    test('/restaurants returns items', () async {
      final response = await dio.get('/restaurants', queryParameters: {'country': 'US'});
      expect(response.statusCode, 200);
      expect(response.data['items'] is List, true);
      expect(response.data['items'].isNotEmpty, true);
    });

    test('/restaurants/<id> returns restaurant details', () async {
      // First get restaurants to find a valid ID
      final restaurantsResponse = await dio.get('/restaurants', queryParameters: {'country': 'US'});
      if (restaurantsResponse.data['items'] is List && restaurantsResponse.data['items'].isNotEmpty) {
        final id = restaurantsResponse.data['items'][0]['id'] as String;
        final response = await dio.get('/restaurants/$id');
        expect(response.statusCode, 200);
        expect(response.data['id'], id);
      }
    });

    test('/restaurants/<nonexistent> returns 404', () async {
      try {
        await dio.get('/restaurants/nonexistent_id_12345');
        fail('Should have thrown DioException');
      } on DioException catch (e) {
        expect(e.response != null ? e.response!.statusCode : 404, 404);
      }
    });

    test('/food/<id> returns food item', () async {
      final response = await dio.get('/food', queryParameters: {'country': 'US', 'category': 'All'});
      expect(response.statusCode, 200);

      final items = response.data['items'] as List;
      if (items.isNotEmpty) {
        final id = items[0]['id'] as String;
        final foodResponse = await dio.get('/food/$id');
        expect(foodResponse.statusCode, 200);
        expect(foodResponse.data['id'], id);
      }
    });

    test('/categories returns categories', () async {
      final response = await dio.get('/categories', queryParameters: {'country': 'US'});
      expect(response.statusCode, 200);
      expect(response.data['shopping_categories'] is List, true);
      expect(response.data['grocery_categories'] is List, true);
      expect(response.data['food_cuisines'] is List, true);
    });

    test('/search with q returns items from all categories', () async {
      final response = await dio.get('/search', queryParameters: {'q': 'test'});
      expect(response.statusCode, 200);

      final data = response.data;
      expect(data['shopping'] is List, true);
      expect(data['groceries'] is List, true);
      expect(data['food'] is List, true);
      expect(data['restaurants'] is List, true);
    });

    test('/shopping?country=IN prices are in INR', () async {
      final response = await dio.get('/shopping', queryParameters: {'country': 'IN', 'page': 1, 'limit': 5});
      expect(response.statusCode, 200);

      final items = response.data['items'] as List;
      for (final item in items) {
        expect(item['currency'], 'INR');
        expect(item['currency_symbol'], '₹');

        final basePrice = item['base_price_usd'] as num;
        final displayPrice = item['display_price'] as num;

        // display_price should be approximately base_price_usd * exchange_rate (92.83)
        final expected = basePrice * 92.83;
        final diff = (displayPrice - expected).abs();

        // Allow some tolerance for rounding
        expect(diff < 1.0, true, reason: 'Price for ${item['name']} should be close to USD*rate');
      }
    });

    test('/groceries returns items', () async {
      final response = await dio.get('/groceries', queryParameters: {'country': 'US'});
      expect(response.statusCode, 200);
      expect(response.data['items'] is List, true);
    });

    test('/food returns items', () async {
      final response = await dio.get('/food', queryParameters: {'country': 'US'});
      expect(response.statusCode, 200);
      expect(response.data['items'] is List, true);
    });

    test('/categories has non-empty shopping categories', () async {
      final r = await dio.get('/categories', queryParameters: {'country': 'US'});
      expect((r.data['shopping_categories'] as List).length, greaterThan(1));
      expect((r.data['food_cuisines'] as List).isNotEmpty, true);
    });

    test('fallback country (BR) groceries are localized to BRL', () async {
      final r = await dio.get('/groceries', queryParameters: {'country': 'BR'});
      final items = r.data['items'] as List;
      expect(items.isNotEmpty, true);
      expect(items.first['currency'], 'BRL');
    });

    test('/search shopping prices are localized for IN', () async {
      final r = await dio.get('/search', queryParameters: {'q': 'a', 'country': 'IN'});
      final shopping = r.data['shopping'] as List;
      expect(shopping.isNotEmpty, true);
      expect(shopping.first['currency'], 'INR');
    });

    test('unknown path returns 404', () async {
      try {
        await dio.get('/unknown/path/that/does/not/exist');
        fail('Should have thrown DioException');
      } on DioException catch (e) {
        expect(e.response != null ? e.response!.statusCode : 404, 404);
      }
    });
  });
}
