import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../theme.dart';
import '../widgets/dark_header.dart';
import 'bill_form_screen.dart';
import 'bill_models.dart';
import 'bill_widgets.dart';
import 'bills_repository.dart';

/// Entry point of the Factures service: pick whose bill to pay, or which
/// service to send a mandat with. A courier collects the cash (and the
/// bill) at home, pays at the counter and brings the receipt back.
class BillProvidersScreen extends StatefulWidget {
  const BillProvidersScreen({super.key});

  @override
  State<BillProvidersScreen> createState() => _BillProvidersScreenState();
}

class _BillProvidersScreenState extends State<BillProvidersScreen> {
  late Future<List<BillProvider>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<BillsRepository>().listProviders();
  }

  void _retry() {
    setState(() => _future = context.read<BillsRepository>().listProviders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: 'Factures',
              subtitle: 'Payer une facture ou envoyer un mandat',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: FutureBuilder<List<BillProvider>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return _ErrorState(
                      message: error is ApiException
                          ? error.message
                          : error is NetworkException
                          ? error.message
                          : 'Impossible de charger les services.',
                      onRetry: _retry,
                    );
                  }

                  final providers = snapshot.data ?? const [];
                  final bills = providers
                      .where((p) => !p.isTransfer)
                      .toList(growable: false);
                  final transfers = providers
                      .where((p) => p.isTransfer)
                      .toList(growable: false);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      const _HowItWorks(),
                      if (bills.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionTitle('Payer une facture'),
                        const SizedBox(height: 12),
                        _ProviderGrid(providers: bills),
                      ],
                      if (transfers.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const _SectionTitle('Envoyer un mandat'),
                        const SizedBox(height: 12),
                        _ProviderGrid(providers: transfers),
                      ],
                      if (providers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Text(
                            'Aucun service disponible pour le moment.',
                            textAlign: TextAlign.center,
                          ),
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

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.home_outlined, 'Un livreur passe chez vous'),
      (Icons.payments_outlined, 'Il paie au guichet'),
      (Icons.receipt_long_outlined, 'Il vous rapporte le reçu'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (icon, label) in steps)
            Expanded(
              child: Column(
                children: [
                  Icon(icon, color: navy),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ProviderGrid extends StatelessWidget {
  const _ProviderGrid({required this.providers});

  final List<BillProvider> providers;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: [
        for (final provider in providers)
          _ProviderTile(
            provider: provider,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BillFormScreen(provider: provider),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap});

  final BillProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BillProviderLogo(provider: provider),
              const SizedBox(height: 10),
              Text(
                provider.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
