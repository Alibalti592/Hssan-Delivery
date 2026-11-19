import '../core/api_client.dart';
import '../core/ttl_cache.dart';
import 'catalogue_models.dart';

/// The backend paginates restaurants/products (`{"items": [...], "meta":
/// {...}}`); the catalogue is an admin-managed list realistically small
/// enough to fetch in one page, so this just asks for the max page size
/// rather than adding infinite-scroll UI here.
const _catalogueLimit = 100;

/// How long each kind of answer is kept (see TtlCache): opening times and
/// menus change during the day, categories hardly ever.
const _restaurantsTtl = Duration(minutes: 5);
const _menuTtl = Duration(minutes: 3);
const _categoriesTtl = Duration(minutes: 30);
const _popularTtl = Duration(minutes: 5);

class CatalogueRepository {
  CatalogueRepository(this._api, {TtlCache? cache})
    : _cache = cache ?? TtlCache();

  final ApiClient _api;
  final TtlCache _cache;

  /// Forgets every kept answer (on sign-out).
  void clearCache() => _cache.clear();

  /// [refresh] (pull to refresh) asks the server again; otherwise an
  /// answer from the last few minutes is reused (TtlCache).
  Future<List<Restaurant>> listRestaurants({
    RestaurantType type = RestaurantType.restaurant,
    bool refresh = false,
  }) {
    return _cache.get(
      'restaurants:${type.wire}',
      ttl: _restaurantsTtl,
      refresh: refresh,
      () async {
        final body = await _api.get(
          '/api/restaurants?limit=$_catalogueLimit&type=${type.wire}',
        );
        final items = (body as Map<String, dynamic>)['items'] as List<dynamic>;
        return items
            .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      },
    );
  }

  /// The categories to filter the restaurant (or grocery store) list by:
  /// only those with an open restaurant behind them, in the admin's order.
  Future<List<RestaurantCategory>> listRestaurantCategories({
    RestaurantType type = RestaurantType.restaurant,
    bool refresh = false,
  }) {
    return _cache.get(
      'restaurant-categories:${type.wire}',
      ttl: _categoriesTtl,
      refresh: refresh,
      () async {
        final body = await _api.get(
          '/api/restaurant-categories?type=${type.wire}',
        );
        return (body as List<dynamic>)
            .map((e) => RestaurantCategory.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      },
    );
  }

  /// A menu is asked for by several screens in a row (home's favourites,
  /// the menu, a dish, the cart): kept a few minutes, they share one.
  Future<List<MenuCategory>> listCategories(int restaurantId) {
    return _cache.get('menu-categories:$restaurantId', ttl: _menuTtl, () async {
      final body = await _api.get('/api/restaurants/$restaurantId/categories');
      return (body as List<dynamic>)
          .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    });
  }

  /// The whole menu: every page of it, so a menu over the server's page
  /// size (100) isn't cut short. A few pages at most.
  Future<List<Product>> listProducts(int restaurantId) {
    return _cache.get(
      'menu-products:$restaurantId',
      ttl: _menuTtl,
      () => _loadProducts(restaurantId),
    );
  }

  Future<List<Product>> _loadProducts(int restaurantId) async {
    const maxPages = 10;
    final products = <Product>[];
    for (var page = 1; page <= maxPages; page++) {
      final body =
          await _api.get(
                '/api/restaurants/$restaurantId/products'
                '?limit=$_catalogueLimit&page=$page',
              )
              as Map<String, dynamic>;
      products.addAll(
        (body['items'] as List<dynamic>).map(
          (e) => Product.fromJson(e as Map<String, dynamic>),
        ),
      );
      final pages =
          (body['meta'] as Map<String, dynamic>?)?['pages'] as int? ?? 1;
      if (page >= pages) break;
    }
    return List.unmodifiable(products);
  }

  /// The most ordered restaurants and dishes. A server older than this
  /// endpoint (404) just has none.
  Future<PopularFeed> popular({bool refresh = false}) {
    return _cache.get('popular', ttl: _popularTtl, refresh: refresh, () async {
      final body = await _api.get('/api/popular');
      return PopularFeed.fromJson(body as Map<String, dynamic>);
    });
  }

  /// Dishes and restaurants whose name contains [query] (2 letters or more).
  Future<SearchResults> search(String query) async {
    final body = await _api.get(
      '/api/search?q=${Uri.encodeQueryComponent(query)}',
    );
    return SearchResults.fromJson(body as Map<String, dynamic>);
  }
}
