import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog_page.dart';
import '../models/product.dart';
import '../models/restaurant.dart';
import 'bootstrap_provider.dart';

class CatalogParams {
  final String? category;
  final String? cuisine;
  final String? search;
  final String? country;

  const CatalogParams({
    this.category,
    this.cuisine,
    this.search,
    this.country,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogParams &&
          category == other.category &&
          cuisine == other.cuisine &&
          search == other.search &&
          country == other.country;

  @override
  int get hashCode => Object.hash(category, cuisine, search, country);
}

class CatalogFeedState {
  final List<Product> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final Object? error;

  const CatalogFeedState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });

  bool get isInitialLoading => isLoading && items.isEmpty;

  CatalogFeedState copyWith({
    List<Product>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return CatalogFeedState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class CatalogFeedNotifier extends StateNotifier<CatalogFeedState> {
  final Ref _ref;
  final String _endpoint;
  final CatalogParams _params;

  CatalogFeedNotifier(this._ref, this._endpoint, this._params)
      : super(const CatalogFeedState()) {
    loadNextPage();
  }

  Future<CatalogPage<Product>> _fetchPage(int page) async {
    final client = _ref.read(apiClientProvider);
    final bootstrap = _ref.read(bootstrapProvider).value;
    final country = _params.country ?? bootstrap?.countryCode;
    final response = await client.dio.get(
      _endpoint,
      queryParameters: {
        if (country != null) 'country': country,
        if (_params.category != null && _params.category != 'All')
          'category': _params.category,
        if (_params.cuisine != null && _params.cuisine != 'All')
          'cuisine': _params.cuisine,
        if (_params.search != null && _params.search!.isNotEmpty)
          'search': _params.search,
        'page': page,
        'limit': 20,
      },
    );
    final rawItems = response.data['items'] as List? ?? const [];
    return CatalogPage(
      items: rawItems.map((item) => Product.fromJson(item)).toList(),
      page: (response.data['page'] as num?)?.toInt() ?? page,
      hasMore: response.data['has_more'] == true,
    );
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _fetchPage(state.page + 1);
      if (!mounted) return;
      final byId = <String, Product>{
        for (final item in state.items) item.id: item,
        for (final item in result.items) item.id: item,
      };
      state = CatalogFeedState(
        items: byId.values.toList(),
        page: result.page,
        hasMore: result.hasMore,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> retry() => loadNextPage();
}

final shoppingProductsProvider = StateNotifierProvider.autoDispose
    .family<CatalogFeedNotifier, CatalogFeedState, CatalogParams>(
        (ref, params) {
  ref.watch(bootstrapProvider);
  return CatalogFeedNotifier(ref, '/shopping', params);
});

final groceriesProvider = StateNotifierProvider.autoDispose
    .family<CatalogFeedNotifier, CatalogFeedState, CatalogParams>(
        (ref, params) {
  ref.watch(bootstrapProvider);
  return CatalogFeedNotifier(ref, '/groceries', params);
});

final foodDishesProvider = StateNotifierProvider.autoDispose
    .family<CatalogFeedNotifier, CatalogFeedState, CatalogParams>(
        (ref, params) {
  ref.watch(bootstrapProvider);
  return CatalogFeedNotifier(ref, '/food', params);
});

final restaurantsProvider =
    FutureProvider.family<List<Restaurant>, CatalogParams>((ref, params) async {
  final client = ref.watch(apiClientProvider);
  final bootstrap = ref.watch(bootstrapProvider).value;
  final country = params.country ?? bootstrap?.countryCode;
  final response = await client.dio.get(
    '/restaurants',
    queryParameters: {
      if (country != null) 'country': country,
      if (params.cuisine != null && params.cuisine != 'All')
        'cuisine': params.cuisine,
    },
  );
  final rawItems = response.data['items'] as List? ?? const [];
  return rawItems.map((item) => Restaurant.fromJson(item)).toList();
});

class FoodSearchResults {
  final List<Restaurant> restaurants;
  final List<Product> dishes;

  const FoodSearchResults({
    required this.restaurants,
    required this.dishes,
  });
}

final foodSearchProvider =
    FutureProvider.family<FoodSearchResults, String>((ref, query) async {
  final client = ref.watch(apiClientProvider);
  final bootstrap = ref.watch(bootstrapProvider).value;
  final response = await client.dio.get(
    '/search',
    queryParameters: {
      'q': query,
      if (bootstrap != null) 'country': bootstrap.countryCode,
    },
  );
  final restaurants = response.data['restaurants'] as List? ?? const [];
  final dishes = response.data['food'] as List? ?? const [];
  return FoodSearchResults(
    restaurants: restaurants.map((item) => Restaurant.fromJson(item)).toList(),
    dishes: dishes.map((item) => Product.fromJson(item)).toList(),
  );
});

final restaurantDetailProvider =
    FutureProvider.family<Restaurant, String>((ref, restaurantId) async {
  final client = ref.watch(apiClientProvider);
  final bootstrap = ref.watch(bootstrapProvider).value;
  final response = await client.dio.get(
    '/restaurants/$restaurantId',
    queryParameters: {
      if (bootstrap != null) 'country': bootstrap.countryCode,
    },
  );
  return Restaurant.fromJson(response.data);
});

final categoriesProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get('/categories');
  return {
    'shopping':
        List<String>.from(response.data['shopping_categories'] ?? const []),
    'groceries':
        List<String>.from(response.data['grocery_categories'] ?? const []),
    'food': List<String>.from(response.data['food_cuisines'] ?? const []),
  };
});
