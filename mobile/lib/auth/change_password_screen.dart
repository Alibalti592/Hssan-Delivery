import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/dark_header.dart';
import 'auth_controller.dart';

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

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _currentPassword,
                        obscureText: true,
                        enabled: !_saving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe actuel',
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Mot de passe actuel requis'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPassword,
                        obscureText: true,
                        enabled: !_saving,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Nouveau mot de passe requis';
                          }
                          if (v.length < 8) {
                            return 'Au moins 8 caractères';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('ENREGISTRER'),
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
