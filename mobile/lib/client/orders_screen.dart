import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../widgets/order_status_chip.dart';
import 'order_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<OrdersRepository>().listOrders();
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _pages = result.pages;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        _orders.addAll(result.items);
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
    return RefreshIndicator(onRefresh: _load, child: _body(context));
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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

        final order = _orders[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(orderId: order.id),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Commande #${order.id}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OrderStatusChip(order.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${order.items.length} article(s) · '
                    '${order.totalAmount} DT',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
