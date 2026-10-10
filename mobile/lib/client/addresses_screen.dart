import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_models.dart';
import '../addresses/address_picker.dart';
import '../addresses/address_repository.dart';
import '../addresses/selected_address.dart';
import '../core/api_exception.dart';
import '../widgets/dark_header.dart';
import 'add_address_screen.dart';

/// The client's saved addresses, from the profile menu or the address
/// sheet's "Gérer": add one on the map, edit or delete one.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

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

  // Not `setState(() => _future = _load())`: that arrow body returns the
  // Future, which setState's assertion rejects. Start the load outside and
  // only assign inside a block body.
  void _refresh() {
    final future = _load();
    setState(() {
      _future = future;
    });
    // "LIVRER À" follows edits and deletions too.
    context.read<SelectedAddressController>().load().ignore();
  }

  Future<void> _addAddress() async {
    final created = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    if (created == null || !mounted) return;
    _refresh();
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
      await context.read<AddressRepository>().delete(address.id!);
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
        // DarkHeader pads itself for the status bar.
        top: false,
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AddressTile(
                            address: address,
                            onTap: () => _editAddress(address),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Modifier',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _editAddress(address),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _deleteAddress(address),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (addresses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40, bottom: 20),
                          child: Center(
                            child: Text('Aucune adresse enregistrée.'),
                          ),
                        ),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _addAddress,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('AJOUTER UNE ADRESSE'),
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
