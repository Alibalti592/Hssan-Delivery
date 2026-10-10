import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/addresses/address_models.dart';
import 'package:mobile/addresses/address_repository.dart';
import 'package:mobile/addresses/selected_address.dart';
import 'package:mobile/client/order_confirmed_screen.dart';
import 'package:mobile/client/parcel_form_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/order_models.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

/// Tall enough that the whole form renders without scrolling.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The client's current address ("LIVRER À"): where the Colis is collected.
final _home = SavedAddress(
  id: 3,
  label: 'Maison',
  addressLine: '1 Rue de la Paix',
  instructions: null,
  isDefault: true,
  zone: DeliveryZoneOption(id: 1, name: 'Centre-ville', fee: '5.000'),
  latitude: 37.27,
  longitude: 9.87,
);

/// The client's saved addresses: the recipient's is one of them.
List<Map<String, dynamic>> _addresses() => [
  {
    'id': 3,
    'label': 'Maison',
    'addressLine': '1 Rue de la Paix',
    'instructions': null,
    'isDefault': true,
    'deliveryZoneId': 1,
    'deliveryZoneName': 'Centre-ville',
    'deliveryZoneFee': '5.000',
    'latitude': 37.27,
    'longitude': 9.87,
  },
  {
    'id': 4,
    'label': 'Chez Sami',
    'addressLine': '2 Avenue Habib Bourguiba',
    'instructions': 'Porte bleue',
    'isDefault': false,
    'deliveryZoneId': 1,
    'deliveryZoneName': 'Centre-ville',
    'deliveryZoneFee': '5.000',
    'latitude': 37.29,
    'longitude': 9.86,
  },
];

Map<String, dynamic> _parcelOrder() => {
  'id': 42,
  'restaurantId': null,
  'items': [],
  'note': null,
  'pickupAddress': '1 Rue de la Paix',
  'deliveryAddress': '2 Avenue Habib Bourguiba — Porte bleue',
  'recipientName': 'Sami Client',
  'recipientPhone': '22000000',
  'deliveryZoneId': 2,
  'deliveryZoneName': 'Corniche',
  'deliveryFee': '6.000',
  'totalAmount': '6.000',
  'status': 'PENDING',
  'deliveryType': 'PARCEL',
  'createdAt': '2026-01-01T08:00:00+00:00',
  'deliveryStatus': 'PENDING',
  'courierName': null,
  'courierPhone': null,
};

Widget _app(MockClient mock, {SavedAddress? current}) {
  final api = ApiClient(
    tokenProvider: () => 'jwt-123',
    onUnauthorized: () {},
    httpClient: mock,
  );
  final addresses = AddressRepository(api);
  final selected = SelectedAddressController(addresses);
  if (current != null) selected.select(current);
  return MultiProvider(
    providers: [
      Provider<OrdersRepository>.value(value: OrdersRepository(api)),
      Provider<AddressRepository>.value(value: addresses),
      ChangeNotifierProvider.value(value: selected),
    ],
    child: const MaterialApp(home: ParcelFormScreen()),
  );
}

void main() {
  testWidgets(
    "collects at the sender's address, delivers where the recipient's pin is",
    (tester) async {
      _useTallViewport(tester);
      Map<String, dynamic>? posted;
      final located = <String>[];
      final mock = MockClient((request) async {
        switch (request.url.path) {
          case '/api/addresses':
            return jsonResponse(_addresses());
          case '/api/delivery-zones/locate':
            located.add(request.url.query);
            // Chez Sami's pin is in the Corniche, whatever was saved.
            return jsonResponse(
              request.url.queryParameters['latitude'] == '37.29'
                  ? {'id': 2, 'name': 'Corniche', 'fee': '6.000'}
                  : {'id': 1, 'name': 'Centre-ville', 'fee': '5.000'},
            );
        }
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(_parcelOrder(), 201);
      });

      await tester.pumpWidget(_app(mock, current: _home));
      await tester.pumpAndSettle();

      // Pickup is pre-filled from "LIVRER À"; its zone isn't needed.
      expect(find.text('Maison'), findsOneWidget);
      expect(located, isEmpty);
      // No zone to choose anywhere.
      expect(find.byType(DropdownButtonFormField), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom du destinataire'),
        'Sami Client',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone du destinataire'),
        '22000000',
      );
      await tester.tap(find.text("Placer l'adresse sur la carte"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chez Sami'));
      await tester.pumpAndSettle();

      expect(located, hasLength(1));
      expect(find.text('Corniche · 6.000 DT'), findsOneWidget);

      await tester.tap(find.text('ENVOYER LE COLIS'));
      await tester.pumpAndSettle();

      expect(posted, {
        'pickupLatitude': 37.27,
        'pickupLongitude': 9.87,
        'deliveryLatitude': 37.29,
        'deliveryLongitude': 9.86,
        'pickupAddress': '1 Rue de la Paix',
        'deliveryAddress': '2 Avenue Habib Bourguiba — Porte bleue',
        'recipientName': 'Sami Client',
        'recipientPhone': '22000000',
        'deliveryZoneId': 2,
      });
      expect(find.byType(OrderConfirmedScreen), findsOneWidget);
      expect(find.text('Colis envoyé'), findsOneWidget);
    },
  );

  testWidgets("a recipient outside every zone can't be sent to", (
    tester,
  ) async {
    _useTallViewport(tester);
    final mock = MockClient((request) async {
      switch (request.url.path) {
        case '/api/addresses':
          return jsonResponse(_addresses());
        case '/api/delivery-zones/locate':
          return jsonResponse({'message': 'Hors zone'}, 404);
      }
      fail('should not submit outside every zone');
    });

    await tester.pumpWidget(_app(mock, current: _home));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Placer l'adresse sur la carte"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chez Sami'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nous ne livrons pas encore à cette adresse.'),
      findsOneWidget,
    );
    await tester.tap(find.text('ENVOYER LE COLIS'));
    await tester.pumpAndSettle();
  });

  testWidgets('shows validation errors instead of submitting when empty', (
    tester,
  ) async {
    _useTallViewport(tester);
    final mock = MockClient((request) async {
      fail('should not submit when the form is invalid');
    });

    await tester.pumpWidget(_app(mock));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ENVOYER LE COLIS'));
    await tester.pumpAndSettle();

    // Neither the pickup nor the recipient's address is chosen yet.
    expect(find.text('Choisissez une adresse'), findsNWidgets(2));
    expect(find.text('Nom requis'), findsOneWidget);
  });
}
