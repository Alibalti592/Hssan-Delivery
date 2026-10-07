import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/restaurant_menu_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/promotions/promotions_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _promotion(
  int id,
  String title, {
  String type = 'PERCENTAGE',
  String value = '10.000',
  String? code,
  int? restaurantId,
}) => {
  'id': id,
  'title': title,
  'description': null,
  'photoUrl': null,
  'discountType': type,
  'discountValue': value,
  'promoCode': code,
  'restaurantId': restaurantId,
  'restaurantName': restaurantId == null ? null : 'Restaurant $restaurantId',
  'items': const [],
  'productId': type == 'FIXED_PRICE' ? 50 : null,
};

void main() {
  testWidgets('a menu shows the promotions that apply there, with their code', (
    tester,
  ) async {
    final api = ApiClient(
      tokenProvider: () => 'jwt-123',
      onUnauthorized: () {},
      httpClient: MockClient((request) async {
        switch (request.url.path) {
          case '/api/promotions':
            return jsonResponse([
              _promotion(1, 'Ici', restaurantId: 1),
              _promotion(
                2,
                'Bienvenue',
                type: 'FIXED_AMOUNT',
                value: '5.000',
                code: 'BIENVENUE',
              ),
              _promotion(3, 'Ailleurs', restaurantId: 2),
              _promotion(
                4,
                'Menu duo',
                type: 'FIXED_PRICE',
                value: '20.000',
                restaurantId: 1,
              ),
            ]);
          case '/api/restaurants/1/categories':
            return jsonResponse([
              {'id': 3, 'name': 'Pizzas', 'restaurantId': 1},
            ]);
          default:
            return jsonResponse(
              pagedBody([
                {
                  'id': 10,
                  'name': 'Margherita',
                  'description': null,
                  'price': '12.000',
                  'options': const [],
                  'isAvailable': true,
                  'photoUrl': null,
                  'restaurantId': 1,
                  'categoryId': 3,
                },
              ]),
            );
        }
      }),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
          Provider<PromotionsRepository>.value(
            value: PromotionsRepository(api),
          ),
          ChangeNotifierProvider(create: (_) => CartController()),
        ],
        child: MaterialApp(
          home: RestaurantMenuScreen(
            restaurant: Restaurant(
              id: 1,
              name: 'Restaurant 1',
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

    expect(find.text('-10% sur votre commande'), findsOneWidget);
    expect(find.text('Appliquée automatiquement'), findsOneWidget);
    expect(find.text('-5.000 DT sur votre commande'), findsOneWidget);
    expect(find.text('Avec le code BIENVENUE'), findsOneWidget);
    // Another restaurant's promotion, and offers (on the menu as dishes).
    expect(find.textContaining('Ailleurs'), findsNothing);
    expect(find.textContaining('Menu duo'), findsNothing);

    await tester.tap(find.text('Avec le code BIENVENUE'));
    await tester.pumpAndSettle();
    expect(find.text('BIENVENUE'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
    expect(
      find.text('Saisissez le code au moment de commander'),
      findsOneWidget,
    );
    expect(
      find.text('Valable dans tous les restaurants et magasins'),
      findsOneWidget,
    );
  });
}
