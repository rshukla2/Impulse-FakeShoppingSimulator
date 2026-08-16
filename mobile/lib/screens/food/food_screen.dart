import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impulse/core/icons/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../providers/catalog_providers.dart';
import '../../widgets/badge_icon.dart';
import '../../widgets/product_card.dart';
import '../../widgets/restaurant_card.dart';

class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({super.key});

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  String _selectedCuisine = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  CatalogParams get _params => CatalogParams(cuisine: _selectedCuisine);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearBottom);
  }

  void _loadMoreNearBottom() {
    if (_searchQuery.isEmpty && _scrollController.position.extentAfter < 400) {
      ref.read(foodDishesProvider(_params).notifier).loadNextPage();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cuisines = ref.watch(categoriesProvider).value?['food'] ??
        const [
          'All',
          'North Indian',
          'South Indian',
          'Japanese',
          'Italian',
          'American',
          'Mexican',
        ];
    final restaurants = ref.watch(restaurantsProvider(_params));
    final dishes = ref.watch(foodDishesProvider(_params));
    final search = _searchQuery.isEmpty
        ? null
        : ref.watch(foodSearchProvider(_searchQuery));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Food'),
        actions: const [CartBadgeButton(), SizedBox(width: 8)],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search restaurants, cuisines, or dishes…',
                      prefixIcon: const Icon(LucideIcons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () {
                                _debounce?.cancel();
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _onSearchChanged(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cuisines.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cuisine = cuisines[index];
                        return ChoiceChip(
                          label: Text(cuisine),
                          selected: cuisine == _selectedCuisine,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCuisine = cuisine);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (search != null)
            ..._buildSearchSlivers(search)
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Restaurants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            restaurants.when(
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No restaurants in this cuisine yet.'),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              RestaurantCard(restaurant: items[index]),
                          childCount: items.length,
                        ),
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: _RetryMessage(
                  message: 'We couldn’t load restaurants.',
                  onRetry: () => ref.invalidate(restaurantsProvider(_params)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Popular Dishes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            if (dishes.isInitialLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (dishes.items.isEmpty && dishes.error != null)
              SliverToBoxAdapter(
                child: _RetryMessage(
                  message: 'We couldn’t load dishes.',
                  onRetry: () =>
                      ref.read(foodDishesProvider(_params).notifier).retry(),
                ),
              )
            else
              _productGrid(dishes.items),
            SliverToBoxAdapter(
              child: _FoodFooter(
                feed: dishes,
                onRetry: () =>
                    ref.read(foodDishesProvider(_params).notifier).retry(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSearchSlivers(
    AsyncValue<FoodSearchResults> search,
  ) {
    return search.when(
      loading: () => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (_, __) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _RetryMessage(
            message: 'We couldn’t complete that search.',
            onRetry: () => ref.invalidate(foodSearchProvider(_searchQuery)),
          ),
        ),
      ],
      data: (results) {
        if (results.restaurants.isEmpty && results.dishes.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No food results match your search.')),
            ),
          ];
        }
        return [
          if (results.restaurants.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Matching Restaurants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => RestaurantCard(
                    restaurant: results.restaurants[index],
                  ),
                  childCount: results.restaurants.length,
                ),
              ),
            ),
          ],
          if (results.dishes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Matching Dishes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            _productGrid(results.dishes),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ];
      },
    );
  }

  Widget _productGrid(List<Product> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          childAspectRatio: 0.68,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(product: items[index]),
          childCount: items.length,
        ),
      ),
    );
  }
}

class _RetryMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RetryMessage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Try Again')),
            ],
          ),
        ),
      );
}

class _FoodFooter extends StatelessWidget {
  final CatalogFeedState feed;
  final VoidCallback onRetry;
  const _FoodFooter({required this.feed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (feed.isLoading && feed.items.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (feed.error != null && feed.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry loading more'),
          ),
        ),
      );
    }
    if (!feed.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('You’ve reached the end.')),
      );
    }
    return const SizedBox(height: 32);
  }
}
