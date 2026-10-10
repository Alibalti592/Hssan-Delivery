import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_picker.dart';
import '../addresses/selected_address.dart';
import '../core/api_exception.dart';
import '../core/phone_format.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../widgets/dark_header.dart';
import 'order_confirmed_screen.dart';

/// A Colis (parcel) request: where it is collected (one of the sender's
/// addresses), who receives it and where, typed in since it is someone
/// else's address, and the delivery zone that prices it — no restaurant,
/// no cart, since a parcel doesn't come from a catalogue.
class ParcelFormScreen extends StatefulWidget {
  const ParcelFormScreen({super.key});

  @override
  State<ParcelFormScreen> createState() => _ParcelFormScreenState();
}

class _ParcelFormScreenState extends State<ParcelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  AddressSelection? _pickup;
  DeliveryZoneOption? _zone;
  late final Future<List<DeliveryZoneOption>> _zones = context
      .read<OrdersRepository>()
      .listDeliveryZones();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _recipientAddress = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _recipientName.dispose();
    _recipientPhone.dispose();
    _recipientAddress.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final pickup = _pickup!.address;

    setState(() => _submitting = true);
    try {
      final order = await context.read<OrdersRepository>().createParcelOrder(
        pickupAddress: pickup.fullText,
        pickupLatitude: pickup.latitude,
        pickupLongitude: pickup.longitude,
        deliveryAddress: _recipientAddress.text.trim(),
        recipientName: _recipientName.text.trim(),
        recipientPhone: _recipientPhone.text.trim(),
        deliveryZoneId: _zone!.id,
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
        // DarkHeader pads itself for the status bar.
        top: false,
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: 'Colis',
              subtitle: 'Envoyer un colis',
              onBack: () => Navigator.of(context).pop(),
              backEnabled: !_submitting,
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
                      Text(
                        'Livrer le colis à',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _recipientName,
                        enabled: !_submitting,
                        textCapitalization: TextCapitalization.words,
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
                        controller: _recipientAddress,
                        enabled: !_submitting,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Adresse du destinataire',
                          hintText: 'Rue, numéro, quartier, repère…',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Adresse requise'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // The zone prices the delivery.
                      FutureBuilder<List<DeliveryZoneOption>>(
                        future: _zones,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          final zones = snapshot.data ?? const [];
                          return DropdownButtonFormField<DeliveryZoneOption>(
                            initialValue: _zone,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Zone de livraison',
                            ),
                            items: [
                              for (final z in zones)
                                DropdownMenuItem(
                                  value: z,
                                  child: Text('${z.name} — ${z.fee} DT'),
                                ),
                            ],
                            onChanged: _submitting
                                ? null
                                : (z) => setState(() => _zone = z),
                            validator: (z) => z == null
                                ? 'Choisissez la zone de livraison'
                                : null,
                          );
                        },
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
