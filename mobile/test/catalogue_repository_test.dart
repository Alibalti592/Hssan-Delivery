import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/core/api_client.dart';

import 'widget/test_utils.dart';

Map<String, dynamic> _product(int id) => {
  'id': id,
  'name': 'Plat $id',
  'description': null,
  'price': '5.000',
  'isAvailable': true,
  'photoUrl': null,
  'restaurantId': 8,
  'categoryId': 1,
  'options': const [],
};

void main() {
  test('a menu over one page (119 items) comes back whole', () async {
    final pagesAsked = <String>[];
    final api = ApiClient(
      tokenProvider: () => 'jwt',
      onUnauthorized: () {},
      httpClient: MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        pagesAsked.add('$page');
        final ids = page == 1
            ? List.generate(100, (i) => i + 1)
            : List.generate(19, (i) => i + 101);
        return jsonResponse(
          pagedBody([for (final id in ids) _product(id)], page: page, pages: 2),
        );
      }),
    );

    final products = await CatalogueRepository(api).listProducts(8);

    expect(pagesAsked, ['1', '2']);
    expect(products, hasLength(119));
    expect(products.last.id, 119);
  });
}
