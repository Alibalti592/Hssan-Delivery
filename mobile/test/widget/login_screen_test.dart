import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/auth/login_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

Future<AuthController> _controllerWith(MockClient mock) async {
  late final AuthController auth;
  auth = AuthController(
    repository: AuthRepository(
      ApiClient(
        tokenProvider: () => auth.token,
        onUnauthorized: () {},
        httpClient: mock,
      ),
    ),
    storage: _MemoryTokenStorage(),
  );
  // Mirrors _Root's real startup flow (main.dart): bootstrap() always runs
  // before LoginScreen is shown, and with no stored token it settles on
  // signedOut synchronously — so tests see the same starting state a real
  // login attempt would.
  await auth.bootstrap();
  return auth;
}

Widget _pumpableApp(AuthController auth) {
  return ChangeNotifierProvider<AuthController>.value(
    value: auth,
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows validation errors instead of submitting when empty', (
      tester,
    ) async {
      var loginCalled = false;
      final auth = await _controllerWith(
        MockClient((request) async {
          loginCalled = true;
          return jsonResponse({'message': 'unexpected'}, 404);
        }),
      );

      await tester.pumpWidget(_pumpableApp(auth));
      await tester.tap(find.text('Se connecter'));
      await tester.pump();

      expect(find.text('Numéro requis'), findsOneWidget);
      expect(find.text('Mot de passe requis'), findsOneWidget);
      expect(loginCalled, isFalse);
    });

    testWidgets('shows an inline error on invalid credentials', (tester) async {
      final auth = await _controllerWith(
        MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return jsonResponse({'message': 'Invalid credentials'}, 401);
          }
          return jsonResponse({'message': 'unexpected'}, 404);
        }),
      );

      await tester.pumpWidget(_pumpableApp(auth));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone'),
        '21000001',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'wrong-password',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('Numéro ou mot de passe incorrect.'), findsOneWidget);
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('signs a courier in on valid credentials', (tester) async {
      final auth = await _controllerWith(
        MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return jsonResponse({'token': 'jwt-123'});
          }
          if (request.url.path == '/api/auth/me') {
            return jsonResponse({
              'id': 3,
              'name': 'Awa',
              'phone': '21000001',
              'roles': ['ROLE_LIVREUR'],
              'isVerified': true,
            });
          }
          return jsonResponse({'message': 'unexpected'}, 404);
        }),
      );

      await tester.pumpWidget(_pumpableApp(auth));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone'),
        '21000001',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'courier1234',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(auth.status, AuthStatus.signedIn);
      expect(auth.account!.name, 'Awa');
    });
  });
}
