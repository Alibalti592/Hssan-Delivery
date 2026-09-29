import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_picker.dart';
import '../addresses/selected_address.dart';
import '../core/api_exception.dart';
import '../core/phone_format.dart';
import '../orders/orders_repository.dart';
import '../widgets/dark_header.dart';
import 'order_confirmed_screen.dart';

/// A Colis (parcel) request: pickup + drop-off address, who receives it,
/// and which delivery zone prices it — no restaurant, no cart, since a
/// parcel doesn't come from a catalogue like the other services.
class ParcelFormScreen extends StatefulWidget {
  const ParcelFormScreen({super.key});

  @override
  State<ParcelFormScreen> createState() => _ParcelFormScreenState();
}

class _ParcelFormScreenState extends State<ParcelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  AddressSelection? _pickup;
  AddressSelection? _dropOff;
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _recipientName.dispose();
    _recipientPhone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final pickup = _pickup!.address;
    final dropOff = _dropOff!;

    setState(() => _submitting = true);
    try {
      final order = await context.read<OrdersRepository>().createParcelOrder(
        pickupAddress: pickup.fullText,
        pickupLatitude: pickup.latitude,
        pickupLongitude: pickup.longitude,
        deliveryAddress: dropOff.address.fullText,
        deliveryLatitude: dropOff.address.latitude,
        deliveryLongitude: dropOff.address.longitude,
        recipientName: _recipientName.text.trim(),
        recipientPhone: _recipientPhone.text.trim(),
        deliveryZoneId: dropOff.zone!.id,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderConfirmedScreen(order: order)),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
              title: 'Colis',
              subtitle: 'Envoyer un colis',
              onBack: _submitting ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AddressField(
                        label: 'Récupérer le colis à',
                        enabled: !_submitting,
                        needsZone: false,
                        allowOneOff: true,
                        initialAddress: context
                            .read<SelectedAddressController>()
                            .current,
                        onChanged: (v) => setState(() => _pickup = v),
                      ),
                      const SizedBox(height: 20),
                      AddressField(
                        label: 'Livrer le colis à',
                        enabled: !_submitting,
                        allowOneOff: true,
                        emptyText: "Choisir l'adresse de livraison",
                        onChanged: (v) => setState(() => _dropOff = v),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _recipientName,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: 'Nom du destinataire',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nom requis'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _recipientPhone,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone du destinataire',
                        ),
                        validator: validatePhone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _note,
                        enabled: !_submitting,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description du colis (optionnel)',
                        ),
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
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('ENVOYER LE COLIS'),
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
