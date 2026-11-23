import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../utils/currency_formatter.dart';

/// Static Demo Interceptor - serves data from pre-generated JSON assets
/// without any network calls. Used for GitHub Pages deployment.
class StaticDemoInterceptor extends Interceptor {
  // Cached data loaded from assets
  static Map<String, dynamic>? _bootstrapData;
  static List<Map<String, dynamic>>? _shoppingData;
  static Map<String, dynamic>? _regionDataUS;
  static Map<String, dynamic>? _regionDataIN;
  static Map<String, dynamic>? _regionDataGB;
  static Map<String, dynamic>? _regionDataJP;
  static Map<String, dynamic>? _regionDataDE;
  static Map<String, dynamic>? _regionDataFR;
  static Map<String, dynamic>? _regionDataCA;
  static Map<String, dynamic>? _regionDataAU;

  static final Set<String> _regionCountries = {'US', 'IN', 'GB', 'JP', 'DE', 'FR', 'CA', 'AU'};

  /// Initialize the interceptor by loading all data from assets.
  /// This should be called once before making any requests.
  static Future<void> init() async {
    await _ensureLoaded();
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Never hit the network - resolve immediately from assets
    try {
      final response = await _resolveRequest(options);
      handler.resolve(response);
    } catch (e, stackTrace) {
      handler.reject(DioException(
        error: e,
        stackTrace: stackTrace,
        requestOptions: options,
        type: DioExceptionType.unknown,
      ));
    }
  }

  static Future<Response> _resolveRequest(RequestOptions options) async {
    final path = options.path;
    final query = options.queryParameters;

    // Always use the 'country' query param, default to 'US'
    final country = (query['country'] as String?)?.toUpperCase() ?? 'US';
    final region = _regionCountries.contains(country) ? country : 'US';

    switch (path) {
      case '/health':
        return _buildResponse({
          'status': 'healthy',
          'mode': 'static_demo',
        });

      case '/bootstrap':
        return await _handleBootstrap(country);

      case '/shopping':
      case '/groceries':
      case '/food':
        return await _handleCatalog(path, country, region, query);

      case '/restaurants':
        return await _handleRestaurants(region, query);

      case '/categories':
        return await _handleCategories(region);

      case '/search':
        return await _handleSearch(country, region, query);

      default:
        // Check for /restaurants/<id> pattern
        if (path.startsWith('/restaurants/')) {
          final id = path.substring('/restaurants/'.length);
          return await _handleRestaurantDetail(country, region, id);
        }
        // Check for /food/<id> pattern
        if (path.startsWith('/food/')) {
          final id = path.substring('/food/'.length);
          return await _handleFoodDetail(country, region, id);
        }

        throw DioException(
          requestOptions: options,
          error: 'Not found: $path',
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 404,
            requestOptions: options,
          ),
        );
    }
  }

  static Future<void> _ensureLoaded() async {
    if (_bootstrapData != null) return;

    // Load bootstrap.json
    final bootstrapStr = await rootBundle.loadString('assets/static_demo/bootstrap.json');
    _bootstrapData = json.decode(bootstrapStr);

    // Load shopping.json
    final shoppingStr = await rootBundle.loadString('assets/static_demo/shopping.json');
    _shoppingData = List<Map<String, dynamic>>.from(json.decode(shoppingStr));
  }

  static Response _buildResponse(dynamic data) {
    return Response(
      statusCode: 200,
      data: data,
      requestOptions: RequestOptions(),
      headers: Headers(),
    );
  }

  static Future<Response> _handleBootstrap(String country) async {
    await _ensureLoaded();
    final countries = (_bootstrapData!['countries'] as Map<String, dynamic>);

    // Get country-specific data or fallback to US
    final countryData = countries[country] ?? countries['US']!;
    final supportedCountries = (_bootstrapData!['supported_countries'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return _buildResponse({
      'country_code': countryData['country_code'],
      'country_name': countryData['country_name'],
      'currency': countryData['currency'],
      'currency_symbol': countryData['currency_symbol'],
      'exchange_rate': countryData['exchange_rate'],
      'supported_countries': supportedCountries,
    });
  }

  static Future<Response> _handleCatalog(
    String endpoint,
    String country,
    String region,
    Map<String, dynamic> query,
  ) async {
    await _ensureLoaded();
    final countries = (_bootstrapData!['countries'] as Map<String, dynamic>);

    // Get country data for localization
    final countryData = countries[country] ?? countries['US']!;
    final exchangeRate = (countryData['exchange_rate'] as num).toDouble();
    final currency = countryData['currency'] as String;
    final currencySymbol = countryData['currency_symbol'] as String;

    // Determine which dataset to use
    List<Map<String, dynamic>> items;
    String? regionKey;

    if (endpoint == '/groceries') {
      regionKey = 'groceries';
    } else if (endpoint == '/food') {
      regionKey = 'food';
    } else {
      // /shopping - use shopping.json
      regionKey = null;
    }

    if (regionKey != null) {
      // Load region data if needed
      final regionData = await _loadRegionData(region);
      items = List<Map<String, dynamic>>.from(regionData[regionKey] ?? []);
    } else {
      items = List<Map<String, dynamic>>.from(_shoppingData!);
    }

    // Filter by category
    final category = query['category'] as String?;
    if (category != null && category != 'All') {
      items = items.where((item) {
        final itemCategory = item['category'] as String? ?? '';
        return itemCategory.toLowerCase() == category.toLowerCase();
      }).toList();
    }

    // Filter by cuisine
    final cuisine = query['cuisine'] as String?;
    if (cuisine != null && cuisine != 'All') {
      items = items.where((item) {
        final itemCuisine = item['cuisine'] as String? ?? '';
        return itemCuisine.toLowerCase() == cuisine.toLowerCase();
      }).toList();
    }

    // Filter by search
    final search = query['search'] as String?;
    if (search != null && search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      items = items.where((item) {
        final name = (item['name'] as String? ?? '').toLowerCase();
        final brand = (item['brand'] as String? ?? '').toLowerCase();
        final cat = (item['category'] as String? ?? '').toLowerCase();
        final desc = (item['description'] as String? ?? '').toLowerCase();
        return name.contains(searchLower) ||
            brand.contains(searchLower) ||
            cat.contains(searchLower) ||
            desc.contains(searchLower);
      }).toList();
    }

    // Pagination
    final page = (query['page'] as num?)?.toInt() ?? 1;
    final limit = (query['limit'] as num?)?.toInt() ?? 20;
    final startIndex = (page - 1) * limit;
    final endIndex = startIndex + limit;

    final paginatedItems = items.length > startIndex
        ? items.sublist(startIndex, endIndex > items.length ? items.length : endIndex)
        : [];

    // Localize prices if not already localized
    // For /groceries and /food from region files, prices are already localized
    // For /shopping, we always need to localize since it comes from shopping.json (USD)
    final isRegionFile =
        regionKey != null && _regionCountries.contains(country);

    final localizedItems = isRegionFile
        ? paginatedItems
        : paginatedItems.map((item) {
            return _localizeProduct(item, exchangeRate, currency, currencySymbol);
          }).toList();

    final total = items.length;
    final hasMore = endIndex < total;

    return _buildResponse({
      'items': localizedItems,
      'total': total,
      'page': page,
      'limit': limit,
      'has_more': hasMore,
      'detected_country': country,
      'currency': currency,
    });
  }

  static Future<Response> _handleRestaurants(String region, Map<String, dynamic> query) async {
    await _ensureLoaded();

    final regionData = await _loadRegionData(region);
    var restaurants = List<Map<String, dynamic>>.from(regionData['restaurants'] ?? []);

    // Filter by cuisine
    final cuisine = query['cuisine'] as String?;
    if (cuisine != null && cuisine != 'All') {
      restaurants = restaurants.where((r) {
        final rCuisine = (r['cuisine'] as String? ?? '').toLowerCase();
        return rCuisine == cuisine.toLowerCase();
      }).toList();
    }

    return _buildResponse({
      'items': restaurants,
    });
  }

  static Future<Response> _handleRestaurantDetail(String country, String region, String id) async {
    await _ensureLoaded();

    final regionData = await _loadRegionData(region);
    final restaurantDetails = regionData['restaurant_details'] as Map<String, dynamic>?;
    final details = restaurantDetails?[id] as Map<String, dynamic>?;

    if (details == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/restaurants/$id'),
        error: 'Restaurant not found: $id',
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 404,
          requestOptions: RequestOptions(path: '/restaurants/$id'),
        ),
      );
    }

    // Localize dish prices if needed
    final countries = (_bootstrapData!['countries'] as Map<String, dynamic>);
    final countryData = countries[country] ?? countries['US']!;
    final exchangeRate = (countryData['exchange_rate'] as num).toDouble();
    final currency = countryData['currency'] as String;
    final currencySymbol = countryData['currency_symbol'] as String;
    final hasRegionFile = _regionCountries.contains(country);

    final localizedDetails = hasRegionFile
        ? details
        : _localizeRestaurantDetails(details, exchangeRate, currency, currencySymbol);

    return _buildResponse(localizedDetails);
  }

  static Future<Response> _handleFoodDetail(String country, String region, String id) async {
    await _ensureLoaded();

    final regionData = await _loadRegionData(region);
    final foodItems = List<Map<String, dynamic>>.from(regionData['food'] ?? []);

    final found = foodItems.firstWhere(
      (item) => item['id'] == id,
      orElse: () => throw DioException(
        requestOptions: RequestOptions(path: '/food/$id'),
        error: 'Food item not found: $id',
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 404,
          requestOptions: RequestOptions(path: '/food/$id'),
        ),
      ),
    );

    // Localize if needed
    final countries = (_bootstrapData!['countries'] as Map<String, dynamic>);
    final countryData = countries[country] ?? countries['US']!;
    final exchangeRate = (countryData['exchange_rate'] as num).toDouble();
    final currency = countryData['currency'] as String;
    final currencySymbol = countryData['currency_symbol'] as String;
    final hasRegionFile = _regionCountries.contains(country);

    final localized = hasRegionFile
        ? found
        : _localizeProduct(found, exchangeRate, currency, currencySymbol);

    return _buildResponse(localized);
  }

  static Future<Response> _handleCategories(String region) async {
    await _ensureLoaded();

    final regionData = await _loadRegionData(region);
    final categories = regionData['categories'] as Map<String, dynamic>?;

    if (categories == null) {
      return _buildResponse({});
    }

    return _buildResponse(categories);
  }

  static Future<Response> _handleSearch(String country, String region, Map<String, dynamic> query) async {
    await _ensureLoaded();

    final q = (query['q'] as String?)?.toLowerCase() ?? '';
    final countries = (_bootstrapData!['countries'] as Map<String, dynamic>);
    final countryData = countries[country] ?? countries['US']!;
    final exchangeRate = (countryData['exchange_rate'] as num).toDouble();
    final currency = countryData['currency'] as String;
    final currencySymbol = countryData['currency_symbol'] as String;
    final hasRegionFile = _regionCountries.contains(country);

    // Get search results
    final shoppingItems = List<Map<String, dynamic>>.from(_shoppingData!);
    final regionData = await _loadRegionData(region);
    final groceries = List<Map<String, dynamic>>.from(regionData['groceries'] ?? []);
    final foodItems = List<Map<String, dynamic>>.from(regionData['food'] ?? []);
    final restaurants = List<Map<String, dynamic>>.from(regionData['restaurants'] ?? []);

    // Filter each by search query
    final shopping = shoppingItems
        .where((item) => _matchesSearch(item, q))
        .take(20)
        .map((item) =>
            _localizeProduct(item, exchangeRate, currency, currencySymbol))
        .toList();

    final grocery = groceries
        .where((item) => _matchesSearch(item, q))
        .take(20)
        .map((item) => hasRegionFile
            ? item
            : _localizeProduct(item, exchangeRate, currency, currencySymbol))
        .toList();

    final food = foodItems
        .where((item) => _matchesSearch(item, q))
        .take(20)
        .map((item) => hasRegionFile
            ? item
            : _localizeProduct(item, exchangeRate, currency, currencySymbol))
        .toList();

    final restaurant = restaurants
        .where((item) => _matchesSearch(item, q))
        .take(20)
        .toList();

    return _buildResponse({
      'query': query['q'],
      'shopping': shopping,
      'groceries': grocery,
      'food': food,
      'restaurants': restaurant,
    });
  }

  static Future<Map<String, dynamic>> _loadRegionData(String region) async {
    final filename = 'assets/static_demo/region_$region.json';

    switch (region) {
      case 'US':
        if (_regionDataUS == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataUS = data as Map<String, dynamic>;
        }
        return _regionDataUS!;
      case 'IN':
        if (_regionDataIN == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataIN = data as Map<String, dynamic>;
        }
        return _regionDataIN!;
      case 'GB':
        if (_regionDataGB == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataGB = data as Map<String, dynamic>;
        }
        return _regionDataGB!;
      case 'JP':
        if (_regionDataJP == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataJP = data as Map<String, dynamic>;
        }
        return _regionDataJP!;
      case 'DE':
        if (_regionDataDE == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataDE = data as Map<String, dynamic>;
        }
        return _regionDataDE!;
      case 'FR':
        if (_regionDataFR == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataFR = data as Map<String, dynamic>;
        }
        return _regionDataFR!;
      case 'CA':
        if (_regionDataCA == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataCA = data as Map<String, dynamic>;
        }
        return _regionDataCA!;
      case 'AU':
        if (_regionDataAU == null) {
          final data = json.decode(await rootBundle.loadString(filename));
          _regionDataAU = data as Map<String, dynamic>;
        }
        return _regionDataAU!;
      default:
        // Fallback to US
        return await _loadRegionData('US');
    }
  }

  static bool _matchesSearch(Map<String, dynamic> item, String query) {
    final name = (item['name'] as String? ?? '').toLowerCase();
    final brand = (item['brand'] as String? ?? '').toLowerCase();
    final cat = (item['category'] as String? ?? '').toLowerCase();
    final desc = (item['description'] as String? ?? '').toLowerCase();
    return name.contains(query) ||
        brand.contains(query) ||
        cat.contains(query) ||
        desc.contains(query);
  }

  static Map<String, dynamic> _localizeProduct(
    Map<String, dynamic> item,
    double exchangeRate,
    String currency,
    String currencySymbol,
  ) {
    final basePrice = item['base_price_usd'] as num;
    final originalPrice = item['original_price_usd'] as num?;

    final shouldRound = currency == 'INR' || currency == 'JPY';
    double round(num v) => shouldRound
        ? v.roundToDouble()
        : (v * 100).roundToDouble() / 100;
    final displayPrice = round(basePrice * exchangeRate);
    final originalDisplayPrice =
        originalPrice != null ? round(originalPrice * exchangeRate) : null;

    // Format prices
    final formattedPrice = CurrencyFormatter.format(displayPrice, currency, currencySymbol);

    final formattedOriginalPrice = originalDisplayPrice != null
        ? CurrencyFormatter.format(originalDisplayPrice, currency, currencySymbol)
        : null;


    return {
      ...item,
      'base_price_usd': item['base_price_usd'],
      'display_price': displayPrice,
      'original_display_price': originalDisplayPrice,
      'formatted_price': formattedPrice,
      'formatted_original_price': formattedOriginalPrice,
      'currency': currency,
      'currency_symbol': currencySymbol,
    };
  }

  static Map<String, dynamic> _localizeRestaurantDetails(
    Map<String, dynamic> details,
    double exchangeRate,
    String currency,
    String currencySymbol,
  ) {
    final menu = details['menu'] as List?;
    if (menu == null) {
      return details;
    }

    final localizedMenu = menu.map((item) {
      return _localizeProduct(item as Map<String, dynamic>, exchangeRate, currency, currencySymbol);
    }).toList();

    return {
      ...details,
      'menu': localizedMenu,
    };
  }
}
