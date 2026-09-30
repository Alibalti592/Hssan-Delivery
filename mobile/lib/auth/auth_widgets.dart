import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/phone_format.dart';
import '../theme.dart';

/// The 8 local digits of what was typed in a [PhoneField]: "22 123 456"
/// gives "22123456".
String phoneDigits(String text) => text.replaceAll(RegExp(r'\D'), '');

/// A Tunisian number: "+216" is fixed in front, only digits go in, grouped
/// as they're typed ("22 123 456"). A pasted "+216 22 123 456" keeps just
/// the local number.
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.controller,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [LocalPhoneFormatter()],
      decoration: const InputDecoration(
        labelText: 'Numéro de téléphone',
        hintText: '22 123 456',
        prefixIcon: Icon(Icons.phone_outlined),
        prefixText: '+216  ',
      ),
      validator: (v) => validatePhone(phoneDigits(v ?? '')),
    );
  }
}

/// Keeps the 8 local digits of a number and groups them "22 123 456".
class LocalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = phoneDigits(newValue.text);
    if (digits.length > 8 && digits.startsWith('216')) {
      digits = digits.substring(3);
    }
    if (digits.length > 8) digits = digits.substring(0, 8);

    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5) grouped.write(' ');
      grouped.write(digits[i]);
    }
    final text = grouped.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A password with a show/hide eye. With [showRule], the 8-character rule
/// sits under the field and ticks green once it's met.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    this.label = 'Mot de passe',
    this.enabled = true,
    this.showRule = false,
    this.isNew = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool showRule;

  /// A password being chosen (sign-up, change) rather than typed to sign in:
  /// lets the phone's password manager offer a strong one.
  final bool isNew;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  static const minLength = 8;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      textInputAction: widget.textInputAction,
      autofillHints: [
        widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
      ],
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Afficher' : 'Masquer',
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Mot de passe requis';
        if (widget.showRule && v.length < PasswordField.minLength) {
          return 'Au moins ${PasswordField.minLength} caractères';
        }
        return null;
      },
    );
    if (!widget.showRule) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final met = value.text.length >= PasswordField.minLength;
            final color = met ? successText : mutedText;
            return Row(
              children: [
                Icon(
                  met ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  '${PasswordField.minLength} caractères minimum',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: met ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A failed sign-in, sign-up or change, in a tinted box that's hard to miss.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dangerBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: dangerText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: dangerText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The submit button: a spinner while [busy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
