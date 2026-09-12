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
import 'package:mobile/notifications/notifications_repository.dart';
import 'package:mobile/notifications/push_notification_service.dart';
import 'package:mobile/orders/orders_repository.dart';

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

/// Wraps a list in the backend's `{"items": [...], "meta": {...}}`
/// pagination envelope, matching what PagedResult.fromJson expects.
Map<String, dynamic> _pagedBody(List<dynamic> items) => {
  'items': items,
  'meta': {'page': 1, 'limit': 20, 'total': items.length, 'pages': 1},
};

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
      expect(auth.account!.name, 'Awa');
      expect(await storage.read(), 'jwt-123');
    });

    test('signs in a client and stores the token', () async {
      final storage = _MemoryTokenStorage();
      final mock = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return _json({'token': 'jwt-456'});
        }
        if (request.url.path == '/api/auth/me') {
          expect(request.headers['Authorization'], 'Bearer jwt-456');
          return _json({
            'id': 9,
            'name': 'Sami',
            'phone': '22000001',
            'roles': ['ROLE_CLIENT', 'ROLE_USER'],
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

      final error = await auth.signIn('22000001', 'client1234');

      expect(error, isNull);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.account!.isClient, isTrue);
      expect(auth.account!.isCourier, isFalse);
      expect(await storage.read(), 'jwt-456');
    });

    test(
      'rejects an account with neither role, without persisting a token',
      () async {
        final storage = _MemoryTokenStorage();
        final mock = MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return _json({'token': 'jwt-xyz'});
          }
          return _json({
            'id': 1,
            'name': 'Admin',
            'phone': '20000000',
            'roles': ['ROLE_ADMIN', 'ROLE_USER'],
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

        final error = await auth.signIn('20000000', 'admin1234');

        expect(error, contains('client'));
        expect(auth.status, isNot(AuthStatus.signedIn));
        expect(await storage.read(), isNull);
      },
    );

    test('register creates the account then signs in', () async {
      final storage = _MemoryTokenStorage();
      var registerCalled = false;
      final mock = MockClient((request) async {
        if (request.url.path == '/api/auth/register') {
          registerCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['phone'], '22000099');
          return _json({
            'id': 42,
            'name': 'Nouveau Client',
            'phone': '22000099',
            'roles': ['ROLE_CLIENT'],
            'isVerified': true,
          }, 201);
        }
        if (request.url.path == '/api/auth/login') {
          return _json({'token': 'jwt-new'});
        }
        return _json({
          'id': 42,
          'name': 'Nouveau Client',
          'phone': '22000099',
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

      final error = await auth.register(
        name: 'Nouveau Client',
        phone: '22000099',
        password: 'client1234',
      );

      expect(registerCalled, isTrue);
      expect(error, isNull);
      expect(auth.status, AuthStatus.signedIn);
      expect(await storage.read(), 'jwt-new');
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
      expect(error, 'Numéro ou mot de passe incorrect.');
    });

    test('changePassword succeeds and keeps the session', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/auth/change-password');
        expect(request.headers['Authorization'], 'Bearer jwt-1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['currentPassword'], 'oldPass123');
        expect(body['newPassword'], 'newPass456');
        return http.Response('', 204);
      });

      final auth = AuthController(
        repository: AuthRepository(
          ApiClient(
            tokenProvider: () => 'jwt-1',
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
        storage: _MemoryTokenStorage(),
      );

      final error = await auth.changePassword(
        currentPassword: 'oldPass123',
        newPassword: 'newPass456',
      );

      expect(error, isNull);
    });

    test('changePassword surfaces the backend error message', () async {
      final mock = MockClient(
        (request) async =>
            _json({'message': 'Mot de passe actuel incorrect.'}, 400),
      );

      final auth = AuthController(
        repository: AuthRepository(
          ApiClient(
            tokenProvider: () => 'jwt-1',
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
        storage: _MemoryTokenStorage(),
      );

      final error = await auth.changePassword(
        currentPassword: 'wrong',
        newPassword: 'newPass456',
      );

      expect(error, 'Mot de passe actuel incorrect.');
    });
  });

  group('DeliveriesController', () {
    test('lists deliveries with active ones first', () async {
      final mock = MockClient((request) async {
        return _json(
          _pagedBody([
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
          ]),
        );
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
          return _json(
            _pagedBody([
              {
                'id': 5,
                'status': 'ASSIGNED',
                'courierId': 3,
                'order': {'id': 20, 'status': 'CONFIRMED', 'items': []},
              },
            ]),
          );
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

    test('a declined delivery is dropped from the list', () async {
      final mock = MockClient((request) async {
        if (request.method == 'GET') {
          return _json(
            _pagedBody([
              {
                'id': 6,
                'status': 'ASSIGNED',
                'courierId': 3,
                'order': {'id': 21, 'status': 'CONFIRMED', 'items': []},
              },
            ]),
          );
        }
        expect(request.url.path, '/api/deliveries/6/decline');
        return _json({
          'id': 6,
          'status': 'PENDING',
          'courierId': null,
          'order': {'id': 21, 'status': 'PENDING', 'items': []},
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
        DeliveryAction.decline,
      );

      expect(error, isNull);
      expect(controller.byId(6), isNull);
      expect(controller.deliveries, isEmpty);
    });

    test('loadMoreHistory appends the next page', () async {
      final mock = MockClient((request) async {
        final page = request.url.queryParameters['page'];
        if (page == '2') {
          return _json({
            'items': [
              {
                'id': 1,
                'status': 'DELIVERED',
                'courierId': 3,
                'order': {'id': 9, 'status': 'COMPLETED', 'items': []},
              },
            ],
            'meta': {'page': 2, 'limit': 1, 'total': 2, 'pages': 2},
          });
        }
        return _json({
          'items': [
            {
              'id': 2,
              'status': 'ASSIGNED',
              'courierId': 3,
              'order': {'id': 10, 'status': 'CONFIRMED', 'items': []},
            },
          ],
          'meta': {'page': 1, 'limit': 1, 'total': 2, 'pages': 2},
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
      expect(controller.hasMoreHistory, isTrue);
      expect(controller.history, isEmpty);
      expect(controller.active.map((d) => d.id), [2]);

      final error = await controller.loadMoreHistory();

      expect(error, isNull);
      expect(controller.hasMoreHistory, isFalse);
      expect(controller.history.map((d) => d.id), [1]);
      // The active delivery from page 1 must still be there.
      expect(controller.active.map((d) => d.id), [2]);
    });
  });

  group('OrdersRepository', () {
    test('listOrders unwraps the paginated envelope', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/orders');
        expect(request.url.queryParameters['page'], '2');
        return _json({
          'items': [
            {
              'id': 42,
              'restaurantId': 1,
              'items': [],
              'deliveryAddress': 'Tunis',
              'deliveryZoneId': 1,
              'deliveryZoneName': 'Centre',
              'deliveryFee': '4.000',
              'totalAmount': '20.000',
              'status': 'PENDING',
            },
          ],
          'meta': {'page': 2, 'limit': 1, 'total': 2, 'pages': 2},
        });
      });

      final repository = OrdersRepository(
        ApiClient(
          tokenProvider: () => 'jwt',
          onUnauthorized: () {},
          httpClient: mock,
        ),
      );

      final result = await repository.listOrders(page: 2);

      expect(result.items.map((o) => o.id), [42]);
      expect(result.page, 2);
      expect(result.pages, 2);
      expect(result.hasMore, isFalse);
    });
  });

  group('NotificationsRepository', () {
    test('registerDeviceToken posts the token and platform', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/notifications/device-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token'], 'abc123');
        expect(body['platform'], 'android');
        return http.Response('', 204);
      });

      final repository = NotificationsRepository(
        ApiClient(
          tokenProvider: () => 'jwt',
          onUnauthorized: () {},
          httpClient: mock,
        ),
      );

      await repository.registerDeviceToken('abc123', platform: 'android');
    });

    test('unregisterDeviceToken sends a DELETE with the token', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/notifications/device-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token'], 'abc123');
        return http.Response('', 204);
      });

      final repository = NotificationsRepository(
        ApiClient(
          tokenProvider: () => 'jwt',
          onUnauthorized: () {},
          httpClient: mock,
        ),
      );

      await repository.unregisterDeviceToken('abc123');
    });
  });

  group('PushNotificationService', () {
    // No FIREBASE_* --dart-define is set in test runs, so
    // AppConfig.firebaseConfigured is false and every method below must
    // stay a safe no-op without ever touching the Firebase plugin — which
    // has no platform channel to answer it in a plain `flutter test` run.
    test('is inert without a Firebase config', () async {
      var repositoryCalled = false;
      final mock = MockClient((request) async {
        repositoryCalled = true;
        return http.Response('', 204);
      });

      final service = PushNotificationService(
        NotificationsRepository(
          ApiClient(
            tokenProvider: () => 'jwt',
            onUnauthorized: () {},
            httpClient: mock,
          ),
        ),
      );

      await service.initialize();
      await service.registerForCurrentUser();
      await service.unregister();

      expect(repositoryCalled, isFalse);
    });

    test(
      'AuthController sign-in/sign-out work with an unconfigured push service',
      () async {
        final mock = MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return _json({'token': 'jwt-push'});
          }
          return _json({
            'id': 1,
            'name': 'Push Test',
            'phone': '21000009',
            'roles': ['ROLE_CLIENT', 'ROLE_USER'],
            'isVerified': true,
          });
        });

        late final AuthController auth;
        final api = ApiClient(
          tokenProvider: () => auth.token,
          onUnauthorized: () {},
          httpClient: mock,
        );
        final pushNotifications = PushNotificationService(
          NotificationsRepository(api),
        );
        auth = AuthController(
          repository: AuthRepository(api),
          storage: _MemoryTokenStorage(),
          pushNotifications: pushNotifications,
        );

        await pushNotifications.initialize();
        final error = await auth.signIn('21000009', 'password123');
        expect(error, isNull);
        expect(auth.status, AuthStatus.signedIn);

        await auth.signOut();
        expect(auth.status, AuthStatus.signedOut);
      },
    );
  });
}
