import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'deliveries_controller.dart';
import 'delivery.dart';
import 'delivery_detail_screen.dart';

class AvailableDeliveriesScreen extends StatefulWidget {
  const AvailableDeliveriesScreen({super.key});

  @override
  State<AvailableDeliveriesScreen> createState() =>
      _AvailableDeliveriesScreenState();
}

class _AvailableDeliveriesScreenState extends State<AvailableDeliveriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveriesController>().refresh();
    });
  }

  Future<void> _decline(Delivery delivery) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<DeliveriesController>().perform(
      delivery,
      DeliveryAction.decline,
    );
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Course refusée.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeliveriesController>();
    final proposals = controller.deliveries
        .where((d) => d.status == DeliveryStatus.assigned)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Courses disponibles')),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: proposals.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text('Aucune course disponible pour le moment.'),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: proposals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final delivery = proposals[index];
                  final busy = controller.actingOnId == delivery.id;
                  return _ProposalCard(
                    delivery: delivery,
                    busy: busy,
                    onAccept: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final error = await context
                          .read<DeliveriesController>()
                          .perform(delivery, DeliveryAction.accept);
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DeliveryDetailScreen(deliveryId: delivery.id),
                        ),
                      );
                    },
                    onDecline: () => _decline(delivery),
                  );
                },
              ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.delivery,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Delivery delivery;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final order = delivery.order;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order?.restaurantName ?? 'Course #${delivery.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (order != null)
                  Text(
                    '${order.totalAmount} DT',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (order != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
