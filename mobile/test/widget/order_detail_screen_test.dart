import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/addresses/pin_map.dart';
import 'package:mobile/client/order_detail_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/courier_position.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _order({
  required String status,
  String? deliveryStatus,
  String? courierName,
  String? courierPhone,
  double? deliveryLatitude,
  double? deliveryLongitude,
  double? pickupLatitude,
  double? pickupLongitude,
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
  'deliveryLatitude': deliveryLatitude,
  'deliveryLongitude': deliveryLongitude,
  'pickupLatitude': pickupLatitude,
  'pickupLongitude': pickupLongitude,
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

  testWidgets('a push about the order shows its new status at once', (
    tester,
  ) async {
    _useTallViewport(tester);
    var loads = 0;
    var courier = 'Sami Courier';
    final mock = MockClient((request) async {
      // The courier's position is polled too: count the order loads only.
      if (request.url.path.endsWith('/courier-location')) {
        return jsonResponse({'message': 'indisponible'}, 404);
      }
      loads++;
      return jsonResponse(
        _order(
          status: 'CONFIRMED',
          deliveryStatus: 'ACCEPTED',
          courierName: courier,
        ),
      );
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
    expect(find.text('Livreur en route vers le restaurant'), findsOneWidget);
    expect(find.text('Paiement en espèces à la livraison'), findsOneWidget);
    expect(loads, 1);

    courier = 'Nour Courier';
    repository.notifyChanged(2); // Another order: ignored.
    await tester.pumpAndSettle();
    expect(loads, 1);

    repository.notifyChanged(1);
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text('Nour Courier'), findsOneWidget);
  });

  testWidgets('a bill shows the bill steps and how to pay', (tester) async {
    _useTallViewport(tester);
    final mock = MockClient(
      (request) async => jsonResponse({
        ..._order(status: 'CONFIRMED', deliveryStatus: 'ACCEPTED'),
        'restaurantId': null,
        'deliveryType': 'BILL',
        'items': [],
        'bill': {
          'providerId': 1,
          'providerName': 'STEG',
          'providerKind': 'BILL',
          'reference': '123456',
          'amount': '85.500',
        },
      }),
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

    expect(find.text('Facture STEG'), findsWidgets);
    expect(find.text('Livreur en route vers vous'), findsOneWidget);
    expect(find.text('Reçu remis'), findsOneWidget);
    expect(find.text('En préparation'), findsNothing);
    expect(
      find.text('Paiement en espèces, à remettre au livreur'),
      findsOneWidget,
    );
  });

  group('following the courier', () {
    setUp(() => PinMap.offline = true);

    OrdersRepository repositoryWith({
      required String deliveryStatus,
      Map<String, dynamic>? courier,
    }) => OrdersRepository(
      ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/courier-location')) {
            return courier == null
                ? jsonResponse({'message': 'indisponible'}, 404)
                : jsonResponse(courier);
          }
          return jsonResponse(
            _order(
              status: 'READY_FOR_PICKUP',
              deliveryStatus: deliveryStatus,
              courierName: 'Awa',
              courierPhone: '22000003',
              pickupLatitude: 37.2700,
              pickupLongitude: 9.8600,
              deliveryLatitude: 37.2746,
              deliveryLongitude: 9.8739,
            ),
          );
        }),
      ),
    );

    testWidgets('on the way: the courier on the map, distance and arrival', (
      tester,
    ) async {
      _useTallViewport(tester);
      // About 1.2 km south of the client.
      await tester.pumpWidget(
        _app(
          repositoryWith(
            deliveryStatus: 'ON_THE_WAY',
            courier: {
              'latitude': 37.2638,
              'longitude': 9.8739,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Votre livreur arrive'), findsOneWidget);
      expect(find.text('à 1,2 km · environ 5 min'), findsOneWidget);
      expect(find.byTooltip('Votre livreur'), findsOneWidget);
    });

    testWidgets('before pickup: heading to the pickup point', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(
        _app(
          repositoryWith(
            deliveryStatus: 'ACCEPTED',
            courier: {
              'latitude': 37.2700,
              'longitude': 9.8650,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Votre livreur va chercher votre commande'),
        findsOneWidget,
      );
      expect(find.textContaining('du point de retrait'), findsOneWidget);
    });

    testWidgets('no position yet: says it is coming', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(
        _app(repositoryWith(deliveryStatus: 'PICKED_UP')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Votre livreur arrive'), findsOneWidget);
      expect(
        find.text("Sa position s'affichera sur la carte dans un instant."),
        findsOneWidget,
      );
      expect(find.byTooltip('Votre livreur'), findsNothing);
    });

    test('distances and arrival times read naturally', () {
      expect(formatDistance(0.32), '300 m');
      expect(formatDistance(0.01), '50 m');
      expect(formatDistance(1.24), '1,2 km');
      expect(estimatedMinutes(0.1), 1);
      expect(estimatedMinutes(1.2), 5);
    });
  });
}
