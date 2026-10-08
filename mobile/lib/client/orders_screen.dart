import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/order_tracking.dart';
import '../orders/orders_repository.dart';
import '../theme.dart';
import '../widgets/order_status_chip.dart';
import 'order_detail_screen.dart';
import 'reorder_action.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final List<ClientOrder> _orders = [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription<int>? _pushes;

  @override
  void initState() {
    super.initState();
    _load();
    _pushes = context.read<OrdersRepository>().changes.listen(
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushes?.cancel();
    super.dispose();
  }

  /// [silent]: refresh in place (a poll or a push) without the spinner.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await context.read<OrdersRepository>().listOrders();
      if (!mounted) return;
      setState(() {
        if (silent && _page > 1) {
          // Keep the pages already loaded: update what's on page 1 and put
          // any new order on top.
          final fresh = {for (final o in result.items) o.id: o};
          final known = _orders.map((o) => o.id).toSet();
          final updated = [
            ...result.items.where((o) => !known.contains(o.id)),
            ..._orders.map((o) => fresh[o.id] ?? o),
          ];
          _orders
            ..clear()
            ..addAll(updated);
        } else {
          _orders
            ..clear()
            ..addAll(result.items);
          _page = result.page;
          _pages = result.pages;
        }
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scheduleNextPoll();
      }
    }
  }

  /// While an order is still on its way, its status keeps changing: check
  /// again in a bit. Nothing to watch once they're all done.
  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    if (_orders.every((o) => o.status.isTerminal)) return;
    _pollTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final result = await context.read<OrdersRepository>().listOrders(
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        // An order placed since page 1 was fetched shifts older ones down a
        // page: the next page can repeat one already shown.
        final known = _orders.map((o) => o.id).toSet();
        _orders.addAll(result.items.where((o) => !known.contains(o.id)));
        _page = result.page;
        _pages = result.pages;
      });
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
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _orders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: OutlinedButton(
              onPressed: _load,
              child: const Text('Réessayer'),
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text("Vous n'avez pas encore de commande.")),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length + (_page < _pages ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _orders.length) {
          return Center(
            child: _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : OutlinedButton(
                    onPressed: _loadMore,
                    child: const Text('Charger plus'),
                  ),
          );
        }

        return _OrderCard(order: _orders[index]);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = order.createdAt;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: fieldFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(order.serviceIcon, color: navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (date != null) formatOrderDate(date.toLocal()),
                            '#${order.id}',
                          ].join(' · '),
                          style: textTheme.bodySmall?.copyWith(
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OrderStatusChip(order.status, label: orderStatusText(order)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _summary(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${order.totalAmount} DT',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (order.status == OrderStatus.completed &&
                  order.isFromCatalogue)
                Align(
                  alignment: Alignment.centerRight,
                  child: ReorderButton(order: order, compact: true),
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  /// "2× Pizza Margherita, 1× Coca" / "Pour Sami" / "Réf. 123456".
  static String _summary(ClientOrder order) {
    final bill = order.bill;
    if (bill != null) {
      if (bill.isTransfer) {
        return order.recipientName == null
            ? 'Mandat'
            : 'Pour ${order.recipientName}';
      }
      return bill.reference == null ? 'Facture' : 'Réf. ${bill.reference}';
    }
    if (order.isParcel) {
      return order.recipientName == null
          ? order.deliveryAddress
          : 'Pour ${order.recipientName}';
    }
    return order.items.map((i) => '${i.quantity}× ${i.displayName}').join(', ');
  }
}

const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// "Aujourd'hui, 14:05" / "Hier, 20:30" / "12 sept., 19:45".
String formatOrderDate(DateTime date, {DateTime? now}) {
  now ??= DateTime.now();
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo == 0) return "Aujourd'hui, $time";
  if (daysAgo == 1) return 'Hier, $time';
  final year = date.year == now.year ? '' : ' ${date.year}';
  return '${date.day} ${_months[date.month - 1]}$year, $time';
}
