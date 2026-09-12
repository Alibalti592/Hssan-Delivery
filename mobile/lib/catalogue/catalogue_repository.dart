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

  Future<List<Restaurant>> listRestaurants() async {
    final body = await _api.get('/api/restaurants?limit=$_catalogueLimit');
    final items = (body as Map<String, dynamic>)['items'] as List<dynamic>;
    return items
        .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
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
}
