import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/client/order_detail_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _order({
  required String status,
  String? deliveryStatus,
  String? courierName,
  String? courierPhone,
}) => {
  'id': 1,
  'restaurantId': 1,
  'items': [],
  'note': null,
  'deliveryAddress': '1 Rue de la Paix',
  'deliveryZoneId': 1,
  'deliveryZoneName': 'Centre-ville',
  'deliveryFee': '3.000',
  'totalAmount': '25.000',
  'status': status,
  'createdAt': '2026-01-01T08:00:00+00:00',
  'deliveryStatus': deliveryStatus,
  'courierName': courierName,
  'courierPhone': courierPhone,
};

Widget _app(OrdersRepository repository) {
  return Provider<OrdersRepository>.value(
    value: repository,
    child: const MaterialApp(home: OrderDetailScreen(orderId: 1)),
  );
}

/// Tall enough that the whole scrollable body (map, timeline, courier card,
/// items, cancel button) renders without scrolling — off-screen content
/// isn't built by the underlying sliver list, so find.text() would
/// otherwise miss it.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('cancels a still-pending order and hides the cancel button', (
    tester,
  ) async {
    _useTallViewport(tester);
    var cancelCalled = false;
    final mock = MockClient((request) async {
      if (request.method == 'POST') {
        cancelCalled = true;
        return jsonResponse(
          _order(status: 'CANCELLED', deliveryStatus: 'CANCELLED'),
        );
      }
      return jsonResponse(_order(status: 'PENDING', deliveryStatus: 'PENDING'));
    });

    final repository = OrdersRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Annuler la commande'), findsOneWidget);

    await tester.tap(find.text('Annuler la commande'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, annuler'));
    await tester.pumpAndSettle();

    expect(cancelCalled, isTrue);
    expect(find.text('Annuler la commande'), findsNothing);
  });

  testWidgets('shows the courier and a call button once assigned', (
    tester,
  ) async {
    _useTallViewport(tester);
    final mock = MockClient(
      (request) async => jsonResponse(
        _order(
          status: 'CONFIRMED',
          deliveryStatus: 'ASSIGNED',
          courierName: 'Sami Courier',
          courierPhone: '22000000',
        ),
      ),
    );

    final repository = OrdersRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Sami Courier'), findsOneWidget);
    expect(find.text('Appeler'), findsOneWidget);
    // Still cancellable while just assigned (not yet accepted).
    expect(find.text('Annuler la commande'), findsOneWidget);
  });

  testWidgets('hides the cancel button once the courier has accepted', (
    tester,
  ) async {
    _useTallViewport(tester);
    final mock = MockClient(
      (request) async => jsonResponse(
        _order(
          status: 'CONFIRMED',
          deliveryStatus: 'ACCEPTED',
          courierName: 'Sami Courier',
          courierPhone: '22000000',
        ),
      ),
    );

    final repository = OrdersRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Annuler la commande'), findsNothing);
  });
}
