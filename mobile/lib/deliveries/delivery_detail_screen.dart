import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../addresses/route_map.dart';
import '../bills/bill_widgets.dart';
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
    final pickup = order != null && order.hasPickupLocation && !order.isBill
        ? LatLng(order.pickupLatitude!, order.pickupLongitude!)
        : null;
    final dropOff = order != null && order.hasDeliveryLocation
        ? LatLng(order.deliveryLatitude!, order.deliveryLongitude!)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text('Course #${delivery.id}')),
      body: Column(
        children: [
          if (!delivery.status.isTerminal && RouteMap.canShow(pickup, dropOff))
            RouteMap(pickup: pickup, dropOff: dropOff),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Text(
                      'Statut',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    StatusChip(delivery.status),
                  ],
                ),
                const SizedBox(height: 16),
                if (order != null) ...[
                  if (order.bill != null) ...[
                    BillDetailsCard(
                      bill: order.bill!,
                      recipientName: order.recipientName,
                      recipientPhone: order.recipientPhone,
                      onCallRecipient:
                          order.recipientPhone == null ||
                              order.recipientPhone!.isEmpty
                          ? null
                          : () => _call(context, order.recipientPhone!),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _Section(
                    icon: order.isParcel
                        ? Icons.inventory_2_outlined
                        : Icons.storefront_outlined,
                    title: order.isParcel || order.isBill
                        ? 'Récupérer à'
                        : 'Récupérer chez',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.isParcel || order.isBill
                              ? (order.pickupAddress ?? '')
                              : (order.restaurantName ?? ''),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        // A bill's pickup and drop-off are the same pin,
                        // offered once under "Rapporter le reçu à".
                        if (order.hasPickupLocation && !order.isBill)
                          _OpenInMapsButton(
                            latitude: order.pickupLatitude!,
                            longitude: order.pickupLongitude!,
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.place_outlined,
                    title: order.isBill ? 'Rapporter le reçu à' : 'Livrer à',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.deliveryAddress,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (order.hasDeliveryLocation)
                          _OpenInMapsButton(
                            latitude: order.deliveryLatitude!,
                            longitude: order.deliveryLongitude!,
                          ),
                        if (order.note != null &&
                            order.note!.trim().isNotEmpty) ...[
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
                    title: order.isParcel ? 'Destinataire' : 'Client',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.contactName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (order.contactPhone != null &&
                            order.contactPhone!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _call(context, order.contactPhone!),
                            icon: const Icon(Icons.phone),
                            label: Text(order.contactPhone!),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.receipt_long_outlined,
                    title: order.isBill
                        ? 'Argent à récupérer'
                        : order.isParcel
                        ? 'Colis'
                        : 'Commande',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${item.quantity}× ${item.displayName}',
                            ),
                          ),
                        if (order.bill != null)
                          _MoneyRow(
                            order.bill!.isTransfer
                                ? 'Montant du mandat'
                                : 'Montant de la facture',
                            order.bill!.amount,
                          ),
                        if (order.items.isNotEmpty || order.bill == null)
                          const Divider(height: 20),
                        if (order.hasDiscount)
                          _MoneyRow(
                            'Réduction · ${order.promotionTitle ?? 'promotion'}',
                            '-${order.discountAmount}',
                          ),
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
          ),
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

/// Directions to the pin the client placed, in Google Maps (or whatever
/// the phone opens map links with).
class _OpenInMapsButton extends StatelessWidget {
  const _OpenInMapsButton({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la carte.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.navigation_outlined),
        label: const Text('Ouvrir dans Maps'),
      ),
    );
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
                    child: Text(action.labelFor(delivery.order)),
                  )
                : FilledButton(
                    onPressed: busy ? null : () => _run(context, action),
                    child: busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(action.labelFor(delivery.order)),
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
          Flexible(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text('$amount DT', style: style),
        ],
      ),
    );
  }
}
