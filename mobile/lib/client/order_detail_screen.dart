import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import '../widgets/decorative_map.dart';
import '../widgets/order_status_chip.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: Column(
        children: [
          if (tracking) const DecorativeMap(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Commande #${order.id}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    OrderStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 16),
                if (tracking) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: _StatusTimeline(status: order.status),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(order.deliveryAddress)),
                          ],
                        ),
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
                  'Articles',
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
                              Expanded(child: Text(item.productName)),
                              Text('${item.unitPrice} DT'),
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
                    ],
                  ),
                ),
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

/// Progress through the order lifecycle, based purely on the current
/// [OrderStatus] — the backend doesn't record a timestamp per stage, so this
/// shows which stages are done/current/upcoming without inventing times.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final OrderStatus status;

  static const _stages = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.readyForPickup,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stages.indexOf(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _stages.length; i++)
          _TimelineRow(
            label: _stages[i].label,
            isDone: i < currentIndex,
            isCurrent: i == currentIndex,
            isLast: i == _stages.length - 1,
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
  });

  final String label;
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
          Column(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.4, color: const Color(0xFFE6EAEF)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? navy : mutedText,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
