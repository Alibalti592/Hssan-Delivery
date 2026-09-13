import 'dart:convert';

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
  _MemoryTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
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

  testWidgets('toggles the real availability field via the API', (
    tester,
  ) async {
    final patchedTo = <bool>[];

    final mock = MockClient((request) async {
      if (request.url.path == '/api/deliveries/mine') {
        return jsonResponse(pagedBody(const []));
      }
      if (request.url.path == '/api/auth/me') {
        return jsonResponse({
          'id': 3,
          'name': 'Awa',
          'phone': '21000001',
          'roles': ['ROLE_LIVREUR'],
          'isVerified': true,
          'isAvailable': true,
        });
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/api/auth/availability') {
        patchedTo.add((jsonDecode(request.body) as Map)['isAvailable'] as bool);
        return jsonResponse({
          'id': 3,
          'name': 'Awa',
          'phone': '21000001',
          'roles': ['ROLE_LIVREUR'],
          'isVerified': true,
          'isAvailable': false,
        });
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
      storage: _MemoryTokenStorage('jwt-123'),
    );
    await auth.bootstrap();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<DeliveriesController>.value(value: deliveries),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vous êtes disponible'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(patchedTo, [false]);
    expect(find.text('Vous êtes hors-ligne'), findsOneWidget);
  });
}
