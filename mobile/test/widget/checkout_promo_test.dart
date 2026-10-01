import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/addresses/address_repository.dart';
import 'package:mobile/addresses/selected_address.dart';
import 'package:mobile/cart/cart.dart';
import 'package:mobile/catalogue/catalogue_models.dart';
import 'package:mobile/client/checkout_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/orders/orders_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Map<String, dynamic> _quote({
  required String discount,
  required String total,
  String? title,
  String? code,
}) => {
  'subtotal': '24.000',
  'discountAmount': discount,
  'deliveryFee': '4.000',
  'totalAmount': total,
  'promotionTitle': title,
  'promoCode': code,
};

void main() {
  late List<Map<String, dynamic>> placed;

  Future<Widget> app() async {
    placed = [];
    final api = ApiClient(
      tokenProvider: () => 'jwt-123',
      onUnauthorized: () {},
      httpClient: MockClient((http.Request request) async {
        final path = request.url.path;
        if (path == '/api/addresses') {
          return jsonResponse([
            {
              'id': 1,
              'label': 'Maison',
              'addressLine': '12 Rue de Marseille',
              'instructions': null,
              'isDefault': true,
              'deliveryZoneId': 1,
              'deliveryZoneName': 'Bizerte centre',
              'deliveryZoneFee': '4.000',
            },
          ]);
        }
        if (path == '/api/delivery-zones') {
          return jsonResponse([
            {'id': 1, 'name': 'Bizerte centre', 'fee': '4.000'},
          ]);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final code = body['promoCode'] as String?;
        if (path == '/api/orders/quote') {
          if (code == null) {
            return jsonResponse(
              _quote(
                discount: '2.400',
                total: '25.600',
                title: '-10 % chez Pizzeria',
              ),
            );
          }
          if (code == 'BIENVENUE') {
            return jsonResponse(
              _quote(
                discount: '5.000',
                total: '23.000',
                title: 'Bienvenue',
                code: 'BIENVENUE',
              ),
            );
          }
          return jsonResponse({
            'message': "Ce code promo n'est pas valable.",
          }, 400);
        }
        if (path == '/api/orders') {
          placed.add(body);
          return jsonResponse({
            'id': 9,
            'restaurantId': 1,
            'restaurantName': 'Pizzeria',
            'items': const [],
            'deliveryAddress': '12 Rue de Marseille',
            'deliveryZoneId': 1,
            'deliveryZoneName': 'Bizerte centre',
            'deliveryFee': '4.000',
            'totalAmount': '23.000',
            'discountAmount': '5.000',
            'promotionTitle': 'Bienvenue',
            'status': 'PENDING',
            'deliveryType': 'RESTAURANT',
          }, 201);
        }
        return jsonResponse({'message': 'unexpected $path'}, 404);
      }),
    );

    final addresses = AddressRepository(api);
    final selected = SelectedAddressController(addresses);
    await selected.load();
    final cart = CartController()
      ..add(
        Product(
          id: 3,
          name: 'Pizza',
          description: null,
          price: '12.000',
          isAvailable: true,
          photoUrl: null,
          restaurantId: 1,
          categoryId: 1,
        ),
        restaurantName: 'Pizzeria',
        quantity: 2,
      );

    return MultiProvider(
      providers: [
        Provider<AddressRepository>.value(value: addresses),
        ChangeNotifierProvider.value(value: selected),
        Provider<OrdersRepository>.value(value: OrdersRepository(api)),
        ChangeNotifierProvider.value(value: cart),
      ],
      child: const MaterialApp(home: CheckoutScreen()),
    );
  }

  testWidgets('shows the automatic promotion in the total', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    expect(find.text('-10 % chez Pizzeria'), findsOneWidget);
    expect(find.text('-2.400 DT'), findsOneWidget);
    expect(find.text('25.600 DT'), findsOneWidget);
    expect(find.text('Vous économisez 2.400 DT'), findsOneWidget);
  });

  testWidgets('a wrong code says why; the right one lowers the total and '
      'goes with the order', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    await tester.tap(find.text("J'ai un code promo"));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Code promo'),
      'FAUX',
    );
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    expect(find.text("Ce code promo n'est pas valable."), findsOneWidget);
    expect(find.text('25.600 DT'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Code promo'),
      'BIENVENUE',
    );
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    expect(find.text('Code BIENVENUE appliqué'), findsOneWidget);
    expect(find.text('-5.000 DT'), findsOneWidget);
    expect(find.text('23.000 DT'), findsOneWidget);

    await tester.tap(find.text('CONFIRMER LA COMMANDE'));
    await tester.pumpAndSettle();
    expect(placed.single['promoCode'], 'BIENVENUE');
  });
}
