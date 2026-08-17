import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/providers/bootstrap_provider.dart';
import 'package:impulse/providers/catalog_providers.dart';
import 'package:impulse/providers/user_provider.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog pagination requests 20 records and deduplicates by ID',
      () async {
    final prefs = await testPreferences();
    final shoppingCalls = <Map<String, dynamic>>[];
    final api = testApiClient((options, handler) {
      if (options.path == '/bootstrap') {
        resolveJson(options, handler, bootstrapJson());
        return;
      }
      if (options.path == '/shopping') {
        shoppingCalls.add(Map<String, dynamic>.from(options.queryParameters));
        final page = options.queryParameters['page'] as int;
        resolveJson(options, handler, {
          'items': page == 1
              ? [productJson(id: 'a'), productJson(id: 'b')]
              : [productJson(id: 'b'), productJson(id: 'c')],
          'page': page,
          'total': 3,
          'has_more': page == 1,
        });
        return;
      }
      fail('Unexpected request: ${options.path}');
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

    const params = CatalogParams(
      category: 'Electronics',
      search: 'laptop',
    );
    final provider = shoppingProductsProvider(params);
    final subscription = container.listen(
      provider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await waitUntil(() {
      final state = container.read(provider);
      return state.page == 1 && !state.isLoading;
    });

    await container.read(provider.notifier).loadNextPage();
    final state = container.read(provider);
    expect(state.items.map((item) => item.id).toList(), ['a', 'b', 'c']);
    expect(state.page, 2);
    expect(state.total, 3);
    expect(state.hasMore, isFalse);
    expect(shoppingCalls.first, containsPair('limit', 20));
    expect(shoppingCalls.first, containsPair('page', 1));
    expect(shoppingCalls.first, containsPair('category', 'Electronics'));
    expect(shoppingCalls.first, containsPair('search', 'laptop'));
    expect(shoppingCalls.first, containsPair('country', 'US'));
  });

  test('dynamic categories and food search use backend results', () async {
    final prefs = await testPreferences();
    final api = testApiClient((options, handler) {
      if (options.path == '/bootstrap') {
        resolveJson(options, handler, bootstrapJson());
        return;
      }
      if (options.path == '/categories') {
        resolveJson(options, handler, {
          'shopping_categories': ['All', 'Audio'],
          'grocery_categories': ['All', 'Bakery'],
          'food_cuisines': ['All', 'Japanese'],
        });
        return;
      }
      if (options.path == '/search') {
        expect(options.queryParameters['q'], 'ramen');
        resolveJson(options, handler, {
          'restaurants': [
            {
              'id': 'restaurant-1',
              'name': 'Ramen House',
              'cuisine': 'Japanese',
              'rating': 4.7,
              'review_count': 40,
              'price_level': '\$\$',
            },
          ],
          'food': [
            productJson(
              id: 'dish-1',
              name: 'Miso Ramen',
              type: 'food',
            ),
          ],
        });
        return;
      }
      fail('Unexpected request: ${options.path}');
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
    final categories = await container.read(categoriesProvider.future);
    final results = await container.read(foodSearchProvider('ramen').future);

    expect(categories['shopping'], ['All', 'Audio']);
    expect(categories['groceries'], ['All', 'Bakery']);
    expect(categories['food'], ['All', 'Japanese']);
    expect(results.restaurants.single.name, 'Ramen House');
    expect(results.dishes.single.name, 'Miso Ramen');
  });
}
