import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_models.dart';
import '../addresses/address_repository.dart';
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

  Future<void> _addAddress() async {
    final created = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    if (created == null) return;
    if (!mounted) return;
    if (widget.pickMode) {
      Navigator.of(context).pop(created);
    } else {
      setState(() => _future = _load());
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
