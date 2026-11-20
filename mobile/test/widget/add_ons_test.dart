import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/add_on_card.dart';
import 'package:mobile/catalogue/add_ons.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/cart_screen.dart';
import 'package:mobile/client/product_detail_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _category(int id, String name) => {
  'id': id,
  'name': name,
  'restaurantId': 4,
};

Map<String, dynamic> _product(
  int id,
  String name,
  int categoryId,
  String price, {
  List<dynamic> options = const [],
  bool available = true,
}) => {
  'id': id,
  'name': name,
  'description': null,
  'price': price,
  'isAvailable': available,
  'photoUrl': null,
  'restaurantId': 4,
  'categoryId': categoryId,
  'options': options,
};

/// A pizzeria's menu as restaurants really set it up: pizzas, then their
/// extras sold as items of their own.
final _categories = [
  _category(1, 'Pizza'),
  _category(2, 'Supplément sauces'),
  _category(3, 'Nos Supplèments'),
  _category(4, 'BOISSONS'),
];
final _products = [
  _product(10, 'Margherita', 1, '15.000'),
  _product(20, 'Sauce algérienne', 2, '1.000'),
  _product(30, 'Mozzarella', 3, '3.000'),
  _product(31, 'Jambon', 3, '2.500', available: false),
  _product(
    40,
    'Coca-Cola',
    4,
    '2.500',
    options: [
      {'name': '33 cl', 'price': '2.500'},
    ],
  ),
  _product(
    41,
    'Jus',
    4,
    '4.000',
    options: [
      {'name': 'Petit', 'price': '4.000'},
      {'name': 'Grand', 'price': '6.000'},
    ],
  ),
];

Widget _app(Widget child, CartController cart) {
  final api = ApiClient(
    tokenProvider: () => 'jwt',
    onUnauthorized: () {},
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/categories')) return jsonResponse(_categories);
      if (path.endsWith('/products')) return jsonResponse(pagedBody(_products));
      return jsonResponse(const []);
    }),
  );
  return MultiProvider(
    providers: [
      Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
      ChangeNotifierProvider<CartController>.value(value: cart),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => child)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AddOnKind.ofSection', () {
    test('reads the section names restaurants really use', () {
      expect(AddOnKind.ofSection('Supplément sauces'), AddOnKind.sauce);
      expect(AddOnKind.ofSection('BOISSONS'), AddOnKind.drink);
      expect(AddOnKind.ofSection('Boissons مشروبات'), AddOnKind.drink);
      expect(AddOnKind.ofSection('Nos Supplèments'), AddOnKind.supplement);
      expect(AddOnKind.ofSection('Suppléments اضافات'), AddOnKind.supplement);
      expect(AddOnKind.ofSection('Garnitures'), AddOnKind.supplement);
      expect(AddOnKind.ofSection('Supplément fromages'), AddOnKind.supplement);
      expect(AddOnKind.ofSection('Pizza'), isNull);
      expect(AddOnKind.ofSection('Desserts'), isNull);
    });
  });

  group('menuAddOns', () {
    final categories = [for (final c in _categories) MenuCategory.fromJson(c)];
    final products = [for (final p in _products) Product.fromJson(p)];

    test('only what can be added in one tap, by kind', () {
      final groups = menuAddOns(categories: categories, products: products);

      expect(groups.map((g) => g.kind), [
        AddOnKind.sauce,
        AddOnKind.supplement,
        AddOnKind.drink,
      ]);
      // Jambon is sold out; the juice has two sizes to choose from.
      expect(groups[1].products.map((p) => p.name), ['Mozzarella']);
      expect(groups[2].products.map((p) => p.name), ['Coca-Cola']);
      expect(addOnPrice(groups[2].products.single), '2.500');
    });

    test('nothing to add to an extra itself', () {
      expect(
        menuAddOns(
          categories: categories,
          products: products,
          forProduct: products.firstWhere((p) => p.id == 40),
        ),
        isEmpty,
      );
    });
  });

  testWidgets('a dish offers the restaurant’s extras, added with it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cart = CartController();
    final margherita = Product.fromJson(_products.first);
    await tester.pumpWidget(
      _app(
        ProductDetailScreen(product: margherita, restaurantName: 'Davvero'),
        cart,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Envie d’un petit plus ?'), findsOneWidget);
    // One row of cards you swipe sideways, drinks first: the cart's look.
    final cards = tester
        .widgetList<AddOnCard>(find.byType(AddOnCard))
        .map((c) => c.product.name)
        .toList();
    expect(cards.first, 'Coca-Cola');
    expect(cards, containsAll(['Sauce algérienne', 'Coca-Cola']));
    expect(find.text('15.000 DT'), findsWidgets);

    await tester.tap(find.text('Coca-Cola'));
    await tester.drag(find.byType(AddOnCard).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sauce algérienne'));
    await tester.pumpAndSettle();
    // Picked ones say so (a tick), and a second tap would take them back.
    expect(
      find.descendant(
        of: find.widgetWithText(AddOnCard, 'Coca-Cola'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    // 15 + 1 + 2.5, on the button.
    expect(find.text('18.500 DT'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(cart.lines.map((l) => l.product.name), [
      'Margherita',
      'Sauce algérienne',
      'Coca-Cola',
    ]);
    expect(cart.lines.last.option?.name, '33 cl');
    expect(cart.subtotal, closeTo(18.5, 1e-9));
    expect(
      find.text('Margherita et 2 extras ajoutés au panier'),
      findsOneWidget,
    );
  });

  testWidgets('the cart suggests the extras not in it yet', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cart = CartController()
      ..add(Product.fromJson(_products.first), restaurantName: 'Davvero');
    await tester.pumpWidget(_app(const CartScreen(), cart));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Complétez votre commande'), findsOneWidget);
    expect(find.text('Coca-Cola'), findsOneWidget);

    await tester.tap(find.text('Coca-Cola'));
    await tester.pumpAndSettle();

    expect(cart.quantityOf(40), 1);
    expect(cart.subtotal, closeTo(17.5, 1e-9));
    // In the cart now, so no longer suggested: shown once, as a line.
    expect(find.text('Coca-Cola (33 cl)'), findsOneWidget);
  });
}
