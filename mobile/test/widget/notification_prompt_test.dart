import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/notifications/notification_prompt.dart';
import 'package:mobile/notifications/notifications_repository.dart';
import 'package:mobile/notifications/push_notification_service.dart';
import 'package:mobile/theme.dart';
import 'package:provider/provider.dart';

/// Notifications never asked for yet, as on a fresh Android 13+ install.
class _FreshInstallPush extends PushNotificationService {
  _FreshInstallPush()
    : super(
        NotificationsRepository(
          ApiClient(tokenProvider: () => null, onUnauthorized: () {}),
        ),
      );

  int prompts = 0;

  @override
  Future<bool> needsPermission() async => true;

  @override
  Future<bool> requestPermission() async {
    prompts++;
    return true;
  }
}

Future<void> _openHome(WidgetTester tester, PushNotificationService push) {
  return tester.pumpWidget(
    Provider<PushNotificationService>.value(
      value: push,
      child: MaterialApp(
        // A button style without a family is drawn as boxes in tests (a
        // phone uses its own Roboto): named here for the screenshot.
        theme: Platform.environment['SHOT'] == null
            ? buildTheme()
            : buildTheme().copyWith(
                filledButtonTheme: FilledButtonThemeData(
                  style: buildTheme().filledButtonTheme.style?.copyWith(
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => askClientForNotifications(context),
            );
            return const Scaffold();
          },
        ),
      ),
    ),
  );
}

/// Only for a screenshot (SHOT=path): tests draw text as boxes otherwise.
Future<void> _loadRealFonts(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    final fonts = {
      'Roboto': ['Regular', 'Medium', 'Bold', 'ExtraBold'],
      'Poppins': ['Medium', 'SemiBold'],
    };
    for (final MapEntry(key: family, value: weights) in fonts.entries) {
      final loader = FontLoader(family);
      for (final weight in weights) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
      }
      await loader.load();
    }
    final icons = File(Platform.environment['ICONS']!).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('a customer is asked once, then the system prompt follows', (
    tester,
  ) async {
    if (Platform.environment['SHOT'] != null) await _loadRealFonts(tester);
    final push = _FreshInstallPush();
    await _openHome(tester, push);
    await tester.pumpAndSettle();

    expect(find.text('Ne ratez aucune offre'), findsOneWidget);
    if (Platform.environment['SHOT'] case final path?) {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
    }

    await tester.tap(find.text('Activer'));
    await tester.pumpAndSettle();
    expect(push.prompts, 1);

    // Next launch: not asked again.
    await tester.pumpWidget(const SizedBox());
    await _openHome(tester, push);
    await tester.pumpAndSettle();
    expect(find.text('Ne ratez aucune offre'), findsNothing);
  });

  testWidgets('"Plus tard" doesn\'t show the system prompt', (tester) async {
    final push = _FreshInstallPush();
    await _openHome(tester, push);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(push.prompts, 0);
  });
}
