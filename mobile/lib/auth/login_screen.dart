import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding/splash_screen.dart' show SplashMonogram;
import '../theme.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  /// Once a submit has shown errors, they clear as each field is fixed.
  bool _submitted = false;

  @override
  void dispose() {
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

    final message = await context.read<AuthController>().signIn(
      phoneDigits(_phone.text),
      _password.text,
    );
    if (mounted && message != null) {
      setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthController>().busy;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: navy,
      body: GestureDetector(
        // Tapping outside a field puts the keyboard away.
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _BrandHeader()),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _submitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Connexion',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Heureux de vous revoir !',
                            style: textTheme.bodyMedium?.copyWith(
                              color: mutedText,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PhoneField(controller: _phone, enabled: !busy),
                          const SizedBox(height: 16),
                          PasswordField(
                            controller: _password,
                            enabled: !busy,
                            onSubmitted: _submit,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            AuthErrorBanner(_error!),
                          ],
                          const SizedBox(height: 24),
                          AuthSubmitButton(
                            label: 'Se connecter',
                            busy: busy,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 24),
                          const _OrDivider(),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                            child: const Text('Créer un compte'),
                          ),
                          const Spacer(),
                          const SizedBox(height: 24),
                          const _CourierNote(),
                        ],
                      ),
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

/// The monogram, name and tagline, as on the splash screen.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 36, 24, 32),
      child: Column(
        children: [
          SplashMonogram(),
          SizedBox(height: 14),
          Text(
            'Delivery Hassen',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Aussi rapide que votre pensée',
            style: TextStyle(color: Color(0xFF9AA5B6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: cardBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Nouveau sur Delivery Hassen ?',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: mutedText),
          ),
        ),
        const Expanded(child: Divider(color: cardBorder)),
      ],
    );
  }
}

class _CourierNote extends StatelessWidget {
  const _CourierNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.delivery_dining_outlined, size: 18, color: mutedText),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            "Livreur ? Votre compte est créé par l'administrateur.",
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: mutedText),
          ),
        ),
      ],
    );
  }
}
