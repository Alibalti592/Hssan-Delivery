import '../core/api_client.dart';
import 'catalogue_models.dart';

/// The backend paginates restaurants/products (`{"items": [...], "meta":
/// {...}}`); the catalogue is an admin-managed list realistically small
/// enough to fetch in one page, so this just asks for the max page size
/// rather than adding infinite-scroll UI here.
const _catalogueLimit = 100;

class CatalogueRepository {
  CatalogueRepository(this._api);

  final ApiClient _api;

  Future<List<Restaurant>> listRestaurants({
    RestaurantType type = RestaurantType.restaurant,
  }) async {
    final body = await _api.get(
      '/api/restaurants?limit=$_catalogueLimit&type=${type.wire}',
    );
    final items = (body as Map<String, dynamic>)['items'] as List<dynamic>;
    return items
        .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The categories to filter the restaurant (or grocery store) list by:
  /// only those with an open restaurant behind them, in the admin's order.
  Future<List<RestaurantCategory>> listRestaurantCategories({
    RestaurantType type = RestaurantType.restaurant,
  }) async {
    final body = await _api.get('/api/restaurant-categories?type=${type.wire}');
    return (body as List<dynamic>)
        .map((e) => RestaurantCategory.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<MenuCategory>> listCategories(int restaurantId) async {
    final body = await _api.get('/api/restaurants/$restaurantId/categories');
    return (body as List<dynamic>)
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Product>> listProducts(int restaurantId) async {
    final body = await _api.get(
      '/api/restaurants/$restaurantId/products?limit=$_catalogueLimit',
    );
    final items = (body as Map<String, dynamic>)['items'] as List<dynamic>;
    return items
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Dishes and restaurants whose name contains [query] (2 letters or more).
  Future<SearchResults> search(String query) async {
    final body = await _api.get(
      '/api/search?q=${Uri.encodeQueryComponent(query)}',
    );
    return SearchResults.fromJson(body as Map<String, dynamic>);
  }
}
