import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/auth/delete_account_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? _token;
  String? _refresh;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> writeRefreshToken(String? token) async => _refresh = token;

  @override
  Future<void> clear() async {
    _token = null;
    _refresh = null;
  }
}

Future<(AuthController, List<Object?>)> _signedIn() async {
  final deletions = <Object?>[];
  late final AuthController auth;
  auth = AuthController(
    repository: AuthRepository(
      ApiClient(
        tokenProvider: () => auth.token,
        onUnauthorized: () {},
        httpClient: MockClient((request) async {
          switch ('${request.method} ${request.url.path}') {
            case 'POST /api/auth/login':
              return jsonResponse({'token': 'jwt', 'refreshToken': 'r'});
            case 'GET /api/auth/me':
              return jsonResponse({
                'id': 5,
                'name': 'Sami',
                'phone': '22000001',
                'roles': ['ROLE_CLIENT'],
                'isVerified': true,
              });
            case 'DELETE /api/auth/me':
              final password = (jsonDecode(request.body) as Map)['password'];
              deletions.add(password);
              return password == 'client1234'
                  ? http.Response('', 204)
                  : jsonResponse({'message': 'Mot de passe incorrect.'}, 400);
          }
          return jsonResponse({'message': 'unexpected'}, 404);
        }),
      ),
    ),
    storage: _MemoryTokenStorage(),
  );
  await auth.signIn('22000001', 'client1234');
  return (auth, deletions);
}

Widget _app(AuthController auth) => ChangeNotifierProvider.value(
  value: auth,
  child: const MaterialApp(home: DeleteAccountScreen()),
);

void main() {
  testWidgets('a wrong password deletes nothing and says why', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (auth, deletions) = await _signedIn();

    await tester.pumpWidget(_app(auth));
    await tester.enterText(find.byType(TextFormField), 'oops-wrong');
    await tester.tap(find.text('SUPPRIMER MON COMPTE'));
    await tester.pumpAndSettle();
    // Asked once more before anything happens.
    expect(find.text('Supprimer définitivement ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(deletions, ['oops-wrong']);
    expect(find.text('Mot de passe incorrect.'), findsOneWidget);
    expect(auth.status, AuthStatus.signedIn);
  });

  testWidgets('cancelling the confirmation sends nothing', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (auth, deletions) = await _signedIn();

    await tester.pumpWidget(_app(auth));
    await tester.enterText(find.byType(TextFormField), 'client1234');
    await tester.tap(find.text('SUPPRIMER MON COMPTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(deletions, isEmpty);
  });

  testWidgets('the right password deletes the account and signs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (auth, deletions) = await _signedIn();

    await tester.pumpWidget(_app(auth));
    await tester.enterText(find.byType(TextFormField), 'client1234');
    await tester.tap(find.text('SUPPRIMER MON COMPTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    // In the app the signed-out root replaces this screen; alone in a
    // test it stays, spinner and all, so don't wait for it to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(deletions, ['client1234']);
    expect(auth.status, AuthStatus.signedOut);
    expect(find.text('Votre compte a été supprimé.'), findsOneWidget);
  });
}
