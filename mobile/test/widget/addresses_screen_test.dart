import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/addresses/address_repository.dart';
import 'package:mobile/addresses/pin_map.dart';
import 'package:mobile/addresses/selected_address.dart';
import 'package:mobile/client/addresses_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _address({
  int id = 1,
  String label = 'Domicile',
  String addressLine = '12 Rue de la Corniche',
  String? instructions,
  bool isDefault = false,
  int? zoneId = 1,
}) => {
  'id': id,
  'label': label,
  'addressLine': addressLine,
  'instructions': instructions,
  'isDefault': isDefault,
  'deliveryZoneId': zoneId,
  'deliveryZoneName': zoneId == null ? null : 'Bizerte centre',
  'deliveryZoneFee': zoneId == null ? null : '4.000',
  'latitude': null,
  'longitude': null,
};

const _zones = [
  {'id': 1, 'name': 'Bizerte centre', 'fee': '4.000'},
  {'id': 2, 'name': 'Corniche', 'fee': '5.000'},
];

Widget _app(MockClient mock) {
  final api = ApiClient(
    tokenProvider: () => 'jwt-123',
    onUnauthorized: () {},
    httpClient: mock,
  );
  final addresses = AddressRepository(api);
  return MultiProvider(
    providers: [
      Provider<AddressRepository>.value(value: addresses),
      Provider<OrdersRepository>.value(value: OrdersRepository(api)),
      ChangeNotifierProvider(
        create: (_) => SelectedAddressController(addresses),
      ),
    ],
    child: const MaterialApp(home: AddressesScreen()),
  );
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => PinMap.offline = true);

  testWidgets('shows each address with its zone and fee', (tester) async {
    final mock = MockClient(
      (request) async => jsonResponse([
        _address(isDefault: true),
        _address(id: 2, label: 'Travail', zoneId: null),
      ]),
    );

    await tester.pumpWidget(_app(mock));
    await tester.pumpAndSettle();

    expect(find.text('Domicile'), findsOneWidget);
    expect(find.text('Par défaut'), findsOneWidget);
    expect(find.text('Bizerte centre · 4.000 DT'), findsOneWidget);
    // Saved before zones were asked for: flagged, fixed at checkout.
    expect(find.text('Zone à choisir'), findsOneWidget);
  });

  testWidgets('adds an address with a label chip and its zone', (tester) async {
    _useTallViewport(tester);
    Map<String, dynamic>? posted;

    final mock = MockClient((request) async {
      if (request.url.path == '/api/delivery-zones') {
        return jsonResponse(_zones);
      }
      if (request.method == 'POST') {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(_address(label: 'Travail', zoneId: 2), 201);
      }
      return jsonResponse(posted == null ? [] : [_address(label: 'Travail')]);
    });

    await tester.pumpWidget(_app(mock));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AJOUTER UNE ADRESSE'));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle adresse'), findsOneWidget);
    expect(
      find.text('Déplacez la carte pour placer le repère'),
      findsOneWidget,
    );

    await tester.tap(find.text('Travail'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adresse'),
      'Avenue Habib Bourguiba',
    );
    await tester.tap(find.text('ENREGISTRER'));
    await tester.pumpAndSettle();

    // The zone is required.
    expect(find.text('Choisissez la zone'), findsOneWidget);
    expect(posted, isNull);

    await tester.tap(find.text('Zone de livraison'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corniche — 5.000 DT').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENREGISTRER'));
    await tester.pumpAndSettle();

    expect(posted, {
      'label': 'Travail',
      'addressLine': 'Avenue Habib Bourguiba',
      'isDefault': false,
      'deliveryZoneId': 2,
    });
    expect(find.text('Travail'), findsOneWidget);
  });

  testWidgets('edits a saved address and refreshes the list', (tester) async {
    _useTallViewport(tester);
    var address = _address();
    var putCalled = false;

    final mock = MockClient((request) async {
      if (request.url.path == '/api/delivery-zones') {
        return jsonResponse(_zones);
      }
      if (request.method == 'PUT') {
        putCalled = true;
        return jsonResponse(address);
      }
      return jsonResponse([address]);
    });

    await tester.pumpWidget(_app(mock));
    await tester.pumpAndSettle();

    expect(find.text('Domicile'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Modifier l\'adresse'), findsOneWidget);

    // "Domicile" isn't one of the chips, so it's under "Autre".
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom de l\'adresse'),
      'Bureau',
    );

    // Reflects what the fake PUT response returns once the list reloads.
    address = _address(label: 'Bureau');

    await tester.tap(find.text('MODIFIER'));
    await tester.pumpAndSettle();

    expect(putCalled, isTrue);
    expect(find.text('Bureau'), findsOneWidget);
  });

  testWidgets('deletes a saved address after confirmation', (tester) async {
    var deleted = false;

    final mock = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted = true;
        return http.Response('', 204);
      }
      return jsonResponse(deleted ? [] : [_address()]);
    });

    await tester.pumpWidget(_app(mock));
    await tester.pumpAndSettle();

    expect(find.text('Domicile'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer cette adresse ?'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.text('Domicile'), findsNothing);
    expect(find.text('Aucune adresse enregistrée.'), findsOneWidget);
  });
}
