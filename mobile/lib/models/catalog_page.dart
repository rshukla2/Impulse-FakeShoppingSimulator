class CatalogPage<T> {
  final List<T> items;
  final int page;
  final bool hasMore;

  const CatalogPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });
}
