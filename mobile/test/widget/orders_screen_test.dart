import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/client/orders_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _order(int id) => {
  'id': id,
  'restaurantId': 1,
  'items': [],
  'note': null,
  'deliveryAddress': '$id Rue de la Paix',
  'deliveryZoneId': 1,
  'deliveryZoneName': 'Centre-ville',
  'deliveryFee': '3.000',
  'totalAmount': '25.000',
  'status': 'PENDING',
  'createdAt': '2026-01-0${id}T08:00:00+00:00',
};

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

    final repository = OrdersRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(
      Provider<OrdersRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: OrdersScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commande #1'), findsOneWidget);
    expect(find.text('Commande #2'), findsOneWidget);
    expect(find.text('Commande #3'), findsNothing);
    expect(find.text('Charger plus'), findsOneWidget);

    await tester.tap(find.text('Charger plus'));
    await tester.pumpAndSettle();

    expect(find.text('Commande #3'), findsOneWidget);
    expect(find.text('Charger plus'), findsNothing);
  });

  testWidgets('shows an empty state when there are no orders', (tester) async {
    final mock = MockClient(
      (request) async => jsonResponse(pagedBody(const [])),
    );
    final repository = OrdersRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(
      Provider<OrdersRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: OrdersScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Vous n'avez pas encore de commande."), findsOneWidget);
  });
}
