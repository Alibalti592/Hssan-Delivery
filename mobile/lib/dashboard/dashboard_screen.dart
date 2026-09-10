import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../deliveries/available_deliveries_screen.dart';
import '../deliveries/deliveries_controller.dart';
import '../deliveries/deliveries_screen.dart';
import '../deliveries/delivery.dart';
import '../deliveries/delivery_detail_screen.dart';
import '../theme.dart';
import '../widgets/dark_header.dart';
import '../widgets/status_chip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _available = true;

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

  bool _isInProgress(DeliveryStatus status) {
    return status == DeliveryStatus.accepted ||
        status == DeliveryStatus.pickedUp ||
        status == DeliveryStatus.onTheWay;
  }

  Delivery? _findInProgress(List<Delivery> deliveries) {
    for (final delivery in deliveries) {
      if (_isInProgress(delivery.status)) return delivery;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeliveriesController>();
    final account = context.watch<AuthController>().account;
    final firstName = account?.name.split(' ').first ?? '';

    if (!controller.loadedOnce && controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final deliveries = controller.deliveries;
    final inProgress = _findInProgress(deliveries);
    final proposals = deliveries
        .where((d) => d.status == DeliveryStatus.assigned)
        .length;

    final now = DateTime.now();
    final deliveredToday = deliveries.where((d) {
      final at = d.deliveredAt;
      if (d.status != DeliveryStatus.delivered || at == null) {
        return false;
      }
      return at.year == now.year && at.month == now.month && at.day == now.day;
    }).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DarkHeader(
              title: 'Bonjour, $firstName',
              subtitle: _available
                  ? 'Vous êtes disponible'
                  : 'Vous êtes hors-ligne',
              trailing: IconButton(
                tooltip: 'Se déconnecter',
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Disponible',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Switch(
                              value: _available,
                              onChanged: (value) =>
                                  setState(() => _available = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            value: '$deliveredToday',
                            label: "Livrées\naujourd'hui",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            value: '$proposals',
                            label: 'Propositions\nen attente',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (inProgress != null) ...[
                      Text(
                        'Course en cours',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _InProgressCard(
                        delivery: inProgress,
                        onContinue: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DeliveryDetailScreen(
                                deliveryId: inProgress.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        'Aucune course en cours',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                proposals > 0
                                    ? Icons.local_shipping_outlined
                                    : Icons.nightlight_outlined,
                                color: Theme.of(context).colorScheme.outline,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                proposals > 0
                                    ? '$proposals nouvelle(s) course(s) disponible(s)'
                                    : 'Aucune course disponible pour le moment',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AvailableDeliveriesScreen(),
                        ),
                      ),
                      child: const Text('Voir les courses disponibles'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DeliveriesScreen(),
                        ),
                      ),
                      child: const Text('Toutes mes courses'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InProgressCard extends StatelessWidget {
  const _InProgressCard({required this.delivery, required this.onContinue});

  final Delivery delivery;
  final VoidCallback onContinue;

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
                StatusChip(delivery.status),
              ],
            ),
            if (order != null) ...[
              const SizedBox(height: 8),
              Text(
                order.deliveryAddress,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onContinue,
              child: const Text('Continuer la course'),
            ),
          ],
        ),
      ),
    );
  }
}
