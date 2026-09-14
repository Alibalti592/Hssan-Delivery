import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/client/order_confirmed_screen.dart';
import 'package:mobile/client/parcel_form_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/order_models.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

/// Tall enough that the whole scrollable form (four fields, the zone
/// dropdown, note, and the submit button) renders without scrolling.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

final _zones = [
  {'id': 1, 'name': 'Centre-ville', 'fee': '5.000'},
];

Map<String, dynamic> _parcelOrder() => {
  'id': 42,
  'restaurantId': null,
  'items': [],
  'note': null,
  'pickupAddress': '1 Rue de la Paix',
  'deliveryAddress': '2 Avenue Habib Bourguiba',
  'recipientName': 'Sami Client',
  'recipientPhone': '22000000',
  'deliveryZoneId': 1,
  'deliveryZoneName': 'Centre-ville',
  'deliveryFee': '5.000',
  'totalAmount': '5.000',
  'status': 'PENDING',
  'deliveryType': 'PARCEL',
  'createdAt': '2026-01-01T08:00:00+00:00',
  'deliveryStatus': 'PENDING',
  'courierName': null,
  'courierPhone': null,
};

Widget _app(OrdersRepository repository) {
  return Provider<OrdersRepository>.value(
    value: repository,
    child: const MaterialApp(home: ParcelFormScreen()),
  );
}

void main() {
  testWidgets('submits a parcel request and lands on the confirmation screen', (
    tester,
  ) async {
    _useTallViewport(tester);
    String? postedPath;
    final mock = MockClient((request) async {
      if (request.url.path == '/api/delivery-zones') {
        return jsonResponse(_zones);
      }
      postedPath = request.url.path;
      return jsonResponse(_parcelOrder(), 201);
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

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adresse de récupération'),
      '1 Rue de la Paix',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adresse de livraison'),
      '2 Avenue Habib Bourguiba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom du destinataire'),
      'Sami Client',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone du destinataire'),
      '22000000',
    );

    await tester.tap(find.byType(DropdownButtonFormField<DeliveryZoneOption>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centre-ville — 5.000 DT').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ENVOYER LE COLIS'));
    await tester.pumpAndSettle();

    expect(postedPath, '/api/orders/parcels');
    expect(find.byType(OrderConfirmedScreen), findsOneWidget);
    expect(find.text('Colis envoyé'), findsOneWidget);
  });

  testWidgets('shows validation errors instead of submitting when empty', (
    tester,
  ) async {
    _useTallViewport(tester);
    final mock = MockClient((request) async {
      if (request.url.path == '/api/delivery-zones') {
        return jsonResponse(_zones);
      }
      fail('should not submit when the form is invalid');
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

    await tester.tap(find.text('ENVOYER LE COLIS'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse requise'), findsNWidgets(2));
    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Téléphone requis'), findsOneWidget);
    expect(find.byType(OrderConfirmedScreen), findsNothing);
  });
}
