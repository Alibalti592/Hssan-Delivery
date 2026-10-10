import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../widgets/dark_header.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

/// "Supprimer mon compte": says plainly what goes and what stays, asks for
/// the password, and confirms once more before anything is deleted.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: const Text(
          'Votre compte sera supprimé tout de suite. Cette action ne peut '
          'pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: dangerText),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final error = await context.read<AuthController>().deleteAccount(
      _password.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _deleting = false;
        _error = error;
      });
      return;
    }
    // Signed out: back to the login screen, which is now the root.
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      const SnackBar(content: Text('Votre compte a été supprimé.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          // DarkHeader pads itself for the status bar.
          top: false,
          bottom: false,
          child: Column(
            children: [
              DarkHeader(
                title: 'Supprimer mon compte',
                onBack: () => Navigator.of(context).pop(),
                backEnabled: !_deleting,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ce qui sera supprimé',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _Line(
                          Icons.person_off_outlined,
                          'Votre nom et votre numéro de téléphone',
                        ),
                        const _Line(
                          Icons.place_outlined,
                          'Vos adresses enregistrées',
                        ),
                        const _Line(
                          Icons.phonelink_erase_outlined,
                          'Votre connexion sur tous vos appareils',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ce qui est conservé',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _Line(
                          Icons.receipt_long_outlined,
                          'Vos commandes passées, sans votre nom, pour notre '
                          'comptabilité',
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: warnBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Si une commande est en cours, attendez qu\'elle '
                            'soit livrée. Vous pourrez ensuite recréer un '
                            'compte avec le même numéro.',
                            style: TextStyle(color: warnText),
                          ),
                        ),
                        const SizedBox(height: 24),
                        PasswordField(
                          controller: _password,
                          label: 'Votre mot de passe',
                          enabled: !_deleting,
                          onSubmitted: _delete,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          AuthErrorBanner(_error!),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: dangerText,
                          ),
                          onPressed: _deleting ? null : _delete,
                          child: _deleting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('SUPPRIMER MON COMPTE'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: mutedText),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
