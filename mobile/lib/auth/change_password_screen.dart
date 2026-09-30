import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../widgets/dark_header.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

/// Self-service password change, reached from either the client profile
/// screen or the courier dashboard menu. Requires the current password —
/// there's no email/SMS channel in this app to recover a forgotten one; a
/// locked-out courier has their password reset by an admin instead.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _saving = false;
  String? _error;

  /// Once a submit has shown errors, they clear as each field is fixed.
  bool _submitted = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final message = await context.read<AuthController>().changePassword(
      currentPassword: _currentPassword.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;

    if (message == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour.')));
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: 'Changer le mot de passe',
              onBack: _saving ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Choisissez un nouveau mot de passe que vous '
                        "n'utilisez pas ailleurs.",
                        style: TextStyle(color: mutedText),
                      ),
                      const SizedBox(height: 20),
                      PasswordField(
                        controller: _currentPassword,
                        label: 'Mot de passe actuel',
                        enabled: !_saving,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _newPassword,
                        label: 'Nouveau mot de passe',
                        enabled: !_saving,
                        showRule: true,
                        isNew: true,
                        onSubmitted: _submit,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        AuthErrorBanner(_error!),
                      ],
                      const SizedBox(height: 24),
                      AuthSubmitButton(
                        label: 'ENREGISTRER',
                        busy: _saving,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
