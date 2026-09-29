import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/bills/bill_form_screen.dart';
import 'package:mobile/bills/bill_models.dart';
import 'package:mobile/bills/bills_repository.dart';
import 'package:mobile/client/order_confirmed_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/order_models.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

const _steg = BillProvider(id: 1, name: 'STEG', kind: BillProviderKind.bill);
const _wafa = BillProvider(
  id: 6,
  name: 'Wafa Cash',
  kind: BillProviderKind.transfer,
);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Map<String, dynamic> _billOrder({String? photoUrl}) => {
  'id': 42,
  'restaurantId': null,
  'items': [],
  'note': null,
  'pickupAddress': 'Rue de Marseille',
  'deliveryAddress': 'Rue de Marseille',
  'recipientName': null,
  'recipientPhone': null,
  'deliveryZoneId': 1,
  'deliveryZoneName': 'Centre-ville',
  'deliveryFee': '5.000',
  'totalAmount': '90.500',
  'status': 'PENDING',
  'deliveryType': 'BILL',
  'createdAt': '2026-01-01T08:00:00+00:00',
  'deliveryStatus': 'PENDING',
  'courierName': null,
  'courierPhone': null,
  'bill': {
    'providerId': 1,
    'providerName': 'STEG',
    'providerKind': 'BILL',
    'providerLogoUrl': null,
    'reference': '1234567',
    'amount': '85.500',
    'photoUrl': photoUrl,
  },
};

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app(
  MockClient mock,
  BillProvider provider, {
  BillPhotoPicker? pickPhoto,
}) {
  final api = ApiClient(
    tokenProvider: () => 'jwt-123',
    onUnauthorized: () {},
    httpClient: mock,
  );
  return MultiProvider(
    providers: [
      Provider<OrdersRepository>.value(value: OrdersRepository(api)),
      Provider<BillsRepository>.value(value: BillsRepository(api)),
    ],
    child: MaterialApp(
      home: BillFormScreen(provider: provider, pickPhoto: pickPhoto),
    ),
  );
}

Future<void> _pickZone(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<DeliveryZoneOption>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Centre-ville — 5.000 DT').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'pays a bill: shows the cash to hand over, then sends the order and its photo',
    (tester) async {
      _useTallViewport(tester);
      Map<String, dynamic>? posted;
      String? photoUploadPath;
      final mock = MockClient((request) async {
        switch (request.url.path) {
          case '/api/delivery-zones':
            return jsonResponse([
              {'id': 1, 'name': 'Centre-ville', 'fee': '5.000'},
            ]);
          case '/api/orders/bills':
            posted = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse(_billOrder(), 201);
          case '/api/orders/42/bill-photo':
            photoUploadPath = request.url.path;
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data'),
            );
            return jsonResponse(
              _billOrder(photoUrl: '/api/orders/42/bill-photo'),
            );
        }
        fail('unexpected ${request.url}');
      });

      await tester.pumpWidget(
        _app(
          mock,
          _steg,
          pickPhoto: (source) async =>
              XFile.fromData(_png, name: 'facture.png'),
        ),
      );
      await tester.pumpAndSettle();

      // A mandat's fields aren't asked for a bill.
      expect(find.text('Nom du bénéficiaire'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Référence de la facture'),
        '1234567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Montant de la facture'),
        '85,5',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Votre adresse'),
        'Rue de Marseille',
      );
      await _pickZone(tester);

      expect(find.text('90.500 DT'), findsOneWidget);

      await tester.tap(find.text('Caméra'));
      await tester.pumpAndSettle();
      expect(find.text('Retirer'), findsOneWidget);

      await tester.tap(find.text('PAYER LA FACTURE'));
      await tester.pumpAndSettle();

      expect(posted, {
        'providerId': 1,
        'amount': '85.5',
        'address': 'Rue de Marseille',
        'deliveryZoneId': 1,
        'reference': '1234567',
      });
      expect(photoUploadPath, '/api/orders/42/bill-photo');
      expect(find.byType(OrderConfirmedScreen), findsOneWidget);
      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.text('À remettre au livreur'), findsOneWidget);
    },
  );

  testWidgets('a mandat asks who receives the money, and no photo', (
    tester,
  ) async {
    _useTallViewport(tester);
    Map<String, dynamic>? posted;
    final mock = MockClient((request) async {
      if (request.url.path == '/api/delivery-zones') {
        return jsonResponse([
          {'id': 1, 'name': 'Centre-ville', 'fee': '5.000'},
        ]);
      }
      posted = jsonDecode(request.body) as Map<String, dynamic>;
      final order = _billOrder()
        ..['recipientName'] = 'Mohamed'
        ..['recipientPhone'] = '98765432'
        ..['bill'] = {
          'providerId': 6,
          'providerName': 'Wafa Cash',
          'providerKind': 'TRANSFER',
          'providerLogoUrl': null,
          'reference': null,
          'amount': '300.000',
          'photoUrl': null,
        };
      return jsonResponse(order, 201);
    });

    await tester.pumpWidget(_app(mock, _wafa));
    await tester.pumpAndSettle();

    expect(find.text('Référence de la facture'), findsNothing);
    expect(find.text('Photo de la facture (optionnel)'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom du bénéficiaire'),
      'Mohamed',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone du bénéficiaire'),
      '98765432',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Montant à envoyer'),
      '300',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Votre adresse'),
      'Rue de Marseille',
    );
    await _pickZone(tester);

    await tester.tap(find.text('ENVOYER LE MANDAT'));
    await tester.pumpAndSettle();

    expect(posted, {
      'providerId': 6,
      'amount': '300',
      'address': 'Rue de Marseille',
      'deliveryZoneId': 1,
      'recipientName': 'Mohamed',
      'recipientPhone': '98765432',
    });
    expect(find.byType(OrderConfirmedScreen), findsOneWidget);
  });

  testWidgets('rejects an amount above the cash limit without sending', (
    tester,
  ) async {
    _useTallViewport(tester);
    final mock = MockClient((request) async {
      if (request.url.path == '/api/delivery-zones') {
        return jsonResponse([
          {'id': 1, 'name': 'Centre-ville', 'fee': '5.000'},
        ]);
      }
      fail('should not submit an invalid form');
    });

    await tester.pumpWidget(_app(mock, _steg));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Référence de la facture'),
      'R1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Montant de la facture'),
      '2500',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Votre adresse'),
      'Rue de Marseille',
    );
    await _pickZone(tester);

    await tester.tap(find.text('PAYER LA FACTURE'));
    await tester.pumpAndSettle();

    expect(find.text('Maximum 2000 DT par demande'), findsOneWidget);
    expect(find.byType(OrderConfirmedScreen), findsNothing);
  });
}
