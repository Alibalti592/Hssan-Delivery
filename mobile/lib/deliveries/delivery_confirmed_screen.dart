import 'package:flutter/material.dart';

import '../theme.dart';
import 'available_deliveries_screen.dart';
import 'delivery.dart';

class DeliveryConfirmedScreen extends StatelessWidget {
  const DeliveryConfirmedScreen({required this.delivery, super.key});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final order = delivery.order;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: successText, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Livraison confirmée',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Course #${delivery.id} livrée avec succès.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (order != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Montant encaissé',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.totalAmount} DT',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const AvailableDeliveriesScreen(),
                    ),
                    (route) => route.isFirst,
                  );
                },
                child: const Text('Course suivante'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
