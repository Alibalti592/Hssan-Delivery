import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import '../widgets/order_status_chip.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<ClientOrder> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<OrdersRepository>().getOrder(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.orderId}')),
      body: FutureBuilder<ClientOrder>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger cette commande.'),
            );
          }

          final order = snapshot.data!;
          return ListView(
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
              if (order.status != OrderStatus.cancelled) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: _StatusTimeline(status: order.status),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
            ],
          );
        },
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
