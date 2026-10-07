import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/auth/auth_controller.dart';
import 'package:mobile/auth/auth_repository.dart';
import 'package:mobile/auth/login_screen.dart';
import 'package:mobile/client/profile_screen.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/support.dart';
import 'package:mobile/core/token_storage.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

class _NoStorage extends TokenStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<void> writeRefreshToken(String? token) async {}
  @override
  Future<void> clear() async {}
}

Future<AuthController> _signedOut() async {
  late final AuthController auth;
  auth = AuthController(
    repository: AuthRepository(
      ApiClient(
        tokenProvider: () => auth.token,
        onUnauthorized: () {},
        httpClient: MockClient((_) async => jsonResponse({}, 404)),
      ),
    ),
    storage: _NoStorage(),
  );
  await auth.bootstrap();
  return auth;
}

Widget _app(AuthController auth, Widget home) => ChangeNotifierProvider.value(
  value: auth,
  child: MaterialApp(home: home),
);

void main() {
  late Future<bool> Function(Uri) realOpen;
  final opened = <Uri>[];
  var opens = true;

  setUp(() {
    realOpen = Support.open;
    opened.clear();
    opens = true;
    Support.open = (uri) async {
      opened.add(uri);
      return opens;
    };
  });
  tearDown(() => Support.open = realOpen);

  testWidgets(
    '"Mot de passe oublié ?" writes to support on WhatsApp with the number',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(await _signedOut(), const LoginScreen()));

      await tester.enterText(find.byType(TextFormField).first, '22 000 001');
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe oublié ?'), findsNWidgets(2));
      await tester.tap(find.text('ÉCRIRE SUR WHATSAPP'));
      await tester.pumpAndSettle();

      final uri = opened.single;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/21698141009');
      expect(
        uri.queryParameters['text'],
        "Bonjour, j'ai oublié mon mot de passe Delivery Hassen. "
        'Mon numéro : 22 000 001',
      );
      // Done: the sheet closes behind WhatsApp.
      expect(find.text('ÉCRIRE SUR WHATSAPP'), findsNothing);
    },
  );

  testWidgets('says the number when WhatsApp cannot open', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    opens = false;
    await tester.pumpWidget(_app(await _signedOut(), const LoginScreen()));

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ÉCRIRE SUR WHATSAPP'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Impossible d'ouvrir l'application. Contactez-nous au 98 141 009.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Aide / Contact" in the profile calls support', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(await _signedOut(), const Scaffold(body: ProfileScreen())),
    );

    await tester.tap(find.text('Aide / Contact'));
    await tester.pumpAndSettle();
    expect(find.text("Besoin d'aide ?"), findsOneWidget);

    await tester.tap(find.text('APPELER LE 98 141 009'));
    await tester.pumpAndSettle();

    expect(opened.single.toString(), 'tel:+21698141009');
  });
}
