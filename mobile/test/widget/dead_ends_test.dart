import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/cart_screen.dart';
import 'package:mobile/client/restaurant_menu_screen.dart';
import 'package:mobile/client/restaurants_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

/// Screens that used to leave the client stuck now offer a way forward.
void main() {
  testWidgets('a menu that failed to load can be retried', (tester) async {
    var calls = 0;
    final api = ApiClient(
      tokenProvider: () => 'jwt-123',
      onUnauthorized: () {},
      httpClient: MockClient((request) async {
        calls++;
        if (calls == 1) return jsonResponse({'message': 'Erreur'}, 500);
        if (request.url.path.endsWith('/categories')) {
          return jsonResponse([
            {'id': 3, 'name': 'Pizzas', 'restaurantId': 1},
          ]);
        }
        return jsonResponse(
          pagedBody([
            {
              'id': 10,
              'name': 'Pizza Margherita',
              'description': null,
              'price': '12.000',
              'options': [],
              'isAvailable': true,
              'photoUrl': null,
              'restaurantId': 1,
              'categoryId': 3,
            },
          ]),
        );
      }),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
          ChangeNotifierProvider(create: (_) => CartController()),
        ],
        child: MaterialApp(
          home: RestaurantMenuScreen(
            restaurant: Restaurant(
              id: 1,
              name: 'Pizzeria Roma',
              description: null,
              isAvailable: true,
              type: RestaurantType.restaurant,
              photoUrl: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger le menu'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Pizza Margherita'), findsOneWidget);
  });

  testWidgets('an empty cart leads to the restaurants', (tester) async {
    final api = ApiClient(
      tokenProvider: () => 'jwt-123',
      onUnauthorized: () {},
      httpClient: MockClient((_) async => jsonResponse(pagedBody(const []))),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
          ChangeNotifierProvider(create: (_) => CartController()),
        ],
        child: const MaterialApp(home: Scaffold(body: CartView())),
      ),
    );

    expect(find.text('Votre panier est vide'), findsOneWidget);
    await tester.tap(find.text('Voir les restaurants'));
    await tester.pumpAndSettle();

    expect(find.byType(RestaurantsScreen), findsOneWidget);
  });
}
