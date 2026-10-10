import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../client/add_address_screen.dart';
import '../client/addresses_screen.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import 'address_models.dart';
import 'address_repository.dart';

/// The client's saved addresses in a bottom sheet — tap one to use it, or
/// add a new one on the map. Resolves to the chosen address (null when
/// dismissed). [allowOneOff] lets a new address be used without saving it.
Future<SavedAddress?> showAddressSheet(
  BuildContext context, {
  SavedAddress? selected,
  String title = 'Choisir une adresse',
  bool allowOneOff = false,
}) {
  return showModalBottomSheet<SavedAddress>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _AddressSheet(
      selected: selected,
      title: title,
      allowOneOff: allowOneOff,
    ),
  );
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({
    required this.selected,
    required this.title,
    required this.allowOneOff,
  });

  final SavedAddress? selected;
  final String title;
  final bool allowOneOff;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late Future<List<SavedAddress>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AddressRepository>().list();
  }

  Future<void> _addNew() async {
    final navigator = Navigator.of(context);
    final created = await navigator.push<SavedAddress>(
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(allowOneOff: widget.allowOneOff),
      ),
    );
    if (created != null && mounted) navigator.pop(created);
  }

  Future<void> _manage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddressesScreen()));
    if (!mounted) return;
    final future = context.read<AddressRepository>().list();
    setState(() => _future = future);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: _manage, child: const Text('Gérer')),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<SavedAddress>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final addresses = snapshot.data ?? const [];
                  if (addresses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        snapshot.hasError
                            ? 'Impossible de charger vos adresses.'
                            : 'Aucune adresse enregistrée pour le moment.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(color: mutedText),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return AddressTile(
                        address: address,
                        selected:
                            widget.selected?.isSaved == true &&
                            widget.selected!.id == address.id,
                        onTap: () => Navigator.of(context).pop(address),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addNew,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Nouvelle adresse'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One address as a card: label icon, label, address, zone and fee.
class AddressTile extends StatelessWidget {
  const AddressTile({
    required this.address,
    this.selected = false,
    this.onTap,
    this.trailing,
    super.key,
  });

  final SavedAddress address;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = accentOf(context);
    final fill = fieldFillOf(context);
    final zone = address.zone;

    return Material(
      color: selected ? fill : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : cardBorderOf(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? accent : fill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  addressLabelIcon(address.label),
                  color: selected ? scheme.onPrimary : accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            address.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 6),
                          const _Pill('Par défaut'),
                        ],
                        if (address.hasLocation) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: successText,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.fullText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zone == null
                          ? 'Zone selon la position sur la carte'
                          : zoneSummary(zone),
                      style: textTheme.bodySmall?.copyWith(
                        color: zone == null ? warnText : mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: successBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: successText,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// An address plus the zone that prices it — what an order form needs.
/// Without a zone, [zoneProblem] says why.
class AddressSelection {
  const AddressSelection(this.address, this.zone, {this.zoneProblem});

  final SavedAddress address;
  final DeliveryZoneOption? zone;
  final String? zoneProblem;
}

/// Why an address has no zone: no pin to place it by, or outside them all.
const _needsPin = 'Placez cette adresse sur la carte';
const _outside = 'Nous ne livrons pas encore à cette adresse.';
const _locating = 'Recherche de la zone de livraison…';

/// The address block of an order form: the chosen address as a card (tap
/// to switch or add one) with the zone that prices it. The zone comes from
/// the address's pin — the zones the admin placed on the map — never from
/// the client. Validates like any form field.
class AddressField extends FormField<AddressSelection> {
  AddressField({
    required String label,
    required ValueChanged<AddressSelection?> onChanged,
    SavedAddress? initialAddress,
    bool needsZone = true,
    bool allowOneOff = false,
    String emptyText = 'Choisir une adresse',
    super.enabled,
    super.key,
  }) : super(
         initialValue: initialAddress == null
             ? null
             : _selectionOf(initialAddress, needsZone),
         validator: (value) {
           if (value == null) return 'Choisissez une adresse';
           if (needsZone && value.zone == null) {
             return value.zoneProblem ?? _needsPin;
           }
           return null;
         },
         builder: (state) => _AddressFieldBody(
           state: state,
           label: label,
           needsZone: needsZone,
           allowOneOff: allowOneOff,
           emptyText: emptyText,
           onChanged: onChanged,
         ),
       );
}

/// An address as just picked: with a pin, its zone is looked up again (it
/// follows the map as it stands today); without one, its saved zone counts.
AddressSelection _selectionOf(SavedAddress address, bool needsZone) {
  if (needsZone && address.hasLocation) {
    return AddressSelection(address, null, zoneProblem: _locating);
  }
  return AddressSelection(
    address,
    address.zone,
    zoneProblem: address.zone == null ? _needsPin : null,
  );
}

class _AddressFieldBody extends StatefulWidget {
  const _AddressFieldBody({
    required this.state,
    required this.label,
    required this.needsZone,
    required this.allowOneOff,
    required this.emptyText,
    required this.onChanged,
  });

  final FormFieldState<AddressSelection> state;
  final String label;
  final bool needsZone;
  final bool allowOneOff;
  final String emptyText;
  final ValueChanged<AddressSelection?> onChanged;

  @override
  State<_AddressFieldBody> createState() => _AddressFieldBodyState();
}

class _AddressFieldBodyState extends State<_AddressFieldBody> {
  AddressSelection? get _value => widget.state.value;

  @override
  void initState() {
    super.initState();
    // Report the pre-filled address so the form knows it from the start.
    final initial = _value;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged(initial);
        _locateZone(initial.address);
      });
    }
  }

  /// The zone covering the address's pin. If the lookup fails (no
  /// network), the zone saved with the address stands in.
  Future<void> _locateZone(SavedAddress address) async {
    if (!widget.needsZone || !address.hasLocation) return;
    AddressSelection located;
    try {
      final zone = await context.read<OrdersRepository>().locateZone(
        address.latitude!,
        address.longitude!,
      );
      located = AddressSelection(
        address,
        zone,
        zoneProblem: zone == null ? _outside : null,
      );
    } on Exception {
      located = AddressSelection(
        address,
        address.zone,
        zoneProblem: address.zone == null
            ? 'Impossible de trouver la zone. Vérifiez votre connexion.'
            : null,
      );
    }
    // Still that address?
    if (!mounted || _value?.address != address) return;
    _set(located);
    // Clear or show the error now that the zone is known.
    if (widget.state.hasError || located.zone == null) widget.state.validate();
  }

  void _set(AddressSelection? value) {
    widget.state.didChange(value);
    widget.onChanged(value);
  }

  Future<void> _pick() async {
    final picked = await showAddressSheet(
      context,
      selected: _value?.address,
      title: widget.label,
      allowOneOff: widget.allowOneOff,
    );
    if (picked == null) return;
    _set(_selectionOf(picked, widget.needsZone));
    _locateZone(picked);
  }

  /// A saved address without a pin: place it on the map, then use it.
  Future<void> _placeOnMap(SavedAddress address) async {
    final placed = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => AddAddressScreen(existing: address)),
    );
    if (placed == null || !mounted) return;
    _set(_selectionOf(placed, widget.needsZone));
    _locateZone(placed);
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final textTheme = Theme.of(context).textTheme;
    final enabled = widget.state.widget.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (value == null)
          _EmptyAddressCard(
            text: widget.emptyText,
            onTap: enabled ? _pick : null,
            hasError: widget.state.hasError,
          )
        else
          AddressTile(
            // The zone shown is the one that prices this order.
            address: SavedAddress(
              id: value.address.id,
              label: value.address.label,
              addressLine: value.address.addressLine,
              instructions: value.address.instructions,
              isDefault: value.address.isDefault,
              zone: widget.needsZone ? value.zone : value.address.zone,
              latitude: value.address.latitude,
              longitude: value.address.longitude,
            ),
            onTap: enabled ? _pick : null,
            trailing: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Changer',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accentOf(context),
                ),
              ),
            ),
          ),
        if (widget.needsZone && value != null && value.zoneProblem == _locating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (widget.needsZone &&
            value != null &&
            value.zone == null &&
            !value.address.hasLocation &&
            value.address.isSaved)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: enabled ? () => _placeOnMap(value.address) : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Placer sur la carte'),
            ),
          ),
        if (widget.state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.state.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyAddressCard extends StatelessWidget {
  const _EmptyAddressCard({
    required this.text,
    required this.onTap,
    required this.hasError,
  });

  final String text;
  final VoidCallback? onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fieldFillOf(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: hasError
                ? Border.all(color: Theme.of(context).colorScheme.error)
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.add_location_alt_outlined, color: accentOf(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right, color: mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
