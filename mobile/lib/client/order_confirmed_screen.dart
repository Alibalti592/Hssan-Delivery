import 'package:flutter/material.dart';

import '../notifications/notification_prompt.dart';
import '../orders/order_models.dart';
import '../theme.dart';
import 'client_home_screen.dart';
import 'order_detail_screen.dart';

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
                order.isBill
                    ? 'Demande envoyée'
                    : order.isParcel
                    ? 'Colis envoyé'
                    : 'Commande envoyée',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order.isBill
                    ? 'Votre demande #${order.id} a bien été envoyée. Un livreur va passer chez vous récupérer '
                          '${order.bill!.isTransfer ? "l'argent du mandat" : "la facture et l'argent"}.'
                    : order.isParcel
                    ? 'Votre demande de course #${order.id} a bien été envoyée. Un livreur va la récupérer.'
                    : 'Votre commande #${order.id} a bien été transmise au restaurant.',
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
                        order.isBill
                            ? 'À remettre au livreur'
                            : 'Total à payer',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.totalAmount} DT',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (order.hasDiscount) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Vous économisez ${order.discountAmount} DT',
                          style: const TextStyle(
                            color: successText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: successText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.isBill
                                ? 'En espèces, au livreur'
                                : 'En espèces à la livraison',
                            style: const TextStyle(
                              color: successText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const OrderNotificationsCard(),
              const SizedBox(height: 32),
              FilledButton.icon(
                // Home underneath, so "back" from the tracking page lands
                // there rather than on this confirmation.
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
                    (route) => false,
                  );
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(orderId: order.id),
                    ),
                  );
                },
                icon: const Icon(Icons.near_me_outlined),
                label: Text(
                  order.isBill || order.isParcel
                      ? 'Suivre ma demande'
                      : 'Suivre ma commande',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
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
