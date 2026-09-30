import 'package:flutter/material.dart';
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

  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined, size: 36),
      title: const Text('Ne ratez aucune course'),
      content: const Text(
        'Activez les notifications pour être prévenu dès qu\'une course '
        'vous est confiée, même quand l\'application est fermée.',
        textAlign: TextAlign.center,
      ),
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
  if (accepted == true) await push.requestPermission();
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
