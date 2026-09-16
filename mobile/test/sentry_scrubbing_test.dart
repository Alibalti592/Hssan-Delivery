import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sentry_scrubbing.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('scrubSensitiveEventData', () {
    test('strips Authorization and cookie headers from the request', () {
      final event = SentryEvent(
        request: SentryRequest(
          url: 'https://api.hssan.example/api/orders',
          headers: {
            'Authorization': 'Bearer secret-token',
            'Cookie': 'BEARER=secret-token',
            'Accept': 'application/json',
          },
        ),
      );

      final scrubbed = scrubSensitiveEventData(event, Hint());

      expect(scrubbed, isNotNull);
      final headers = scrubbed!.request!.headers;
      expect(headers.containsKey('Authorization'), isFalse);
      expect(headers.containsKey('Cookie'), isFalse);
      expect(headers['Accept'], 'application/json');
    });

    test('is a no-op when the event has no request', () {
      final event = SentryEvent();

      final scrubbed = scrubSensitiveEventData(event, Hint());

      expect(scrubbed, same(event));
    });
  });

  group('scrubSensitiveBreadcrumbData', () {
    test('strips a sensitive key from breadcrumb data', () {
      final breadcrumb = Breadcrumb(
        type: 'http',
        data: {
          'url': 'https://api.hssan.example/api/orders',
          'authorization': 'Bearer secret-token',
        },
      );

      final scrubbed = scrubSensitiveBreadcrumbData(breadcrumb, Hint());

      expect(scrubbed, isNotNull);
      expect(scrubbed!.data!.containsKey('authorization'), isFalse);
      expect(scrubbed.data!['url'], 'https://api.hssan.example/api/orders');
    });

    test('tolerates a breadcrumb with no data', () {
      final breadcrumb = Breadcrumb(message: 'tapped button');

      final scrubbed = scrubSensitiveBreadcrumbData(breadcrumb, Hint());

      expect(scrubbed, same(breadcrumb));
    });
  });
}
