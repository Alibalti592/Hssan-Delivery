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

/// A saved address the sheet offers for the drop-off.
Map<String, dynamic> _samiAddress() => {
  'id': 8,
  'label': 'Chez Sami',
  'addressLine': '2 Avenue Habib Bourguiba',
  'instructions': 'Porte bleue',
  'isDefault': false,
  'deliveryZoneId': 2,
  'deliveryZoneName': 'Corniche',
  'deliveryZoneFee': '6.000',
  'latitude': 37.29,
  'longitude': 9.86,
};

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
    'collects at the current address, delivers to one picked in the sheet',
    (tester) async {
      _useTallViewport(tester);
      Map<String, dynamic>? posted;
      final mock = MockClient((request) async {
        if (request.url.path == '/api/addresses') {
          return jsonResponse([_samiAddress()]);
        }
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(_parcelOrder(), 201);
      });

      await tester.pumpWidget(_app(mock, current: _home));
      await tester.pumpAndSettle();

      // Pickup is pre-filled from "LIVRER À".
      expect(find.text('Maison'), findsOneWidget);

      await tester.tap(find.text("Choisir l'adresse de livraison"));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle adresse'), findsOneWidget);
      await tester.tap(find.text('Chez Sami'));
      await tester.pumpAndSettle();

      // Its zone comes with it: no zone dropdown to fill.
      expect(find.text('Corniche · 6.000 DT'), findsOneWidget);
      expect(find.text('Zone de livraison'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom du destinataire'),
        'Sami Client',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone du destinataire'),
        '22000000',
      );

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

    expect(find.text('Choisissez une adresse'), findsNWidgets(2));
    expect(find.text('Nom requis'), findsOneWidget);
  });
}
