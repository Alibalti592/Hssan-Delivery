import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'deliveries_controller.dart';
import 'delivery.dart';
import 'delivery_detail_screen.dart';
import '../widgets/status_chip.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveriesController>().refresh();
    });
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AuthController>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeliveriesController>();
    final account = context.watch<AuthController>().account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toutes mes courses'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: _confirmSignOut,
          ),
        ],
        bottom: account == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Connecté en tant que ${account.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _body(context, controller),
      ),
    );
  }

  Widget _body(BuildContext context, DeliveriesController controller) {
    if (!controller.loadedOnce && controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!controller.loadedOnce && controller.error != null) {
      return _Message(
        icon: Icons.wifi_off,
        title: 'Impossible de charger vos courses',
        detail: controller.error,
        onRetry: controller.refresh,
      );
    }

    final active = controller.active;
    final history = controller.history;

    if (active.isEmpty && history.isEmpty) {
      return _Message(
        icon: Icons.inbox_outlined,
        title: 'Aucune course pour le moment',
        detail: 'Les courses qui vous sont assignées apparaîtront ici.',
        onRetry: controller.refresh,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              controller.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (active.isNotEmpty) ...[
          _SectionLabel('En cours (${active.length})'),
          for (final d in active) _DeliveryCard(delivery: d),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionLabel('Historique'),
          for (final d in history) _DeliveryCard(delivery: d),
        ],
        if (controller.hasMoreHistory) ...[
          const SizedBox(height: 8),
          Center(
            child: controller.loadingMoreHistory
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : OutlinedButton(
                    onPressed: () => _loadMoreHistory(context),
                    child: const Text('Charger plus d\'historique'),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadMoreHistory(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<DeliveriesController>().loadMoreHistory();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final order = delivery.order;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeliveryDetailScreen(deliveryId: delivery.id),
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
                      order?.restaurantName ?? 'Delivery #${delivery.id}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StatusChip(delivery.status),
                ],
              ),
              if (order != null) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.deliveryAddress,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.items.length} article(s) · ${order.totalAmount} DT',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (detail != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              detail!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ),
        ],
      ],
    );
  }
}
