import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  late Future<List<ClientOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ClientOrder>> _load() {
    return context.read<OrdersRepository>().listOrders();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ClientOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 100),
                Center(
                  child: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Réessayer'),
                  ),
                ),
              ],
            );
          }

          final orders = snapshot.data ?? const [];
          if (orders.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 100),
                Center(child: Text("Vous n'avez pas encore de commande.")),
              ],
            );
          }

          final sorted = [...orders]
            ..sort((a, b) => b.id.compareTo(a.id));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = sorted[index];
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
        },
      ),
    );
  }
}
