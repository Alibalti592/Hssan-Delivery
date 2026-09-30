import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/notifications/notification_prompt.dart';
import 'package:mobile/notifications/notifications_repository.dart';
import 'package:mobile/notifications/push_notification_service.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

/// Firebase isn't available in tests: this one says whether it would ask.
class _FakePush extends PushNotificationService {
  _FakePush({required this.needed})
    : super(
        NotificationsRepository(
          ApiClient(
            tokenProvider: () => null,
            onUnauthorized: () {},
            httpClient: MockClient((_) async => jsonResponse({})),
          ),
        ),
      );

  final bool needed;
  int requests = 0;

  @override
  Future<bool> needsPermission() async => needed;

  @override
  Future<bool> requestPermission() async {
    requests++;
    return true;
  }
}

Widget _app(_FakePush push, Widget child) =>
    Provider<PushNotificationService>.value(
      value: push,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('a client is offered notifications after ordering', (
    tester,
  ) async {
    final push = _FakePush(needed: true);
    await tester.pumpWidget(_app(push, const OrderNotificationsCard()));
    await tester.pumpAndSettle();

    expect(
      find.text('Soyez prévenu quand votre commande arrive'),
      findsOneWidget,
    );
    await tester.tap(find.text('Activer'));
    await tester.pumpAndSettle();

    expect(push.requests, 1);
    expect(
      find.text('Soyez prévenu quand votre commande arrive'),
      findsNothing,
    );
  });

  testWidgets('nothing is offered once notifications were decided', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakePush(needed: false), const OrderNotificationsCard()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Soyez prévenu quand votre commande arrive'),
      findsNothing,
    );
  });

  testWidgets('a courier is told why before the system prompt', (tester) async {
    final push = _FakePush(needed: true);
    await tester.pumpWidget(
      _app(
        push,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => askCourierForNotifications(context),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Ne ratez aucune course'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(push.requests, 0);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activer'));
    await tester.pumpAndSettle();
    expect(push.requests, 1);
  });
}
