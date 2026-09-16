import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_models.dart';
import '../addresses/address_repository.dart';
import '../core/api_exception.dart';
import '../theme.dart';
import '../widgets/dark_header.dart';
import 'add_address_screen.dart';

/// Saved-address list. Can be used either as a picker (returns the chosen
/// [SavedAddress] via [Navigator.pop] when [pickMode] is true, for checkout)
/// or as a plain management screen reached from the profile menu.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({this.pickMode = false, super.key});

  final bool pickMode;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late Future<List<SavedAddress>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SavedAddress>> _load() {
    return context.read<AddressRepository>().list();
  }

  // Not `setState(() => _future = _load())`: that arrow body is an
  // assignment *expression*, which evaluates to the assigned Future — so
  // the callback itself returns a Future, which setState's own assertion
  // rejects at runtime (it exists to catch exactly this "did you mean to
  // await first" mistake). Starting the load outside the callback and only
  // assigning the already-created Future inside a block body keeps the
  // callback's return value void.
  void _refresh() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  Future<void> _addAddress() async {
    final created = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    if (created == null) return;
    if (!mounted) return;
    if (widget.pickMode) {
      Navigator.of(context).pop(created);
    } else {
      _refresh();
    }
  }

  Future<void> _editAddress(SavedAddress address) async {
    final updated = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => AddAddressScreen(existing: address)),
    );
    if (updated == null || !mounted) return;
    _refresh();
  }

  Future<void> _deleteAddress(SavedAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette adresse ?'),
        content: Text('« ${address.label} » sera définitivement supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AddressRepository>().delete(address.id);
      if (!mounted) return;
      _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on NetworkException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
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
              title: 'Mes adresses',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: FutureBuilder<List<SavedAddress>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Impossible de charger vos adresses.'),
                    );
                  }

                  final addresses = snapshot.data ?? const [];

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final address in addresses)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: widget.pickMode
                                ? () => Navigator.of(context).pop(address)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          address.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      if (address.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: successBg,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Par défaut',
                                            style: TextStyle(
                                              color: successText,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      if (!widget.pickMode) ...[
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              _editAddress(address),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              _deleteAddress(address),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    address.instructions == null ||
                                            address.instructions!.isEmpty
                                        ? address.addressLine
                                        : '${address.addressLine} · '
                                              '${address.instructions}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (addresses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('Aucune adresse enregistrée.'),
                          ),
                        ),
                      const SizedBox(height: 4),
                      OutlinedButton(
                        onPressed: _addAddress,
                        child: const Text('+ AJOUTER UNE ADRESSE'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
