import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_models.dart';
import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../widgets/dark_header.dart';
import 'addresses_screen.dart';
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
  final _pickupAddress = TextEditingController();
  final _deliveryAddress = TextEditingController();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _note = TextEditingController();
  late Future<List<DeliveryZoneOption>> _zonesFuture;
  DeliveryZoneOption? _selectedZone;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _zonesFuture = context.read<OrdersRepository>().listDeliveryZones();
  }

  @override
  void dispose() {
    _pickupAddress.dispose();
    _deliveryAddress.dispose();
    _recipientName.dispose();
    _recipientPhone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickSavedAddress(TextEditingController target) async {
    final picked = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddressesScreen(pickMode: true)),
    );
    if (picked != null) {
      setState(() => target.text = picked.addressLine);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedZone == null) {
      setState(() => _error = 'Choisissez une zone de livraison.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final order = await context.read<OrdersRepository>().createParcelOrder(
        pickupAddress: _pickupAddress.text.trim(),
        deliveryAddress: _deliveryAddress.text.trim(),
        recipientName: _recipientName.text.trim(),
        recipientPhone: _recipientPhone.text.trim(),
        deliveryZoneId: _selectedZone!.id,
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
                      TextFormField(
                        controller: _pickupAddress,
                        enabled: !_submitting,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Adresse de récupération',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Adresse requise'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _pickSavedAddress(_pickupAddress),
                          icon: const Icon(Icons.place_outlined, size: 16),
                          label: const Text('Choisir une adresse enregistrée'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _deliveryAddress,
                        enabled: !_submitting,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Adresse de livraison',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Adresse requise'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _pickSavedAddress(_deliveryAddress),
                          icon: const Icon(Icons.place_outlined, size: 16),
                          label: const Text('Choisir une adresse enregistrée'),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Téléphone requis'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<DeliveryZoneOption>>(
                        future: _zonesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Impossible de charger les zones de livraison.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                          final zones = snapshot.data ?? const [];
                          return DropdownButtonFormField<DeliveryZoneOption>(
                            initialValue: _selectedZone,
                            decoration: const InputDecoration(
                              labelText: 'Zone de livraison',
                            ),
                            items: zones
                                .map(
                                  (z) => DropdownMenuItem(
                                    value: z,
                                    child: Text('${z.name} — ${z.fee} DT'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _submitting
                                ? null
                                : (value) =>
                                      setState(() => _selectedZone = value),
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
