import 'package:sentry_flutter/sentry_flutter.dart';

/// Header names stripped from anything Sentry is about to send. Nothing in
/// this app currently wraps outgoing HTTP calls with Sentry's own client
/// (ApiClient uses a plain http.Client — see core/api_client.dart), so no
/// event or breadcrumb should carry an Authorization header or session
/// cookie today. This exists as a defensive floor for the day someone wires
/// up automatic HTTP instrumentation (an easy thing to reach for without
/// realizing it'd also capture the bearer token) rather than relying on
/// nobody ever adding that.
const _sensitiveKeys = {'authorization', 'cookie', 'set-cookie'};

/// Wired up as [SentryFlutterOptions.beforeSend] — see main.dart.
SentryEvent? scrubSensitiveEventData(SentryEvent event, Hint hint) {
  final request = event.request;

  if (request != null) {
    final headers = Map<String, String>.of(request.headers)
      ..removeWhere((key, _) => _sensitiveKeys.contains(key.toLowerCase()));
    request.headers = headers;
  }

  return event;
}

/// Wired up as [SentryFlutterOptions.beforeBreadcrumb] — see main.dart.
Breadcrumb? scrubSensitiveBreadcrumbData(Breadcrumb? breadcrumb, Hint hint) {
  breadcrumb?.data?.removeWhere(
    (key, _) => _sensitiveKeys.contains(key.toLowerCase()),
  );

  return breadcrumb;
}
