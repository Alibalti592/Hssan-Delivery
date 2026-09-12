/// A single page from one of the backend's `{"items": [...], "meta": {...}}`
/// paginated list endpoints.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pages,
    required this.total,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = json['items'] as List<dynamic>;
    final meta = json['meta'] as Map<String, dynamic>;

    return PagedResult(
      items: items
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      page: meta['page'] as int,
      pages: meta['pages'] as int,
      total: meta['total'] as int,
    );
  }

  final List<T> items;
  final int page;
  final int pages;
  final int total;

  bool get hasMore => page < pages;
}
