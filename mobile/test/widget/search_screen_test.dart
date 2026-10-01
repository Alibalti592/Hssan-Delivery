import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/product_detail_screen.dart';
import 'package:mobile/client/search_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _restaurant(int id, String name, {String? type}) => {
  'id': id,
  'name': name,
  'description': null,
  'isAvailable': true,
  'type': type ?? 'RESTAURANT',
  'photoUrl': null,
};

Widget _app(Future<http.Response> Function(http.Request) handler) {
  final api = ApiClient(
    tokenProvider: () => 'jwt-123',
    onUnauthorized: () {},
    httpClient: MockClient(handler),
  );
  return MultiProvider(
    providers: [
      Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
      ChangeNotifierProvider(create: (_) => CartController()),
    ],
    child: const MaterialApp(home: SearchScreen()),
  );
}

void main() {
  testWidgets('finds dishes with their restaurant, and opens one', (
    tester,
  ) async {
    final queries = <String>[];
    await tester.pumpWidget(
      _app((request) async {
        queries.add(request.url.queryParameters['q']!);
        return jsonResponse({
          'restaurants': [_restaurant(1, 'Pizzeria Roma')],
          'products': [
            {
              'id': 10,
              'name': 'Pizza Margherita',
              'description': null,
              'price': '12.000',
              'options': [
                {'name': 'M', 'price': '12.000'},
                {'name': 'Familiale', 'price': '22.000'},
              ],
              'isAvailable': true,
              'photoUrl': null,
              'restaurantId': 1,
              'categoryId': 3,
              'restaurant': _restaurant(1, 'Pizzeria Roma'),
            },
          ],
        });
      }),
    );

    expect(find.text('Que voulez-vous commander ?'), findsOneWidget);

    // One letter isn't a search; typing on waits for a pause.
    await tester.enterText(find.byType(TextField), 'p');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'piz');
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(queries, ['pizza']);
    expect(find.text('RESTAURANTS ET MAGASINS'), findsOneWidget);
    expect(find.text('PLATS ET PRODUITS'), findsOneWidget);
    expect(find.text('Pizza Margherita'), findsOneWidget);
    expect(find.text('Pizzeria Roma'), findsNWidgets(2));
    expect(find.text('À partir de 12.000 DT'), findsOneWidget);

    await tester.tap(find.text('Pizza Margherita'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('says so when nothing matches, and retries after an error', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app((request) async {
        calls++;
        if (calls == 1) {
          return jsonResponse({'message': 'Erreur serveur'}, 500);
        }
        return jsonResponse({'restaurants': [], 'products': []});
      }),
    );

    await tester.enterText(find.byType(TextField), 'sushi');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour « sushi »'), findsOneWidget);
  });
}
