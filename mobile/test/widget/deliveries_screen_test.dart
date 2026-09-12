import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/deliveries/deliveries_controller.dart';
import 'package:mobile/deliveries/deliveries_screen.dart';
import 'package:mobile/deliveries/delivery_repository.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

class _MemoryTokenStorage extends TokenStorage {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

Map<String, dynamic> _delivery(int id, {required String status}) => {
  'id': id,
  'status': status,
  'courierId': 3,
  'assignedAt': '2026-01-0${id}T08:00:00+00:00',
  'acceptedAt': null,
  'pickedUpAt': null,
  'deliveredAt': status == 'DELIVERED' ? '2026-01-0${id}T09:00:00+00:00' : null,
  'order': {
    'id': 100 + id,
    'restaurantName': 'Restaurant $id',
    'customerName': 'Client',
    'customerPhone': '22000000',
    'deliveryAddress': '$id Rue de la Paix',
    'note': null,
    'deliveryFee': '3.000',
    'totalAmount': '25.000',
    'items': [],
  },
};

void main() {
  testWidgets(
    'shows active and history sections, and loads more history on demand',
    (tester) async {
      final requestedPage = <int>[];

      final mock = MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        requestedPage.add(page);

        if (page == 1) {
          return jsonResponse(
            pagedBody(
              [
                _delivery(1, status: 'ASSIGNED'),
                _delivery(2, status: 'DELIVERED'),
              ],
              page: 1,
              pages: 2,
            ),
          );
        }
        return jsonResponse(
          pagedBody([_delivery(3, status: 'DELIVERED')], page: 2, pages: 2),
        );
      });

      final api = ApiClient(
        tokenProvider: () => 'jwt-123',
        onUnauthorized: () {},
        httpClient: mock,
      );
      final deliveries = DeliveriesController(DeliveryRepository(api));
      final auth = AuthController(
        repository: AuthRepository(api),
        storage: _MemoryTokenStorage(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<DeliveriesController>.value(
              value: deliveries,
            ),
          ],
          child: const MaterialApp(home: DeliveriesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EN COURS (1)'), findsOneWidget);
      expect(find.text('Restaurant 1'), findsOneWidget);
      expect(find.text('Restaurant 2'), findsOneWidget);
      expect(find.text('Restaurant 3'), findsNothing);
      expect(find.text('Charger plus d\'historique'), findsOneWidget);

      await tester.tap(find.text('Charger plus d\'historique'));
      await tester.pumpAndSettle();

      expect(find.text('Restaurant 3'), findsOneWidget);
      expect(find.text('Charger plus d\'historique'), findsNothing);
      expect(requestedPage, [1, 2]);
    },
  );
}
