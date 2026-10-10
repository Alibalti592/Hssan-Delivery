import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../addresses/address_models.dart';
import '../addresses/address_repository.dart';
import '../addresses/pin_map.dart';
import '../addresses/reverse_geocoder.dart';
import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import '../widgets/dark_header.dart';

/// Adds or edits an address: a pin on the map (what the courier navigates
/// to), a label chip, the written address — filled in from where the pin
/// is placed — the zone that prices it and door-step hints. Pops the
/// resulting [SavedAddress].
///
/// With [allowOneOff] (picking an address for an order), the client can
/// switch off "Enregistrer dans mes adresses" to use it just this once —
/// the popped address then has no id.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({this.existing, this.allowOneOff = false, super.key});

  final SavedAddress? existing;
  final bool allowOneOff;

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AddressLabel _initialLabel = widget.existing == null
      ? AddressLabel.home
      : AddressLabel.of(widget.existing!.label);
  late AddressLabel _labelChoice = _initialLabel;
  late final _customLabel = TextEditingController(
    text: _initialLabel == AddressLabel.other ? widget.existing?.label : null,
  );
  late final _addressLine = TextEditingController(
    text: widget.existing?.addressLine,
  );
  late final _instructions = TextEditingController(
    text: widget.existing?.instructions,
  );
  late bool _isDefault = widget.existing?.isDefault ?? false;
  late DeliveryZoneOption? _zone = widget.existing?.zone;
  late LatLng? _pin = widget.existing?.hasLocation == true
      ? LatLng(widget.existing!.latitude!, widget.existing!.longitude!)
      : null;
  bool _saveForLater = true;
  late Future<List<DeliveryZoneOption>> _zonesFuture;
  bool _saving = false;
  String? _error;

  /// Filling the address in from the pin: waits for the pin to rest, and
  /// only the latest lookup counts.
  Timer? _lookupDelay;
  int _lookup = 0;
  bool _lookingUp = false;

  /// What the last lookup wrote, so a new pin replaces it — but never
  /// replaces what the client typed themselves.
  String? _filledIn;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _zonesFuture = context.read<OrdersRepository>().listDeliveryZones();
  }

  @override
  void dispose() {
    _lookupDelay?.cancel();
    _customLabel.dispose();
    _addressLine.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _pinSettled(LatLng point) {
    _lookupDelay?.cancel();
    _lookupDelay = Timer(
      const Duration(milliseconds: 500),
      () => _fillAddressAt(point),
    );
  }

  Future<void> _fillAddressAt(LatLng point) async {
    final typed = _addressLine.text.trim();
    if (typed.isNotEmpty && typed != _filledIn) return;
    final lookup = ++_lookup;
    setState(() => _lookingUp = true);
    final address = await ReverseGeocoder.instance.addressAt(point);
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _lookingUp = false;
      // Typed while the lookup ran: theirs wins.
      final now = _addressLine.text.trim();
      if (address != null && (now.isEmpty || now == _filledIn)) {
        _addressLine.text = address;
        _filledIn = address;
      }
    });
  }

  String get _label => _labelChoice == AddressLabel.other
      ? _customLabel.text.trim()
      : _labelChoice.text;

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    if (!_saveForLater) {
      Navigator.of(context).pop(
        SavedAddress(
          id: null,
          label: _label,
          addressLine: _addressLine.text.trim(),
          instructions: _instructions.text.trim(),
          isDefault: false,
          zone: _zone,
          latitude: _pin?.latitude,
          longitude: _pin?.longitude,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = context.read<AddressRepository>();
      final address = _isEditing
          ? await repository.update(
              widget.existing!.id!,
              label: _label,
              addressLine: _addressLine.text.trim(),
              instructions: _instructions.text.trim(),
              isDefault: _isDefault,
              deliveryZoneId: _zone?.id,
              latitude: _pin?.latitude,
              longitude: _pin?.longitude,
            )
          : await repository.create(
              label: _label,
              addressLine: _addressLine.text.trim(),
              instructions: _instructions.text.trim(),
              isDefault: _isDefault,
              deliveryZoneId: _zone?.id,
              latitude: _pin?.latitude,
              longitude: _pin?.longitude,
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        // DarkHeader pads itself for the status bar.
        top: false,
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: _isEditing ? 'Modifier l\'adresse' : 'Nouvelle adresse',
              onBack: _saving ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  PinMap(
                    initial: _pin ?? defaultMapCenter,
                    locateOnStart: _pin == null,
                    // No setState: the pin is only read on save, and
                    // rebuilding the form on every map frame is wasted work.
                    onMoved: (point) => _pin = point,
                    onSettled: _saving ? null : _pinSettled,
                  ),
                  Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Type d\'adresse',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final choice in AddressLabel.values)
                                ChoiceChip(
                                  // The icon is the cue; a checkmark would
                                  // be drawn over it.
                                  showCheckmark: false,
                                  avatar: Icon(
                                    addressLabelIcon(choice.text),
                                    size: 18,
                                    color: _labelChoice == choice
                                        ? Colors.white
                                        : navy,
                                  ),
                                  label: Text(choice.text),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _labelChoice == choice
                                        ? Colors.white
                                        : navy,
                                  ),
                                  selectedColor: navy,
                                  selected: _labelChoice == choice,
                                  onSelected: _saving
                                      ? null
                                      : (_) => setState(
                                          () => _labelChoice = choice,
                                        ),
                                ),
                            ],
                          ),
                          if (_labelChoice == AddressLabel.other) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _customLabel,
                              enabled: !_saving,
                              decoration: const InputDecoration(
                                labelText: 'Nom de l\'adresse',
                                hintText: 'Chez maman, Salle de sport…',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nom requis'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressLine,
                            enabled: !_saving,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Adresse',
                              hintText: 'Rue, numéro, quartier',
                              helperText: _lookingUp
                                  ? "Recherche de l'adresse…"
                                  : null,
                              suffixIcon: _lookingUp
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Adresse requise'
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
                              final zones = snapshot.data ?? const [];
                              return DropdownButtonFormField<
                                DeliveryZoneOption
                              >(
                                initialValue: zones.contains(_zone)
                                    ? _zone
                                    : null,
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
                                validator: (v) =>
                                    v == null ? 'Choisissez la zone' : null,
                                onChanged: _saving
                                    ? null
                                    : (z) => setState(() => _zone = z),
                              );
                            },
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
                          if (widget.allowOneOff && !_isEditing)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _saveForLater,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _saveForLater = v),
                              title: const Text(
                                'Enregistrer dans mes adresses',
                              ),
                            ),
                          if (_saveForLater)
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
                                : Text(
                                    _isEditing
                                        ? 'MODIFIER'
                                        : _saveForLater
                                        ? 'ENREGISTRER'
                                        : 'UTILISER CETTE ADRESSE',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maison / Travail / anything else, for address cards and chips.
IconData addressLabelIcon(String label) {
  switch (AddressLabel.of(label)) {
    case AddressLabel.home:
      return Icons.home_outlined;
    case AddressLabel.work:
      return Icons.work_outline;
    case AddressLabel.other:
      return Icons.place_outlined;
  }
}

/// A zone line for address cards: "Bizerte centre · 4.000 DT".
String zoneSummary(DeliveryZoneOption zone) => '${zone.name} · ${zone.fee} DT';
