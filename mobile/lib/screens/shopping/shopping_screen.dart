import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impulse/core/icons/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/catalog_providers.dart';
import '../../widgets/badge_icon.dart';
import '../../widgets/product_card.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  CatalogParams get _params => CatalogParams(
        category: _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearBottom);
  }

  void _loadMoreNearBottom() {
    if (_scrollController.position.extentAfter < 400) {
      ref.read(shoppingProductsProvider(_params).notifier).loadNextPage();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
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
    final feed = ref.watch(shoppingProductsProvider(_params));
    final categories = ref.watch(categoriesProvider).value?['shopping'] ??
        const ['All', 'Electronics', 'Computers', 'Office', 'Home'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shopping'),
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
                      hintText: 'Search products, brands, or categories…',
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
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ChoiceChip(
                          label: Text(category),
                          selected: category == _selectedCategory,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _selectedCategory == 'All'
                        ? 'Catalog Items'
                        : '$_selectedCategory Items',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          if (feed.isInitialLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (feed.items.isEmpty && feed.error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _CatalogError(
                onRetry: () => ref
                    .read(shoppingProductsProvider(_params).notifier)
                    .retry(),
              ),
            )
          else if (feed.items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No products match your search.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(product: feed.items[index]),
                  childCount: feed.items.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _CatalogFooter(
              isLoading: feed.isLoading && feed.items.isNotEmpty,
              hasMore: feed.hasMore,
              hasError: feed.error != null && feed.items.isNotEmpty,
              onRetry: () =>
                  ref.read(shoppingProductsProvider(_params).notifier).retry(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  final VoidCallback onRetry;

  const _CatalogError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We couldn’t load the catalog.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      );
}

class _CatalogFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final bool hasError;
  final VoidCallback onRetry;

  const _CatalogFooter({
    required this.isLoading,
    required this.hasMore,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasError) {
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
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('You’ve reached the end.')),
      );
    }
    return const SizedBox(height: 32);
  }
}
