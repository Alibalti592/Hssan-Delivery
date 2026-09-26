import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/addresses/address_repository.dart';
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/home_screen.dart';
import 'package:mobile/client/parcel_form_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:mobile/promotions/promotions_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

Map<String, dynamic> _promotion(int id, String title) => {
  'id': id,
  'title': title,
  'description': null,
  'photoUrl': null,
  'discountType': 'PERCENTAGE',
  'discountValue': '10.000',
  'promoCode': null,
  'restaurantId': null,
  'restaurantName': null,
};

Map<String, dynamic> _offer() => {
  'id': 7,
  'title': '2 Sandwiches Chawarma',
  'description': null,
  'photoUrl': null,
  'discountType': 'FIXED_PRICE',
  'discountValue': '11.000',
  'promoCode': null,
  'restaurantId': 4,
  'restaurantName': 'Chawarma House',
  'items': ['2 Sandwichs Chawarma au Poulet Grillé', 'Frites dorées'],
  'productId': 30,
};

/// Wires up the full provider graph HomeScreen now depends on (address,
/// catalogue, auth, cart — mirroring main.dart's real composition), with an
/// empty-but-valid response for everything not explicitly overridden.
Widget _wrap({
  List<dynamic> promotions = const [],
  List<dynamic> restaurants = const [],
  CartController? cart,
}) {
  final api = ApiClient(
    tokenProvider: () => 'jwt-123',
    onUnauthorized: () {},
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/addresses') {
        return jsonResponse(const []);
      }
      if (request.url.path == '/api/restaurants') {
        return jsonResponse(pagedBody(restaurants));
      }
      return jsonResponse(promotions);
    }),
  );

  return MultiProvider(
    providers: [
      Provider<PromotionsRepository>.value(value: PromotionsRepository(api)),
      Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
      Provider<AddressRepository>.value(value: AddressRepository(api)),
      Provider<OrdersRepository>.value(value: OrdersRepository(api)),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(
          repository: AuthRepository(api),
          storage: _MemoryTokenStorage(),
        ),
      ),
      ChangeNotifierProvider<CartController>.value(
        value: cart ?? CartController(),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: HomeScreen())),
  );
}

void main() {
  testWidgets('shows exactly the four service cards, Restaurants first', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Restaurants'), findsWidgets);
    expect(find.text('Factures'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('Pressing'), findsNothing);
  });

  testWidgets('tapping a coming-soon service shows the placeholder dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Factures'));
    await tester.pumpAndSettle();

    expect(find.text('Service bientôt disponible'), findsOneWidget);
  });

  testWidgets('tapping Colis opens the parcel form, not the placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    expect(find.byType(ParcelFormScreen), findsOneWidget);
    expect(find.text('Service bientôt disponible'), findsNothing);
  });

  testWidgets(
    'shows the promotions carousel when the backend has active promos',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          promotions: [
            _promotion(1, 'Summer Discount'),
            _promotion(2, 'Weekend Special'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Summer Discount'), findsOneWidget);
      expect(find.text('Weekend Special'), findsOneWidget);
    },
  );

  testWidgets(
    'an offer opens its page and "Commander" puts it in the cart at its price',
    (tester) async {
      // Tall enough for the offer page's included-items list and its
      // bottom bar in the test font.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final cart = CartController();
      await tester.pumpWidget(_wrap(promotions: [_offer()], cart: cart));
      await tester.pumpAndSettle();

      expect(find.text('2 Sandwiches Chawarma'), findsOneWidget);
      expect(find.text('11.000 DT'), findsOneWidget);

      await tester.tap(find.text('2 Sandwiches Chawarma'));
      await tester.pumpAndSettle();

      expect(find.text('Ce qui est inclus'), findsOneWidget);
      expect(
        find.text('2 Sandwichs Chawarma au Poulet Grillé'),
        findsOneWidget,
      );
      expect(find.text('Frites dorées'), findsOneWidget);
      expect(find.text('Chawarma House'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('COMMANDER · 22.000 DT'), findsOneWidget);

      await tester.tap(find.text('COMMANDER · 22.000 DT'));
      await tester.pumpAndSettle();

      expect(cart.restaurantId, 4);
      expect(cart.restaurantName, 'Chawarma House');
      expect(cart.lines.single.product.id, 30);
      expect(cart.lines.single.quantity, 2);
      expect(cart.subtotal, 22);
    },
  );

  testWidgets('shows nothing extra when there are no active promotions', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Impossible de charger les promotions.'), findsNothing);
  });

  testWidgets('shows a cart badge once an item is added', (tester) async {
    final cart = CartController()
      ..add(
        Product.fromJson({
          'id': 1,
          'name': 'Classic Smash',
          'description': null,
          'price': '12.500',
          'isAvailable': true,
          'photoUrl': null,
          'restaurantId': 1,
          'categoryId': 1,
        }),
        restaurantName: 'Le Bon Burger',
      );

    await tester.pumpWidget(_wrap(cart: cart));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tapping Courses opens grocery stores filtered by type', (
    tester,
  ) async {
    String? requestedUrl;

    final api = ApiClient(
      tokenProvider: () => 'jwt-123',
      onUnauthorized: () {},
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/restaurants') {
          requestedUrl = request.url.toString();
        }
        return jsonResponse(pagedBody(const []));
      }),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PromotionsRepository>.value(
            value: PromotionsRepository(api),
          ),
          Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
          Provider<AddressRepository>.value(value: AddressRepository(api)),
          ChangeNotifierProvider<AuthController>.value(
            value: AuthController(
              repository: AuthRepository(api),
              storage: _MemoryTokenStorage(),
            ),
          ),
          ChangeNotifierProvider<CartController>.value(value: CartController()),
        ],
        child: MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();
    requestedUrl = null; // discard the home feed's own restaurant-type fetch

    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();

    expect(requestedUrl, contains('type=GROCERY'));
    expect(find.text('Service bientôt disponible'), findsNothing);
    expect(
      find.text('Aucun magasin disponible pour le moment.'),
      findsOneWidget,
    );
  });
}
