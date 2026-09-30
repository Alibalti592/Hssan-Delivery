import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../widgets/dark_header.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  /// Once a submit has shown errors, they clear as each field is fixed.
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final message = await context.read<AuthController>().register(
      name: _name.text.trim(),
      phone: phoneDigits(_phone.text),
      password: _password.text,
    );

    if (!mounted) return;

    if (message != null) {
      setState(() => _error = message);
      return;
    }

    // signIn() already ran inside register(); the app root will now switch
    // to the client home on its own once AuthController notifies.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthController>().busy;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              DarkHeader(
                title: 'Créer un compte',
                subtitle: 'Commandez en quelques secondes',
                onBack: busy ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(child: _form(context, busy)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, bool busy) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Nom et prénom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              PhoneField(controller: _phone, enabled: !busy),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Le livreur vous appellera sur ce numéro.',
                  style: TextStyle(color: mutedText, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                enabled: !busy,
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
                label: 'Créer mon compte',
                busy: busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Déjà un compte ?',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: mutedText),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
