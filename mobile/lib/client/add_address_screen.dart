import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_models.dart';
import '../addresses/address_repository.dart';
import '../core/api_exception.dart';
import '../widgets/dark_header.dart';
import '../widgets/decorative_map.dart';

/// Also doubles as the edit screen: pass [existing] to pre-fill the form
/// and update that address instead of creating a new one.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({this.existing, super.key});

  final SavedAddress? existing;

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label);
  late final _addressLine = TextEditingController(
    text: widget.existing?.addressLine,
  );
  late final _instructions = TextEditingController(
    text: widget.existing?.instructions,
  );
  late bool _isDefault = widget.existing?.isDefault ?? false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _label.dispose();
    _addressLine.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final repository = context.read<AddressRepository>();
      final address = _isEditing
          ? await repository.update(
              widget.existing!.id,
              label: _label.text.trim(),
              addressLine: _addressLine.text.trim(),
              instructions: _instructions.text.trim(),
              isDefault: _isDefault,
            )
          : await repository.create(
              label: _label.text.trim(),
              addressLine: _addressLine.text.trim(),
              instructions: _instructions.text.trim(),
              isDefault: _isDefault,
            );
      if (!mounted) return;
      Navigator.of(context).pop(address);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: _isEditing ? 'Modifier l\'adresse' : 'Ajouter une adresse',
              onBack: _saving ? null : () => Navigator.of(context).pop(),
            ),
            const DecorativeMap(height: 130, twoPins: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _label,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Libellé',
                          hintText: 'Domicile, Bureau…',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Libellé requis'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressLine,
                        enabled: !_saving,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Adresse'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Adresse requise'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _instructions,
                        enabled: !_saving,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Indications (optionnel)',
                          hintText: '3ème étage, porte bleue…',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isDefault,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _isDefault = v),
                        title: const Text('Adresse par défaut'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isEditing ? 'MODIFIER' : 'ENREGISTRER'),
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
