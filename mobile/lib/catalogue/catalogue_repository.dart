import '../core/api_client.dart';
import 'catalogue_models.dart';

class CatalogueRepository {
  CatalogueRepository(this._api);

  final ApiClient _api;

  Future<List<Restaurant>> listRestaurants() async {
    final body = await _api.get('/api/restaurants');
    return (body as List<dynamic>)
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
    final body = await _api.get('/api/restaurants/$restaurantId/products');
    return (body as List<dynamic>)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
