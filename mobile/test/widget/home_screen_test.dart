import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/addresses/address_repository.dart';
import 'package:mobile/addresses/selected_address.dart';
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/bills/bill_providers_screen.dart';
import 'package:mobile/bills/bills_repository.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/catalogue/category_widgets.dart';
import 'package:mobile/client/home_screen.dart';
import 'package:mobile/client/parcel_form_screen.dart';
import 'package:mobile/client/product_detail_screen.dart';
import 'package:mobile/client/restaurants_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:mobile/promotions/promotions_repository.dart';
import 'package:mobile/widgets/app_photo.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String? token) async {}

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
  List<dynamic> categories = const [],
  List<dynamic> orders = const [],
  Map<int, List<dynamic>> menus = const {},
  Map<String, dynamic>? popular,
  CartController? cart,
  VoidCallback? onSeeOrders,
}) {
  final api = ApiClient(
    tokenProvider: () => 'jwt-123',
    onUnauthorized: () {},
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/addresses') {
        return jsonResponse(const []);
      }
      if (request.url.path == '/api/popular') {
        return popular == null
            ? jsonResponse({'message': 'Not found'}, 404)
            : jsonResponse(popular);
      }
      final menu = RegExp(
        r'^/api/restaurants/(\d+)/products$',
      ).firstMatch(request.url.path);
      if (menu != null) {
        return jsonResponse(
          pagedBody(menus[int.parse(menu.group(1)!)] ?? const []),
        );
      }
      if (request.url.path == '/api/orders') {
        return jsonResponse(pagedBody(orders));
      }
      if (request.url.path == '/api/restaurants') {
        return jsonResponse(pagedBody(restaurants));
      }
      if (request.url.path == '/api/restaurant-categories') {
        return jsonResponse(categories);
      }
      if (request.url.path == '/api/bill-providers') {
        return jsonResponse([
          {'id': 1, 'name': 'STEG', 'kind': 'BILL', 'logoUrl': null},
          {'id': 5, 'name': 'Wafa Cash', 'kind': 'TRANSFER', 'logoUrl': null},
        ]);
      }
      return jsonResponse(promotions);
    }),
  );

  return MultiProvider(
    providers: [
      Provider<PromotionsRepository>.value(value: PromotionsRepository(api)),
      Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
      Provider<AddressRepository>.value(value: AddressRepository(api)),
      ChangeNotifierProvider(
        create: (_) => SelectedAddressController(AddressRepository(api)),
      ),
      Provider<OrdersRepository>.value(value: OrdersRepository(api)),
      Provider<BillsRepository>.value(value: BillsRepository(api)),
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
    child: MaterialApp(
      home: Scaffold(body: HomeScreen(onSeeOrders: onSeeOrders)),
    ),
  );
}

Map<String, dynamic> _order(
  int id, {
  required String status,
  String? deliveryStatus,
  String? courierName,
  String deliveryType = 'RESTAURANT',
}) => {
  'id': id,
  'restaurantId': deliveryType == 'PARCEL' ? null : 1,
  'restaurantName': deliveryType == 'PARCEL' ? null : 'Pizza Roma',
  'items': const [],
  'deliveryAddress': 'Rue de la Paix',
  'deliveryZoneId': 1,
  'deliveryZoneName': 'Centre-ville',
  'deliveryFee': '3.000',
  'totalAmount': '25.000',
  'status': status,
  'deliveryStatus': deliveryStatus,
  'deliveryType': deliveryType,
  'courierName': courierName,
};

void main() {
  testWidgets('an order on its way shows on top of the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        orders: [
          _order(
            12,
            status: 'CONFIRMED',
            deliveryStatus: 'PICKED_UP',
            courierName: 'Ahmed',
          ),
          _order(9, status: 'COMPLETED', deliveryStatus: 'DELIVERED'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMMANDE EN COURS'), findsOneWidget);
    expect(find.text('Commande récupérée'), findsOneWidget);
    expect(find.text('Pizza Roma · Livreur : Ahmed'), findsOneWidget);
    expect(find.text('#12'), findsOneWidget);
    // Only one is in progress: nothing more to see.
    expect(find.text('Voir mes commandes'), findsNothing);

    // Dispose the screen so its 20-second refresh timer goes with it.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('several orders in progress offer to see them all', (
    tester,
  ) async {
    var openedOrders = false;
    await tester.pumpWidget(
      _wrap(
        orders: [
          _order(14, status: 'PENDING', deliveryType: 'PARCEL'),
          _order(13, status: 'CONFIRMED', deliveryStatus: 'ASSIGNED'),
        ],
        onSeeOrders: () => openedOrders = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DEMANDE EN COURS'), findsOneWidget);
    expect(find.text('Demande envoyée'), findsOneWidget);
    expect(find.text('Colis · Nous cherchons un livreur…'), findsOneWidget);
    await tester.tap(find.text('Voir mes commandes'));
    expect(openedOrders, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no banner once everything is delivered', (tester) async {
    await tester.pumpWidget(
      _wrap(
        orders: [_order(9, status: 'COMPLETED', deliveryStatus: 'DELIVERED')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMMANDE EN COURS'), findsNothing);
  });

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

    // Each tile shows its illustration, and the file ships with the app.
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<ResizeImage>()
        .map((image) => (image.imageProvider as AssetImage).assetName)
        .toList();
    expect(images, [
      'assets/services/restaurants.webp',
      'assets/services/factures.webp',
      'assets/services/courses.webp',
      'assets/services/colis.webp',
    ]);
    for (final asset in images) {
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
    }
  });

  testWidgets('tapping Factures opens the bill providers, by kind', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Factures'));
    await tester.pumpAndSettle();

    expect(find.byType(BillProvidersScreen), findsOneWidget);
    expect(find.text('Payer une facture'), findsOneWidget);
    expect(find.text('Envoyer un mandat'), findsOneWidget);
    expect(find.text('Wafa Cash'), findsOneWidget);
  });

  testWidgets('tapping Colis opens the parcel form', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // The second row of services is below the fold of the test's screen.
    await tester.ensureVisible(find.text('Colis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    expect(find.byType(ParcelFormScreen), findsOneWidget);
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
      // Below the services grid, out of the test screen's first view.
      await tester.scrollUntilVisible(
        find.text('Promotions'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // findsWidgets: the carousel loops, so a card can be built twice.
      expect(find.text('Summer Discount'), findsWidgets);
      expect(find.text('Weekend Special'), findsWidgets);
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

    expect(find.text('Factures'), findsOneWidget); // the rest still shows
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
          ChangeNotifierProvider(
            create: (_) => SelectedAddressController(AddressRepository(api)),
          ),
          ChangeNotifierProvider<AuthController>.value(
            value: AuthController(
              repository: AuthRepository(api),
              storage: _MemoryTokenStorage(),
            ),
          ),
          ChangeNotifierProvider<CartController>.value(value: CartController()),
          Provider<OrdersRepository>.value(value: OrdersRepository(api)),
        ],
        child: MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();
    requestedUrl = null; // discard the home feed's own restaurant-type fetch

    // The second row of services is below the fold of the test's screen.
    await tester.ensureVisible(find.text('Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();

    expect(requestedUrl, contains('type=GROCERY'));
    expect(
      find.text('Aucun magasin disponible pour le moment.'),
      findsOneWidget,
    );
  });

  testWidgets('"Que souhaitez-vous manger ?" sits under the services, '
      'and a category opens its restaurants', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Map<String, dynamic> category(int id, String name, String icon) => {
      'id': id,
      'name': name,
      'icon': icon,
      'imageUrl': null,
      'position': id,
    };
    final pizza = category(1, 'Pizza', 'pizza');
    final sweet = category(2, 'Sucré', 'cake');
    Map<String, dynamic> restaurant(int id, String name, List<dynamic> c) => {
      'id': id,
      'name': name,
      'description': null,
      'isAvailable': true,
      'photoUrl': null,
      'categories': c,
    };

    await tester.pumpWidget(
      _wrap(
        categories: [pizza, sweet],
        restaurants: [
          restaurant(1, 'Napoli Express', [pizza]),
          restaurant(2, 'Douceurs du Lac', [sweet]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    Finder tile(String name) => find.descendant(
      of: find.byType(CategorySelector),
      matching: find.text(name),
    );

    // Under the services, above the offers and the restaurants.
    final title = find.text('Que souhaitez-vous manger ?');
    expect(title, findsOneWidget);
    expect(
      tester.getTopLeft(title).dy,
      greaterThan(tester.getTopLeft(find.text('Colis')).dy),
    );
    expect(
      tester.getTopLeft(title).dy,
      lessThan(tester.getTopLeft(find.text('Restaurants').last).dy),
    );
    // No "Tout" here: every category is a way in, not a filter.
    expect(tile('Tout'), findsNothing);
    expect(tile('Pizza'), findsOneWidget);

    // Each drawn in 3D, like the services.
    final pictures = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byType(CategorySelector),
            matching: find.byType(Image),
          ),
        )
        .map(
          (image) => ((image.image as ResizeImage).imageProvider as AssetImage)
              .assetName,
        );
    expect(pictures, [
      'assets/categories/pizza.webp',
      'assets/categories/cake.webp',
    ]);

    await tester.tap(tile('Sucré'));
    await tester.pumpAndSettle();

    final list = find.byType(RestaurantsScreen);
    expect(list, findsOneWidget);
    expect(
      find.descendant(of: list, matching: find.text('Douceurs du Lac')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Napoli Express')),
      findsNothing,
    );
  });

  testWidgets('discounts and fixed-price offers get their own sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(promotions: [_promotion(1, 'Summer Discount'), _offer()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('-10%'), findsWidgets);
    expect(find.text('Combos & bons plans'), findsOneWidget);
    expect(find.text('2 Sandwiches Chawarma'), findsOneWidget);
  });

  testWidgets('no promotion section is shown without promotions', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Promotions'), findsNothing);
    expect(find.text('Combos & bons plans'), findsNothing);
    expect(find.text('Vos plus commandés'), findsNothing);
    expect(find.text('Nouveautés'), findsNothing);
  });

  testWidgets('"Vos plus commandés" counts the customer’s own orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Map<String, dynamic> item(int id, String name) => {
      'productId': id,
      'productName': name,
      'quantity': 1,
      'unitPrice': '15.000',
    };
    Map<String, dynamic> order(int id, String status, List<dynamic> items) => {
      ..._order(id, status: status),
      'items': items,
    };
    Map<String, dynamic> product(int id, String name) => {
      'id': id,
      'name': name,
      'description': null,
      'price': '15.000',
      'isAvailable': true,
      'photoUrl': null,
      'restaurantId': 1,
      'categoryId': 1,
      'options': const [],
    };

    await tester.pumpWidget(
      _wrap(
        restaurants: [
          {
            'id': 1,
            'name': 'Pizza Roma',
            'description': null,
            'isAvailable': true,
            'photoUrl': null,
          },
        ],
        orders: [
          order(1, 'COMPLETED', [item(10, 'Pizza Reine')]),
          order(2, 'COMPLETED', [
            item(10, 'Pizza Reine'),
            item(11, 'Tiramisu'),
          ]),
          order(3, 'CANCELLED', [item(12, 'Calzone')]),
        ],
        menus: {
          1: [
            product(10, 'Pizza Reine'),
            product(11, 'Tiramisu'),
            product(12, 'Calzone'),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vos plus commandés'), findsOneWidget);
    expect(find.text('Commandé 2 fois'), findsOneWidget);
    expect(find.text('Déjà commandé'), findsOneWidget);
    // Only in a cancelled order: not a favourite.
    expect(find.text('Calzone'), findsNothing);

    await tester.tap(find.text('Pizza Reine'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('"Nouveautés" shows the restaurants added this month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    Map<String, dynamic> restaurant(int id, String name, int daysAgo) => {
      'id': id,
      'name': name,
      'description': null,
      'isAvailable': true,
      'photoUrl': null,
      'createdAt': now
          .subtract(Duration(days: daysAgo))
          .toUtc()
          .toIso8601String(),
    };

    await tester.pumpWidget(
      _wrap(
        restaurants: [
          restaurant(1, 'Le Vieux Port', 120),
          restaurant(2, 'Burger Lab', 3),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouveautés'), findsOneWidget);
    expect(find.text('NOUVEAU'), findsOneWidget);
    expect(find.text('Ajouté il y a 3 jours'), findsOneWidget);
    // Both still in the restaurant list; only the new one is "Nouveau".
    expect(find.text('Le Vieux Port'), findsOneWidget);
    expect(find.text('Burger Lab'), findsNWidgets(2));
  });

  testWidgets('open restaurants are listed before closed ones', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Map<String, dynamic> restaurant(int id, String name, bool open) => {
      'id': id,
      'name': name,
      'description': null,
      'isAvailable': open,
      'photoUrl': null,
    };

    await tester.pumpWidget(
      _wrap(
        restaurants: [
          restaurant(1, 'Fermé Tard', false),
          restaurant(2, 'Toujours Ouvert', true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Toujours Ouvert')).dy,
      lessThan(tester.getTopLeft(find.text('Fermé Tard')).dy),
    );
    expect(find.text('Fermé'), findsOneWidget);
  });

  testWidgets('"Les plus commandés" and "Restaurants populaires" '
      'show every customer\'s delivered orders', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final roma = {
      'id': 1,
      'name': 'Pizza Roma',
      'description': null,
      'isAvailable': true,
      'photoUrl': null,
    };
    await tester.pumpWidget(
      _wrap(
        popular: {
          'restaurants': [
            {...roma, 'orderCount': 42},
          ],
          'dishes': [
            {
              'id': 10,
              'name': 'Pizza Reine',
              'description': null,
              'price': '15.000',
              'isAvailable': true,
              'photoUrl': null,
              'restaurantId': 1,
              'categoryId': 1,
              'options': const [],
              'restaurant': roma,
              'orderCount': 17,
            },
          ],
          'windowDays': 30,
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Les plus commandés'), findsOneWidget);
    expect(
      find.text('Sur Delivery Hassen, ces 30 derniers jours'),
      findsOneWidget,
    );
    expect(find.text('17 commandes'), findsOneWidget);
    expect(find.text('Restaurants populaires'), findsOneWidget);
    expect(find.text('POPULAIRE'), findsOneWidget);
    expect(find.text('42 commandes'), findsOneWidget);

    await tester.tap(find.text('Pizza Reine'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('no popularity sections on a server without them', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Les plus commandés'), findsNothing);
    expect(find.text('Restaurants populaires'), findsNothing);
    expect(find.text('Factures'), findsOneWidget); // the rest still shows
  });

  testWidgets('no category row while no restaurant has a category', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(CategorySelector), findsNothing);
    expect(find.text('Que souhaitez-vous manger ?'), findsNothing);
    expect(find.text('Factures'), findsOneWidget); // the rest still shows
  });

  testWidgets('photos below the fold wait until scrolled near', (tester) async {
    // A phone's height (what's below the fold), wider only for the test
    // font, much wider than the real one; and a home full of photos.
    tester.view.physicalSize = const Size(2400, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Map<String, dynamic> restaurant(int id) => {
      'id': id,
      'name': 'Restaurant $id',
      'description': null,
      'isAvailable': true,
      'photoUrl': '/uploads/restaurants/r$id.jpg',
      'categories': const [],
    };
    Map<String, dynamic> dish(int id) => {
      'id': id,
      'name': 'Plat $id',
      'description': null,
      'price': '15.000',
      'isAvailable': true,
      'photoUrl': '/uploads/products/p$id.jpg',
      'restaurantId': 1,
      'categoryId': 1,
      'options': const [],
      'restaurant': restaurant(1),
      'orderCount': 10,
    };
    await tester.pumpWidget(
      _wrap(
        promotions: [
          for (var i = 1; i <= 5; i++)
            {
              ..._promotion(i, 'Promo $i'),
              'photoUrl': '/uploads/promotions/$i.jpg',
            },
        ],
        categories: [
          for (var i = 1; i <= 8; i++)
            {
              'id': i,
              'name': 'Catégorie $i',
              'icon': 'pizza',
              'imageUrl': '/uploads/restaurant-categories/c$i.jpg',
              'position': i,
            },
        ],
        restaurants: [for (var i = 1; i <= 20; i++) restaurant(i)],
        popular: {
          'restaurants': [
            for (var i = 1; i <= 10; i++) {...restaurant(i), 'orderCount': 9},
          ],
          'dishes': [for (var i = 1; i <= 10; i++) dish(i)],
          'windowDays': 30,
        },
      ),
    );
    await tester.pumpAndSettle();

    int built() => find.byType(AppPhoto, skipOffstage: false).evaluate().length;

    // 25 when the whole feed was built at once; now the first screen's and
    // a little more, just below (built ahead to scroll smoothly).
    final atOpening = built();
    expect(atOpening, lessThanOrEqualTo(15));

    // Scrolled to the bottom: the rest comes in, and what scrolled out of
    // sight is kept (not rebuilt, its photos not loaded again on return).
    final feed = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Les restaurants ouverts en premier'),
      400,
      scrollable: feed.first,
    );
    await tester.pumpAndSettle();
    expect(built(), greaterThan(atOpening));
    expect(find.text('Promo 1', skipOffstage: false), findsWidgets);
  });
}
