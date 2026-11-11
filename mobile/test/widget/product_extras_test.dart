import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/client/product_detail_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/order_models.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

/// A sandwich at 8.000: free sauces (several, optional), paid extras
/// (several, optional) and a required drink (one).
Product _sandwich() => Product.fromJson({
  'id': 5,
  'name': 'Chapati',
  'description': null,
  'price': '8.000',
  'isAvailable': true,
  'photoUrl': null,
  'restaurantId': 7,
  'categoryId': 3,
  'options': [],
  'extraGroups': [
    {
      'name': 'Sauces',
      'required': false,
      'multiple': true,
      'choices': [
        {'name': 'Harissa', 'price': '0.000'},
        {'name': 'Mayonnaise', 'price': '0.000'},
      ],
    },
    {
      'name': 'Suppléments',
      'required': false,
      'multiple': true,
      'choices': [
        {'name': 'Fromage', 'price': '1.500'},
      ],
    },
    {
      'name': 'Boisson',
      'required': true,
      'multiple': false,
      'choices': [
        {'name': 'Eau', 'price': '1.000'},
        {'name': 'Coca-Cola', 'price': '2.500'},
      ],
    },
  ],
});

const _harissa = PickedExtra(group: 'Sauces', name: 'Harissa', price: '0.000');
const _coca = PickedExtra(group: 'Boisson', name: 'Coca-Cola', price: '2.500');

void main() {
  group('cart', () {
    test('extras are priced into the line, and make it a line of its own', () {
      final cart = CartController();
      cart.add(_sandwich(), restaurantName: 'Snack', extras: [_harissa, _coca]);
      // The same picks in another order: the same line.
      cart.add(_sandwich(), restaurantName: 'Snack', extras: [_coca, _harissa]);
      cart.add(_sandwich(), restaurantName: 'Snack');

      expect(cart.lines, hasLength(2));
      final withExtras = cart.lines.first;
      expect(withExtras.quantity, 2);
      expect(withExtras.unitPrice, '10.500');
      expect(withExtras.lineTotal, closeTo(21, 1e-9));
      expect(withExtras.extrasLabel, 'Sauces : Harissa · Boisson : Coca-Cola');
      expect(cart.lines.last.unitPrice, '8.000');
      expect(cart.subtotal, closeTo(29, 1e-9));
      expect(cart.quantityOf(5), 3);
    });

    test('the order sends each extra by group and name', () async {
      Map<String, dynamic>? sent;
      final repository = OrdersRepository(
        ApiClient(
          tokenProvider: () => 'jwt',
          onUnauthorized: () {},
          httpClient: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse({
              'id': 1,
              'restaurantId': 7,
              'items': [
                {
                  'productId': 5,
                  'productName': 'Chapati',
                  'quantity': 1,
                  'unitPrice': '10.500',
                  'option': null,
                  'extras': [
                    {'group': 'Sauces', 'name': 'Harissa', 'price': '0.000'},
                    {'group': 'Boisson', 'name': 'Coca-Cola', 'price': '2.500'},
                  ],
                },
              ],
              'deliveryAddress': 'Bizerte',
              'deliveryZoneId': 1,
              'deliveryFee': '4.000',
              'totalAmount': '14.500',
              'status': 'PENDING',
              'createdAt': '2026-01-01T08:00:00+00:00',
            }, 201);
          }),
        ),
      );
      final cart = CartController()
        ..add(_sandwich(), restaurantName: 'Snack', extras: [_harissa, _coca])
        ..add(_sandwich(), restaurantName: 'Snack');

      final order = await repository.createOrder(
        restaurantId: 7,
        items: cart.lines,
        deliveryAddress: 'Bizerte',
        deliveryZoneId: 1,
      );

      final items = sent!['items'] as List<dynamic>;
      expect(items.first, {
        'productId': 5,
        'quantity': 1,
        'extras': [
          {'group': 'Sauces', 'choice': 'Harissa'},
          {'group': 'Boisson', 'choice': 'Coca-Cola'},
        ],
      });
      // Without extras, nothing extra is sent.
      expect(items.last, {'productId': 5, 'quantity': 1});

      // And they come back with the order, for its detail screen.
      final OrderItemLine line = order.items.single;
      expect(line.extrasLabel, 'Sauces : Harissa · Boisson : Coca-Cola');
    });
  });

  testWidgets('the customer ticks sauces, extras and a drink', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cart = CartController();
    await tester.pumpWidget(
      ChangeNotifierProvider<CartController>.value(
        value: cart,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        product: _sandwich(),
                        restaurantName: 'Snack',
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sauces'), findsOneWidget);
    expect(find.text('Gratuit'), findsNWidgets(2));
    expect(find.text('+1.500 DT'), findsOneWidget);
    expect(find.text('Choisissez-en 1'), findsOneWidget);
    expect(find.text('Obligatoire'), findsOneWidget);
    expect(find.text('Facultatif'), findsNWidgets(2));

    // The drink is required: the button says so, and takes the customer to
    // it instead of adding.
    await tester.tap(find.text('Choisir : Boisson'));
    await tester.pumpAndSettle();
    expect(find.text('Faites un choix pour continuer'), findsOneWidget);
    expect(cart.lines, isEmpty);

    await tester.tap(find.text('Harissa'));
    await tester.tap(find.text('Mayonnaise'));
    await tester.tap(find.text('Fromage'));
    await tester.tap(find.text('Eau'));
    await tester.pump();
    expect(find.text('Ajouter · 10.500 DT'), findsOneWidget);
    expect(find.text('Faites un choix pour continuer'), findsNothing);
    expect(find.text('2 choisis'), findsOneWidget);

    // One drink only: Coca-Cola replaces the water.
    await tester.tap(find.text('Coca-Cola'));
    // A second tap on a sauce removes it.
    await tester.tap(find.text('Mayonnaise'));
    await tester.pump();
    expect(find.text('Ajouter · 12.000 DT'), findsOneWidget);

    // Two of them: the total follows.
    await tester.tap(find.byTooltip('Plus'));
    await tester.pump();
    expect(find.text('Ajouter · 24.000 DT'), findsOneWidget);

    await tester.tap(find.text('Ajouter · 24.000 DT'));
    await tester.pumpAndSettle();

    // A shortcut to the cart in the confirmation.
    expect(find.text('VOIR LE PANIER'), findsOneWidget);

    final line = cart.lines.single;
    expect(line.extras.map((e) => '${e.group}/${e.name}'), [
      'Sauces/Harissa',
      'Suppléments/Fromage',
      'Boisson/Coca-Cola',
    ]);
    expect(line.unitPrice, '12.000');
    expect(line.quantity, 2);
  });

  testWidgets('an optional drink: nothing to pick to add the dish', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final product = Product.fromJson({
      'id': 6,
      'name': 'Makloub',
      'description': null,
      'price': '9.000',
      'isAvailable': true,
      'photoUrl': null,
      'restaurantId': 7,
      'categoryId': 3,
      'extraGroups': [
        {
          'name': 'Boisson',
          'required': false,
          'multiple': false,
          'choices': [
            {'name': 'Coca-Cola', 'price': '2.500'},
          ],
        },
      ],
    });
    final cart = CartController();
    await tester.pumpWidget(
      ChangeNotifierProvider<CartController>.value(
        value: cart,
        child: MaterialApp(
          home: ProductDetailScreen(product: product, restaurantName: 'Snack'),
        ),
      ),
    );

    expect(find.text('Facultatif'), findsOneWidget);
    expect(find.text('Un seul choix possible'), findsOneWidget);
    expect(find.text('Obligatoire'), findsNothing);

    await tester.tap(find.text('Ajouter · 9.000 DT'));
    await tester.pump();

    expect(cart.lines.single.extras, isEmpty);
    expect(cart.lines.single.unitPrice, '9.000');
  });
}
