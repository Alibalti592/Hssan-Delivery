import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/status_chip.dart';
import 'deliveries_controller.dart';
import 'delivery.dart';
import 'delivery_confirmed_screen.dart';

class DeliveryDetailScreen extends StatelessWidget {
  const DeliveryDetailScreen({required this.deliveryId, super.key});

  final int deliveryId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeliveriesController>();
    final delivery = controller.byId(deliveryId);

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course')),
        body: const Center(child: Text('Cette course n\'est plus disponible.')),
      );
    }

    final order = delivery.order;
    final busy = controller.actingOnId == delivery.id;

    return Scaffold(
      appBar: AppBar(title: Text('Course #${delivery.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Statut', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              StatusChip(delivery.status),
            ],
          ),
          const SizedBox(height: 16),
          if (order != null) ...[
            _Section(
              icon: Icons.storefront_outlined,
              title: 'Récupérer chez',
              child: Text(
                order.restaurantName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            _Section(
              icon: Icons.place_outlined,
              title: 'Livrer à',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.deliveryAddress,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (order.note != null && order.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Note : ${order.note}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            _Section(
              icon: Icons.person_outline,
              title: 'Client',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (order.customerPhone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _call(context, order.customerPhone),
                      icon: const Icon(Icons.phone),
                      label: Text(order.customerPhone),
                    ),
                  ],
                ],
              ),
            ),
            _Section(
              icon: Icons.receipt_long_outlined,
              title: 'Commande',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${item.quantity}× ${item.productName}'),
                    ),
                  const Divider(height: 20),
                  _MoneyRow('Frais de livraison', order.deliveryFee),
                  _MoneyRow('Total', order.totalAmount, bold: true),
                ],
              ),
            ),
          ] else
            const Text('Les détails de la commande sont indisponibles.'),
          const SizedBox(height: 8),
          _ActionBar(delivery: delivery, busy: busy),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d\'appeler $phone')));
    }
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.delivery, required this.busy});

  final Delivery delivery;
  final bool busy;

  Future<void> _run(BuildContext context, DeliveryAction action) async {
    if (action.isDestructive) {
      final isDecline = action == DeliveryAction.decline;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            isDecline ? 'Refuser cette course ?' : 'Signaler un échec ?',
          ),
          content: Text(
            isDecline
                ? 'Elle sera proposée à un autre livreur.'
                : 'Cette action marque la livraison comme échouée et ne peut pas être annulée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isDecline ? 'Refuser' : 'Signaler'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!context.mounted) return;
    final controller = context.read<DeliveriesController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await controller.perform(delivery, action);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (action == DeliveryAction.decline) {
      navigator.pop();
      return;
    }

    if (action == DeliveryAction.delivered) {
      final updated = controller.byId(delivery.id) ?? delivery;
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => DeliveryConfirmedScreen(delivery: updated),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = delivery.availableActions;

    if (actions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          delivery.status.isTerminal
              ? 'Cette course est terminée.'
              : 'Rien à faire pour le moment.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: action.isDestructive
                ? OutlinedButton(
                    onPressed: busy ? null : () => _run(context, action),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: Text(action.label),
                  )
                : FilledButton(
                    onPressed: busy ? null : () => _run(context, action),
                    child: busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(action.label),
                  ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(this.label, this.amount, {this.bold = false});

  final String label;
  final String amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$amount DT', style: style),
        ],
      ),
    );
  }
}
