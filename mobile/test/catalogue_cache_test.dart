import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/promotions/promotions_repository.dart';

import 'widget/test_utils.dart';

/// What a usual visit asks the server: home, a menu, a dish, the cart, home
/// again. Each screen asks for what it shows; the kept answers (TtlCache)
/// spare the round trips to the server for what another screen just had.
void main() {
  late List<String> asked;
  late CatalogueRepository catalogue;
  late PromotionsRepository promotions;

  setUp(() {
    asked = [];
    final api = ApiClient(
      tokenProvider: () => 'jwt',
      onUnauthorized: () {},
      httpClient: MockClient((request) async {
        asked.add(request.url.path);
        final path = request.url.path;
        if (path == '/api/restaurants' || path.endsWith('/products')) {
          return jsonResponse(pagedBody(const []));
        }
        if (path == '/api/popular') {
          return jsonResponse({
            'restaurants': const [],
            'dishes': const [],
            'windowDays': 30,
          });
        }
        return jsonResponse(const []);
      }),
    );
    catalogue = CatalogueRepository(api);
    promotions = PromotionsRepository(api);
  });

  Future<void> home() => Future.wait([
    catalogue.listRestaurants(),
    catalogue.listRestaurantCategories(),
    catalogue.popular(),
    promotions.listActive(),
  ]);
  Future<void> menu(int id) => Future.wait([
    catalogue.listCategories(id),
    catalogue.listProducts(id),
    promotions.listActive(),
  ]);

  test('a usual visit asks the server 6 times, not 15', () async {
    await home(); // 4 requests
    await menu(8); // categories and dishes of the menu: 2 more
    await menu(8); // the dish's page: nothing new
    await menu(8); // the cart: nothing new
    await home(); // back home: nothing new

    expect(asked, hasLength(6));
    expect(asked.toSet(), hasLength(6), reason: 'never twice the same');
  });

  test('pulling the home screen down asks again', () async {
    await home();
    await Future.wait([
      catalogue.listRestaurants(refresh: true),
      catalogue.listRestaurantCategories(refresh: true),
      catalogue.popular(refresh: true),
      promotions.listActive(refresh: true),
    ]);

    expect(asked, hasLength(8));
  });

  test('signing out forgets the kept answers', () async {
    await home();
    catalogue.clearCache();
    promotions.clearCache();
    await home();

    expect(asked, hasLength(8));
  });
}
