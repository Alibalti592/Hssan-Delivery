import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_repository.dart';
import 'package:mobile/client/cart_screen.dart';
import 'package:mobile/client/orders_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _order(
  int id, {
  String status = 'PENDING',
  String? deliveryStatus,
  List<Map<String, dynamic>> items = const [],
}) => {
  'id': id,
  'restaurantId': 1,
  'restaurantName': 'Pizza Roma',
  'items': items,
  'note': null,
  'deliveryAddress': '$id Rue de la Paix',
  'deliveryZoneId': 1,
  'deliveryZoneName': 'Centre-ville',
  'deliveryFee': '3.000',
  'totalAmount': '25.000',
  'status': status,
  'deliveryStatus': deliveryStatus,
  'deliveryType': 'RESTAURANT',
  'createdAt': '2026-01-0${id}T08:00:00+00:00',
};

ApiClient _api(MockClient mock) => ApiClient(
  tokenProvider: () => 'jwt-123',
  onUnauthorized: () {},
  httpClient: mock,
);

Widget _app(ApiClient api, {CartController? cart}) => MultiProvider(
  providers: [
    Provider<OrdersRepository>.value(value: OrdersRepository(api)),
    Provider<CatalogueRepository>.value(value: CatalogueRepository(api)),
    ChangeNotifierProvider<CartController>.value(
      value: cart ?? CartController(),
    ),
  ],
  child: const MaterialApp(home: Scaffold(body: OrdersScreen())),
);

void main() {
  testWidgets('lists orders and loads the next page on demand', (tester) async {
    final mock = MockClient((request) async {
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      if (page == 1) {
        return jsonResponse(
          pagedBody([_order(1), _order(2)], page: 1, pages: 2),
        );
      }
      return jsonResponse(pagedBody([_order(3)], page: 2, pages: 2));
    });

    await tester.pumpWidget(_app(_api(mock)));
    await tester.pumpAndSettle();

    expect(find.textContaining('#1'), findsOneWidget);
    expect(find.textContaining('#2'), findsOneWidget);
    expect(find.textContaining('#3'), findsNothing);
    expect(find.text('Charger plus'), findsOneWidget);

    await tester.tap(find.text('Charger plus'));
    await tester.pumpAndSettle();

    expect(find.textContaining('#3'), findsOneWidget);
    expect(find.text('Charger plus'), findsNothing);
  });

  testWidgets('the next page never repeats an order already shown', (
    tester,
  ) async {
    final mock = MockClient((request) async {
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      if (page == 1) {
        return jsonResponse(
          pagedBody([_order(3), _order(2)], page: 1, pages: 2),
        );
      }
      // An order placed since page 1 pushed #2 onto page 2.
      return jsonResponse(pagedBody([_order(2), _order(1)], page: 2, pages: 2));
    });

    await tester.pumpWidget(_app(_api(mock)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Charger plus'));
    await tester.pumpAndSettle();

    expect(find.textContaining('#1'), findsOneWidget);
    expect(find.textContaining('#2'), findsOneWidget);
    expect(find.textContaining('#3'), findsOneWidget);
  });

  testWidgets('shows what each order is, not just its number', (tester) async {
    final mock = MockClient(
      (request) async => jsonResponse(
        pagedBody([
          _order(
            1,
            status: 'READY_FOR_PICKUP',
            deliveryStatus: 'ON_THE_WAY',
            items: [
              {
                'productId': 7,
                'productName': 'Margherita',
                'quantity': 2,
                'unitPrice': '11.000',
              },
            ],
          ),
          {
            ..._order(2),
            'restaurantId': null,
            'restaurantName': null,
            'deliveryType': 'PARCEL',
            'recipientName': 'Sami',
          },
        ]),
      ),
    );

    await tester.pumpWidget(_app(_api(mock)));
    await tester.pumpAndSettle();

    expect(find.text('Pizza Roma'), findsOneWidget);
    expect(find.text('2× Margherita'), findsOneWidget);
    // Not the raw "Prête pour le retrait" for an order on its way.
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('Pour Sami'), findsOneWidget);
  });

  testWidgets('Recommander refills the cart at today\'s menu', (tester) async {
    final mock = MockClient((request) async {
      if (request.url.path == '/api/restaurants/1/products') {
        return jsonResponse(
          pagedBody([
            {
              'id': 7,
              'name': 'Margherita',
              'price': '12.000',
              'isAvailable': true,
              'restaurantId': 1,
              'categoryId': 1,
            },
          ]),
        );
      }
      return jsonResponse(
        pagedBody([
          _order(
            1,
            status: 'COMPLETED',
            deliveryStatus: 'DELIVERED',
            items: [
              {
                'productId': 7,
                'productName': 'Margherita',
                'quantity': 2,
                'unitPrice': '11.000',
              },
              {
                'productId': 8,
                'productName': 'Tiramisu',
                'quantity': 1,
                'unitPrice': '6.000',
              },
            ],
          ),
        ]),
      );
    });
    final cart = CartController();

    await tester.pumpWidget(_app(_api(mock), cart: cart));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recommander'));
    await tester.pumpAndSettle();

    expect(cart.itemCount, 2);
    expect(cart.lines.single.unitPrice, '12.000');
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Plus disponible : Tiramisu'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no orders', (tester) async {
    final mock = MockClient(
      (request) async => jsonResponse(pagedBody(const [])),
    );

    await tester.pumpWidget(_app(_api(mock)));
    await tester.pumpAndSettle();

    expect(find.text("Vous n'avez pas encore de commande."), findsOneWidget);
  });

  test('dates read like a person would say them', () {
    final now = DateTime(2026, 9, 30, 18);
    expect(
      formatOrderDate(DateTime(2026, 9, 30, 14, 5), now: now),
      "Aujourd'hui, 14:05",
    );
    expect(
      formatOrderDate(DateTime(2026, 9, 29, 20, 30), now: now),
      'Hier, 20:30',
    );
    expect(
      formatOrderDate(DateTime(2026, 9, 12, 19, 45), now: now),
      '12 sept., 19:45',
    );
    expect(
      formatOrderDate(DateTime(2025, 12, 1, 9, 0), now: now),
      '1 déc. 2025, 09:00',
    );
  });
}
