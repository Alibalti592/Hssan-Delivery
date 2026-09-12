import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/dashboard/dashboard_screen.dart';
import 'package:mobile/deliveries/deliveries_controller.dart';
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

Map<String, dynamic> _delivery(
  int id, {
  required String status,
  String? deliveredAt,
}) => {
  'id': id,
  'status': status,
  'courierId': 3,
  'assignedAt': '2026-01-01T08:00:00+00:00',
  'acceptedAt': null,
  'pickedUpAt': null,
  'deliveredAt': deliveredAt,
  'order': {
    'id': 100 + id,
    'restaurantName': 'Le Bon Resto',
    'customerName': 'Client',
    'customerPhone': '22000000',
    'deliveryAddress': '12 Rue de la Paix',
    'note': null,
    'deliveryFee': '3.000',
    'totalAmount': '25.000',
    'items': [],
  },
};

void main() {
  testWidgets(
    'shows the courier greeting, delivered-today count, and pending proposals',
    (tester) async {
      final now = DateTime.now().toUtc().toIso8601String();

      final mock = MockClient((request) async {
        if (request.url.path == '/api/deliveries/mine') {
          return jsonResponse(
            pagedBody([
              _delivery(1, status: 'ASSIGNED'),
              _delivery(2, status: 'ASSIGNED'),
              _delivery(3, status: 'DELIVERED', deliveredAt: now),
            ]),
          );
        }
        return jsonResponse({'message': 'unexpected'}, 404);
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
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      // The dashboard triggers DeliveriesController.refresh() itself via a
      // post-frame callback; let that round-trip complete.
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget); // delivered today
      expect(find.text('2'), findsOneWidget); // pending proposals
      expect(
        find.text('2 nouvelle(s) course(s) disponible(s)'),
        findsOneWidget,
      );
      expect(find.text('Aucune course en cours'), findsOneWidget);
    },
  );
}
