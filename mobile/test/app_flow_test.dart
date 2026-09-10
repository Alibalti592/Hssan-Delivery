import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:mobile/deliveries/deliveries_controller.dart';
import 'package:mobile/deliveries/delivery.dart';
import 'package:mobile/deliveries/delivery_repository.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('AuthController', () {
    test('signs in a courier and stores the token', () async {
      final storage = _MemoryTokenStorage();
      final mock = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return _json({'token': 'jwt-123'});
        }
        if (request.url.path == '/api/auth/me') {
          expect(request.headers['Authorization'], 'Bearer jwt-123');
          return _json({
            'id': 3,
            'name': 'Awa',
            'phone': '21000001',
            'roles': ['ROLE_LIVREUR', 'ROLE_USER'],
            'isVerified': true,
          });
        }
        return _json({'message': 'unexpected'}, 404);
      });

      late final AuthController auth;
      auth = AuthController(
        repository: AuthRepository(
          ApiClient(
            tokenProvider: () => auth.token,
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
        storage: storage,
      );

      final error = await auth.signIn('21000001', 'courier1234');

      expect(error, isNull);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.courier!.name, 'Awa');
      expect(await storage.read(), 'jwt-123');
    });

    test('rejects a non-courier account without persisting a token', () async {
      final storage = _MemoryTokenStorage();
      final mock = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return _json({'token': 'jwt-xyz'});
        }
        return _json({
          'id': 9,
          'name': 'Client',
          'phone': '22000001',
          'roles': ['ROLE_CLIENT', 'ROLE_USER'],
          'isVerified': true,
        });
      });

      late final AuthController auth;
      auth = AuthController(
        repository: AuthRepository(
          ApiClient(
            tokenProvider: () => auth.token,
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
        storage: storage,
      );

      final error = await auth.signIn('22000001', 'client1234');

      expect(error, contains('not a courier'));
      expect(auth.status, isNot(AuthStatus.signedIn));
      expect(await storage.read(), isNull);
    });

    test('maps a 401 to a friendly message', () async {
      final mock = MockClient(
        (request) async => _json({'message': 'Invalid credentials.'}, 401),
      );
      final auth = AuthController(
        repository: AuthRepository(
          ApiClient(
            tokenProvider: () => null,
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
        storage: _MemoryTokenStorage(),
      );

      final error = await auth.signIn('21000001', 'wrong');
      expect(error, 'Wrong phone number or password.');
    });
  });

  group('DeliveriesController', () {
    test('lists deliveries with active ones first', () async {
      final mock = MockClient((request) async {
        return _json([
          {
            'id': 1,
            'status': 'DELIVERED',
            'courierId': 3,
            'assignedAt': '2026-09-10T08:00:00+00:00',
            'order': {'id': 10, 'status': 'COMPLETED', 'items': []},
          },
          {
            'id': 2,
            'status': 'ON_THE_WAY',
            'courierId': 3,
            'assignedAt': '2026-09-10T09:00:00+00:00',
            'order': {'id': 11, 'status': 'READY_FOR_PICKUP', 'items': []},
          },
        ]);
      });

      final controller = DeliveriesController(
        DeliveryRepository(
          ApiClient(
            tokenProvider: () => 'jwt',
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
      );

      await controller.refresh();

      expect(controller.error, isNull);
      expect(controller.deliveries.first.id, 2);
      expect(controller.active.map((d) => d.id), [2]);
      expect(controller.history.map((d) => d.id), [1]);
    });

    test('perform swaps in the updated delivery', () async {
      final mock = MockClient((request) async {
        if (request.method == 'GET') {
          return _json([
            {
              'id': 5,
              'status': 'ASSIGNED',
              'courierId': 3,
              'order': {'id': 20, 'status': 'CONFIRMED', 'items': []},
            },
          ]);
        }
        expect(request.url.path, '/api/deliveries/5/accept');
        return _json({
          'id': 5,
          'status': 'ACCEPTED',
          'courierId': 3,
          'order': {'id': 20, 'status': 'CONFIRMED', 'items': []},
        });
      });

      final controller = DeliveriesController(
        DeliveryRepository(
          ApiClient(
            tokenProvider: () => 'jwt',
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
      );

      await controller.refresh();
      final error = await controller.perform(
        controller.deliveries.first,
        DeliveryAction.accept,
      );

      expect(error, isNull);
      expect(controller.byId(5)!.status, DeliveryStatus.accepted);
    });
  });
}
