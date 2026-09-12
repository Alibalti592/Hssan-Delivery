import 'package:flutter/material.dart';

import '../orders/order_models.dart';
import '../theme.dart';
import 'client_home_screen.dart';

class OrderConfirmedScreen extends StatelessWidget {
  const OrderConfirmedScreen({required this.order, super.key});

  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
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
                'Commande envoyée',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre commande #${order.id} a bien été transmise au restaurant.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
                        'Total à payer',
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
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text("Retour à l'accueil"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
