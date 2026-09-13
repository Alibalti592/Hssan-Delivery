import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../promotions/promotion_model.dart';
import '../promotions/promotions_repository.dart';
import '../theme.dart';
import 'restaurants_screen.dart';

/// Pastel, organic-shaped service cards — the four entry points the client
/// can currently reach from the home screen. Restaurants is the only one
/// wired to a real backend; the rest are UI-only placeholders (see
/// App\Controller — there is no Factures/Courses/Colis backend yet).
class _Service {
  const _Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool comingSoon;
}

const _services = [
  _Service(
    title: 'Restaurants',
    subtitle: 'Vos plats préférés',
    icon: Icons.restaurant_menu,
    background: Color(0xFFFFE8D6),
    foreground: Color(0xFFB3541E),
  ),
  _Service(
    title: 'Factures',
    subtitle: 'Paiement rapide',
    icon: Icons.receipt_long,
    background: Color(0xFFDCEBFF),
    foreground: Color(0xFF2A5DA6),
    comingSoon: true,
  ),
  _Service(
    title: 'Courses',
    subtitle: 'Produits du quotidien',
    icon: Icons.shopping_basket_outlined,
    background: Color(0xFFE1F3E0),
    foreground: Color(0xFF347A34),
    comingSoon: true,
  ),
  _Service(
    title: 'Colis',
    subtitle: 'Envoi rapide',
    icon: Icons.local_shipping_outlined,
    background: Color(0xFFF0E4FA),
    foreground: Color(0xFF7B4CA8),
    comingSoon: true,
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Promotion>> _promotionsFuture;

  @override
  void initState() {
    super.initState();
    _promotionsFuture = _load();
  }

  Future<List<Promotion>> _load() {
    return context.read<PromotionsRepository>().listActive();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _promotionsFuture = future);
    await future;
  }

  void _openService(_Service service) {
    if (service.comingSoon) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('Service bientôt disponible'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Restaurants')),
          body: const RestaurantsScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _PromotionsSection(future: _promotionsFuture, onRetry: _refresh),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Services',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _services.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final service = _services[index];
                return _ServiceCard(
                  service: service,
                  onTap: () => _openService(service),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final _Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Material(
        color: service.background,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(service.icon, color: service.foreground, size: 26),
                    if (service.comingSoon)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Bientôt',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: service.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  service.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: service.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: service.foreground.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionsSection extends StatelessWidget {
  const _PromotionsSection({required this.future, required this.onRetry});

  final Future<List<Promotion>> future;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Promotion>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 150,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  const Text('Impossible de charger les promotions.'),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final promotions = snapshot.data ?? const [];

        if (promotions.isEmpty) {
          // Quietly absent rather than an empty placeholder card — a home
          // screen with nothing promotional to show shouldn't draw the
          // eye to a gap where the carousel would otherwise be.
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            itemCount: promotions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _PromotionCard(promotion: promotions[index]),
          ),
        );
      },
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            promotion.photoUrl != null
                ? Image.network(
                    AppConfig.resolvePhotoUrl(promotion.photoUrl!),
                    fit: BoxFit.cover,
                  )
                : Container(color: fieldFill),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    promotion.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    promotion.discountLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
