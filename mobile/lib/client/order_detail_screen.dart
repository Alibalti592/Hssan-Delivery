import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../addresses/route_map.dart';
import '../bills/bill_widgets.dart';
import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/order_tracking.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import '../widgets/cash_payment_note.dart';
import '../widgets/order_status_chip.dart';
import 'reorder_action.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  ClientOrder? _order;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription<int>? _pushes;

  @override
  void initState() {
    super.initState();
    _load();
    // A push about this order: show the new status now, not at the next poll.
    _pushes = context
        .read<OrdersRepository>()
        .changes
        .where((id) => id == widget.orderId)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushes?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final order = await context.read<OrdersRepository>().getOrder(
        widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
      });
      _scheduleNextPoll(order);
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The backend only pushes a notification for two of the six order
  /// transitions (see DeliveryNotificationListener) — polling covers the
  /// rest (confirmed/preparing/ready-for-pickup) without needing a
  /// websocket. Stops once the order reaches a terminal status.
  void _scheduleNextPoll(ClientOrder order) {
    _pollTimer?.cancel();
    if (order.status.isTerminal) return;
    _pollTimer = Timer(const Duration(seconds: 15), () => _load(silent: true));
  }

  Future<void> _confirmCancel() async {
    final order = _order;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await context.read<OrdersRepository>().cancelOrder(
        order.id,
      );
      if (!mounted) return;
      setState(() => _order = updated);
      _scheduleNextPoll(updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d\'appeler $phone')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.orderId}')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _order == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _order == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Impossible de charger cette commande.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _load(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final order = _order!;
    final tracking = order.status != OrderStatus.cancelled;
    // A bill's courier collects and returns to the same door: one pin.
    final pickup = order.isBill ? null : order.pickupPoint;
    final dropOff = order.deliveryPoint;

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: Column(
        children: [
          if (tracking && RouteMap.canShow(pickup, dropOff))
            RouteMap(pickup: pickup, dropOff: dropOff),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(order.serviceIcon, color: navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        order.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrderStatusChip(
                      order.status,
                      label: orderStatusText(order),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (tracking) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: _StatusTimeline(order: order),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (order.courierName != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.delivery_dining_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              order.courierName!,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          if (order.courierPhone != null &&
                              order.courierPhone!.isNotEmpty)
                            OutlinedButton.icon(
                              // The theme's full-width minimum would
                              // squeeze the courier's name to one letter a
                              // line next to it.
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () => _call(order.courierPhone!),
                              icon: const Icon(Icons.phone, size: 18),
                              label: const Text('Appeler'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (order.bill != null) ...[
                  BillDetailsCard(
                    bill: order.bill!,
                    recipientName: order.recipientName,
                    recipientPhone: order.recipientPhone,
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.isParcel && order.pickupAddress != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.pickupAddress!)),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(order.deliveryAddress)),
                          ],
                        ),
                        if (order.isParcel && order.recipientName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.recipientPhone != null &&
                                          order.recipientPhone!.isNotEmpty
                                      ? '${order.recipientName} · ${order.recipientPhone}'
                                      : order.recipientName!,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(order.deliveryZoneName),
                          ],
                        ),
                        if (order.note != null && order.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(order.note!)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  order.isParcel || order.isBill ? 'Récapitulatif' : 'Articles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Text('${item.quantity}x '),
                              Expanded(child: Text(item.displayName)),
                              Text('${item.unitPrice} DT'),
                            ],
                          ),
                        ),
                      if (order.bill != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order.bill!.isTransfer
                                    ? 'Montant du mandat'
                                    : 'Montant de la facture',
                              ),
                              Text('${order.bill!.amount} DT'),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Frais de livraison'),
                            Text('${order.deliveryFee} DT'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${order.totalAmount} DT',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      CashPaymentNote(
                        cardFooter: true,
                        text: order.isBill
                            ? 'Paiement en espèces, à remettre au livreur'
                            : 'Paiement en espèces à la livraison',
                      ),
                    ],
                  ),
                ),
                if (order.status == OrderStatus.completed &&
                    order.isFromCatalogue) ...[
                  const SizedBox(height: 16),
                  ReorderButton(order: order),
                ],
                if (order.canCancel) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _cancelling ? null : _confirmCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dangerText,
                    ),
                    child: _cancelling
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Annuler la commande'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The order's progress in its service's own words (see trackingSteps) —
/// the backend doesn't record a time per step, so none is invented here.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
    final steps = trackingSteps(order);
    final hint = trackingHint(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            label: steps[i].label,
            hint: steps[i].isCurrent ? hint : null,
            isDone: steps[i].isDone,
            isCurrent: steps[i].isCurrent,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final active = isDone || isCurrent;
    final dotColor = isCurrent ? warnText : (isDone ? successText : cardBorder);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: isDone ? 16 : 12,
                  height: isDone ? 16 : 12,
                  margin: EdgeInsets.all(isDone ? 0 : 2),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone ? successText : const Color(0xFFE6EAEF),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? navy : mutedText,
                      fontSize: 13,
                    ),
                  ),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        hint!,
                        style: const TextStyle(color: mutedText, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
