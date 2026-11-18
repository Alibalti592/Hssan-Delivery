import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import 'push_notification_service.dart';

/// The app's push service, or null where none is provided (widget tests).
PushNotificationService? pushServiceOf(BuildContext context) {
  try {
    return context.read<PushNotificationService>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Courier: right after signing in, explains why notifications matter
/// before the system prompt, which can only be shown once.
Future<void> askCourierForNotifications(BuildContext context) async {
  final push = pushServiceOf(context);
  if (push == null || !await push.needsPermission() || !context.mounted) {
    return;
  }

  final accepted = await _explain(
    context,
    title: 'Ne ratez aucune course',
    body:
        'Activez les notifications pour être prévenu dès qu\'une course '
        'vous est confiée, même quand l\'application est fermée.',
  );
  if (accepted == true) await push.requestPermission();
}

const _clientAskedKey = 'client_notifications_asked';

/// Client: once, on the home screen. Codes promo only reach customers by
/// notification, and Android 13+ shows none while the app is closed until
/// they're allowed. "Plus tard" isn't asked again here (the order screen
/// still offers it, see OrderNotificationsCard).
Future<void> askClientForNotifications(
  BuildContext context, {
  FlutterSecureStorage storage = const FlutterSecureStorage(),
}) async {
  final push = pushServiceOf(context);
  if (push == null || !await push.needsPermission()) return;
  try {
    if (await storage.read(key: _clientAskedKey) == 'true') return;
  } catch (_) {
    // Unreadable storage: asking once more is harmless.
  }
  if (!context.mounted) return;

  final accepted = await _explain(
    context,
    title: 'Ne ratez aucune offre',
    body:
        'Activez les notifications pour recevoir les codes promo et suivre '
        'vos commandes, même quand l\'application est fermée.',
  );
  try {
    await storage.write(key: _clientAskedKey, value: 'true');
  } catch (_) {}
  if (accepted == true) await push.requestPermission();
}

/// Why notifications matter, before the system prompt, which can only be
/// shown once or twice. True when the user chose "Activer".
Future<bool?> _explain(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined, size: 36),
      title: Text(title),
      content: Text(body, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Activer'),
        ),
      ],
    ),
  );
}

/// Client: offered once they've placed an order, when being told it's on
/// its way is plainly useful. Hidden when there's nothing to ask.
class OrderNotificationsCard extends StatefulWidget {
  const OrderNotificationsCard({super.key});

  @override
  State<OrderNotificationsCard> createState() => _OrderNotificationsCardState();
}

class _OrderNotificationsCardState extends State<OrderNotificationsCard> {
  late final PushNotificationService? _push = pushServiceOf(context);
  late final Future<bool> _needed =
      _push?.needsPermission() ?? Future.value(false);
  bool _done = false;

  Future<void> _enable() async {
    await _push?.requestPermission();
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _needed,
      builder: (context, snapshot) {
        if (snapshot.data != true || _done) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: navy),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Soyez prévenu quand votre commande arrive',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _enable,
                child: const Text('Activer'),
              ),
            ],
          ),
        );
      },
    );
  }
}
