import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Delivery Hassen support: WhatsApp and calls, on the number from the
/// flyers. It is also how a forgotten password is recovered: support sets a
/// new one from the admin and sends it back on WhatsApp.
class Support {
  Support._();

  static const phone = '98141009';
  static const display = '98 141 009';

  static Uri whatsApp(String message) =>
      Uri.https('wa.me', '/216$phone', {'text': message});

  static final Uri call = Uri(scheme: 'tel', path: '+216$phone');

  /// Opens a link in WhatsApp or the dialer; widget tests swap it out.
  static Future<bool> Function(Uri) open = (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  };
}

Future<void> _open(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  final opened = await Support.open(uri);
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          "Impossible d'ouvrir l'application. Contactez-nous au "
          '${Support.display}.',
        ),
      ),
    );
    return;
  }
  if (navigator.canPop()) navigator.pop();
}

/// "Aide / Contact": WhatsApp or a call to support.
Future<void> showSupportSheet(BuildContext context) {
  return _showSheet(
    context,
    title: "Besoin d'aide ?",
    text:
        'Une question sur une commande, un livreur ou votre compte ? '
        'Notre équipe vous répond sur WhatsApp.',
    message: 'Bonjour, j\'ai besoin d\'aide avec Delivery Hassen.',
  );
}

/// "Mot de passe oublié ?": support sends a new password on WhatsApp.
/// [phone] is what the client typed on the login screen, if anything.
Future<void> showForgotPasswordSheet(BuildContext context, {String? phone}) {
  final number = phone?.trim() ?? '';
  return _showSheet(
    context,
    title: 'Mot de passe oublié ?',
    text:
        'Écrivez-nous sur WhatsApp depuis le numéro de votre compte : '
        'nous vous enverrons un nouveau mot de passe. Vous pourrez le '
        'changer ensuite dans Profil.',
    message:
        "Bonjour, j'ai oublié mon mot de passe Delivery Hassen. "
        'Mon numéro : ${number.isEmpty ? '…' : number}',
  );
}

Future<void> _showSheet(
  BuildContext context, {
  required String title,
  required String text,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: textTheme.bodyMedium?.copyWith(color: mutedText),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1DA851),
                ),
                onPressed: () => _open(context, Support.whatsApp(message)),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('ÉCRIRE SUR WHATSAPP'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _open(context, Support.call),
                icon: const Icon(Icons.call_outlined),
                label: const Text('APPELER LE ${Support.display}'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
