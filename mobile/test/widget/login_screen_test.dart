import 'dart:convert';

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
  String? refreshToken;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String? token) async => refreshToken = token;

  @override
  Future<void> clear() async {
    _token = null;
    refreshToken = null;
  }
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
        find.widgetWithText(TextFormField, 'Numéro de téléphone'),
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
      String? sentPhone;
      final auth = await _controllerWith(
        MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            sentPhone = (jsonDecode(request.body) as Map)['phone'] as String;
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
      // Pasted with the country code: the field keeps the local number.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numéro de téléphone'),
        '+216 21 000 001',
      );
      expect(find.text('21 000 001'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'courier1234',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(sentPhone, '21000001');
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.account!.name, 'Awa');
    });

    testWidgets('a server error reads as plain words, not a status code', (
      tester,
    ) async {
      final auth = await _controllerWith(
        MockClient((request) async => jsonResponse({'detail': 'boom'}, 500)),
      );

      await tester.pumpWidget(_pumpableApp(auth));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numéro de téléphone'),
        '21000001',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'courier1234',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Le service est momentanément indisponible. Réessayez dans un instant.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('signs up from the login screen', (tester) async {
      Map<String, dynamic>? registered;
      final auth = await _controllerWith(
        MockClient((request) async {
          switch (request.url.path) {
            case '/api/auth/register':
              registered = jsonDecode(request.body) as Map<String, dynamic>;
              return jsonResponse({'id': 9}, 201);
            case '/api/auth/login':
              return jsonResponse({'token': 'jwt-9'});
            case '/api/auth/me':
              return jsonResponse({
                'id': 9,
                'name': 'Sami Ben Ali',
                'phone': '22123456',
                'roles': ['ROLE_CLIENT'],
                'isVerified': true,
              });
          }
          return jsonResponse({'message': 'unexpected'}, 404);
        }),
      );

      await tester.pumpWidget(_pumpableApp(auth));
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom et prénom'),
        'Sami Ben Ali',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numéro de téléphone'),
        '22123456',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'court',
      );
      await tester.tap(find.text('Créer mon compte'));
      await tester.pump();
      // Too short: the field says so, nothing is sent.
      expect(find.text('Au moins 8 caractères'), findsOneWidget);
      expect(registered, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'assez-long',
      );
      await tester.tap(find.text('Créer mon compte'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The creation screen, steps ticking off, then the welcome.
      expect(
        find.text('Votre compte est en cours de création'),
        findsOneWidget,
      );
      expect(find.text('Vérification de votre numéro…'), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(registered, {
        'name': 'Sami Ben Ali',
        'phone': '22123456',
        'password': 'assez-long',
      });
      expect(auth.status, AuthStatus.signedIn);
      expect(find.text('Bienvenue, Sami !'), findsOneWidget);
      expect(find.text('Votre compte est prêt.'), findsOneWidget);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Bienvenue, Sami !'), findsNothing);
    });

    testWidgets('a number already registered comes back to the form, '
        'with the reason', (tester) async {
      final auth = await _controllerWith(
        MockClient((request) async {
          if (request.url.path == '/api/auth/register') {
            return jsonResponse({'message': 'Déjà pris'}, 409);
          }
          return jsonResponse({'message': 'unexpected'}, 404);
        }),
      );

      await tester.pumpWidget(_pumpableApp(auth));
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom et prénom'),
        'Sami Ben Ali',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numéro de téléphone'),
        '22123456',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'assez-long',
      );
      await tester.tap(find.text('Créer mon compte'));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text("Le compte n'a pas pu être créé"), findsOneWidget);
      expect(
        find.text('Un compte existe déjà avec ce numéro.'),
        findsOneWidget,
      );
      expect(auth.status, isNot(AuthStatus.signedIn));

      await tester.tap(find.text('Modifier mes informations'));
      await tester.pumpAndSettle();
      // Back on the form, which keeps what was typed and shows why.
      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(
        find.text('Un compte existe déjà avec ce numéro.'),
        findsOneWidget,
      );
    });
  });
}
