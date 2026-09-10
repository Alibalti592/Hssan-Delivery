import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/status_chip.dart';
import 'deliveries_controller.dart';
import 'delivery.dart';

class DeliveryDetailScreen extends StatelessWidget {
  const DeliveryDetailScreen({required this.deliveryId, super.key});

  final int deliveryId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeliveriesController>();
    final delivery = controller.byId(deliveryId);

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery')),
        body: const Center(
          child: Text('This delivery is no longer available.'),
        ),
      );
    }

    final order = delivery.order;
    final busy = controller.actingOnId == delivery.id;

    return Scaffold(
      appBar: AppBar(title: Text('Delivery #${delivery.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Status', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              StatusChip(delivery.status),
            ],
          ),
          const SizedBox(height: 16),
          if (order != null) ...[
            _Section(
              icon: Icons.storefront_outlined,
              title: 'Pick up from',
              child: Text(
                order.restaurantName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            _Section(
              icon: Icons.place_outlined,
              title: 'Deliver to',
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
                      'Note: ${order.note}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            _Section(
              icon: Icons.person_outline,
              title: 'Customer',
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
              title: 'Order',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${item.quantity}× ${item.productName}'),
                    ),
                  const Divider(height: 20),
                  _MoneyRow('Delivery fee', order.deliveryFee),
                  _MoneyRow('Total', order.totalAmount, bold: true),
                ],
              ),
            ),
          ] else
            const Text('Order details are unavailable.'),
          const SizedBox(height: 8),
          _ActionBar(delivery: delivery, busy: busy),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start a call to $phone')),
      );
    }
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.delivery, required this.busy});

  final Delivery delivery;
  final bool busy;

  Future<void> _run(BuildContext context, DeliveryAction action) async {
    if (action == DeliveryAction.fail) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report a problem?'),
          content: const Text(
            'This marks the delivery as failed and cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Report failure'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<DeliveriesController>().perform(
      delivery,
      action,
    );
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
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
              ? 'This delivery is closed.'
              : 'Nothing to do right now.',
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
            child: action == DeliveryAction.fail
                ? OutlinedButton(
                    onPressed: busy ? null : () => _run(context, action),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Theme.of(context).colorScheme.error,
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
