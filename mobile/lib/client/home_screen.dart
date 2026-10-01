import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_picker.dart';
import '../addresses/selected_address.dart';
import '../auth/auth_controller.dart';
import '../bills/bill_providers_screen.dart';
import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart' show Restaurant, RestaurantType;
import '../catalogue/catalogue_repository.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../promotions/auto_carousel.dart';
import '../promotions/offer_screen.dart';
import '../promotions/promotion_model.dart';
import '../promotions/promotions_repository.dart';
import '../theme.dart';
import 'active_order_banner.dart';
import 'cart_screen.dart';
import 'order_detail_screen.dart';
import 'parcel_form_screen.dart';
import 'restaurant_menu_screen.dart';
import 'restaurants_screen.dart';
import '../widgets/app_photo.dart';

/// Pastel, organic-shaped service cards — the four entry points the client
/// can currently reach from the home screen. Restaurants, Courses, and Colis
/// are wired to a real backend (a grocery store is just a Restaurant row
/// with a different type — see RestaurantType; a Colis order is an Order
/// with no restaurant — see ParcelFormScreen). Factures sends a courier to
/// pay a bill or a mandat with the client's cash — see BillProvidersScreen.
class _Service {
  const _Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.restaurantType,
    this.isParcel = false,
    this.isBills = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Set when tapping this card should open RestaurantsScreen browsing
  /// this type — null for a service with its own screen (Colis, Factures).
  final RestaurantType? restaurantType;

  /// Set when tapping this card should open ParcelFormScreen instead.
  final bool isParcel;

  /// Set when tapping this card should open BillProvidersScreen instead.
  final bool isBills;
}

const _services = [
  _Service(
    title: 'Restaurants',
    subtitle: 'Vos plats préférés',
    icon: Icons.restaurant_menu,
    restaurantType: RestaurantType.restaurant,
  ),
  _Service(
    title: 'Factures',
    subtitle: 'Paiement rapide',
    icon: Icons.receipt_long,
    isBills: true,
  ),
  _Service(
    title: 'Courses',
    subtitle: 'Produits du quotidien',
    icon: Icons.shopping_basket_outlined,
    restaurantType: RestaurantType.grocery,
  ),
  _Service(
    title: 'Colis',
    subtitle: 'Envoi rapide',
    icon: Icons.local_shipping_outlined,
    isParcel: true,
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.onSeeOrders, super.key});

  /// Switches to the "Commandes" tab (several orders in progress).
  final VoidCallback? onSeeOrders;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Promotion>> _promotionsFuture;
  late Future<List<Restaurant>> _restaurantsFuture;
  List<ClientOrder> _activeOrders = const [];
  Timer? _activePoll;
  StreamSubscription<int>? _orderChanges;

  @override
  void initState() {
    super.initState();
    _promotionsFuture = context.read<PromotionsRepository>().listActive();
    _restaurantsFuture = context.read<CatalogueRepository>().listRestaurants();
    _loadAddress();
    _loadActiveOrders();
    _orderChanges = context.read<OrdersRepository>().changes.listen(
      (_) => _loadActiveOrders(),
    );
  }

  @override
  void dispose() {
    _activePoll?.cancel();
    _orderChanges?.cancel();
    super.dispose();
  }

  /// The orders still on their way, for the banner. Checked again every
  /// 20 seconds while there is one; a failure keeps what was shown.
  Future<void> _loadActiveOrders() async {
    _activePoll?.cancel();
    try {
      final result = await context.read<OrdersRepository>().listOrders();
      if (!mounted) return;
      setState(() {
        _activeOrders = result.items
            .where((o) => !o.status.isTerminal)
            .toList(growable: false);
      });
    } catch (_) {
      // Best effort: the banner is a shortcut, Commandes has the full list.
    }
    if (mounted && _activeOrders.isNotEmpty) {
      _activePoll = Timer(const Duration(seconds: 20), _loadActiveOrders);
    }
  }

  /// A failure only leaves "Choisir une adresse" in the header.
  Future<void> _loadAddress() async {
    try {
      await context.read<SelectedAddressController>().load();
    } catch (_) {
      // Best effort: offline, signed out mid-load or an unexpected
      // response all just leave "Choisir une adresse" in the header.
    }
  }

  Future<void> _refresh() async {
    final promotions = context.read<PromotionsRepository>().listActive();
    final restaurants = context.read<CatalogueRepository>().listRestaurants();
    setState(() {
      _promotionsFuture = promotions;
      _restaurantsFuture = restaurants;
    });
    await Future.wait([
      promotions,
      restaurants,
      _loadAddress(),
      _loadActiveOrders(),
    ]);
  }

  void _openService(_Service service) {
    if (service.isBills) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const BillProvidersScreen()));
      return;
    }

    if (service.isParcel) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ParcelFormScreen()));
      return;
    }

    final type = service.restaurantType ?? RestaurantType.restaurant;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(service.title)),
          body: RestaurantsScreen(type: type),
        ),
      ),
    );
  }

  void _openRestaurant(Restaurant restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantMenuScreen(restaurant: restaurant),
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
          const _TopBar(),
          const SizedBox(height: 18),
          const _Greeting(),
          ActiveOrderBanner(
            orders: _activeOrders,
            onOpen: (order) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(orderId: order.id),
              ),
            ),
            onSeeAll: widget.onSeeOrders,
          ),
          const SizedBox(height: 16),
          _SearchBar(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Restaurants')),
                  body: const RestaurantsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _SectionHeader(title: 'Services'),
          SizedBox(
            height: 144,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _services.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final service = _services[index];
                return _ServiceCard(
                  service: service,
                  onTap: () => _openService(service),
                );
              },
            ),
          ),
          // Below the services, not above: the services are how the app is
          // used, and the tall offer cards would otherwise push them below
          // the fold on small phones. The row still shows on first screen.
          _PromotionsSection(future: _promotionsFuture, onRetry: _refresh),
          const SizedBox(height: 8),
          _SectionHeader(
            title: 'Restaurants',
            onSeeAll: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Restaurants')),
                  body: const RestaurantsScreen(),
                ),
              ),
            ),
          ),
          _RestaurantsPreview(
            future: _restaurantsFuture,
            onTapRestaurant: _openRestaurant,
          ),
        ],
      ),
    );
  }
}

/// Address (left) + cart shortcut (right), full-bleed at the top of the
/// scrollable home feed.
class _TopBar extends StatelessWidget {
  const _TopBar();

  Future<void> _changeAddress(BuildContext context) async {
    final selection = context.read<SelectedAddressController>();
    final picked = await showAddressSheet(
      context,
      selected: selection.current,
      title: 'Livrer à',
    );
    if (picked != null) selection.select(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final address = context.watch<SelectedAddressController>().current;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _changeAddress(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: mutedText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVRER À',
                          style: textTheme.labelSmall?.copyWith(
                            color: mutedText,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            address == null
                                ? 'Choisir une adresse'
                                : '${address.label} · ${address.addressLine}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: navy,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  if (!cart.isEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthController>().account;
    final firstName = (account?.name ?? '').split(' ').first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text.rich(
        TextSpan(
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
          children: [
            const TextSpan(text: 'Bonjour'),
            if (firstName.isNotEmpty) ...[
              const TextSpan(text: ', '),
              TextSpan(
                text: firstName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
            const TextSpan(text: ' !'),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: mutedText, size: 20),
              const SizedBox(width: 10),
              Text(
                'Rechercher un plat, un restaurant',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: mutedText,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Icon(Icons.chevron_right, size: 18),
                ],
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
      width: 104,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fieldFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(service.icon, color: navy, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  service.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  service.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantsPreview extends StatelessWidget {
  const _RestaurantsPreview({
    required this.future,
    required this.onTapRestaurant,
  });

  final Future<List<Restaurant>> future;
  final void Function(Restaurant) onTapRestaurant;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text('Impossible de charger les restaurants.'),
          );
        }

        // The home feed only ever teases restaurants — "Voir tout" is where
        // the full, searchable list lives — so cap it well short of a full
        // page's worth even when the catalogue is large.
        final restaurants = (snapshot.data ?? const []).take(4).toList();

        if (restaurants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text('Aucun restaurant disponible pour le moment.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final restaurant in restaurants)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RestaurantPreviewCard(
                    restaurant: restaurant,
                    onTap: () => onTapRestaurant(restaurant),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RestaurantPreviewCard extends StatelessWidget {
  const _RestaurantPreviewCard({required this.restaurant, required this.onTap});

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AppPhoto(
                restaurant.photoUrl,
                icon: Icons.storefront_outlined,
                iconSize: 36,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (restaurant.description != null &&
                            restaurant.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            restaurant.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: mutedText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: restaurant.isAvailable ? successBg : dangerBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      restaurant.isAvailable ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        color: restaurant.isAvailable
                            ? successText
                            : dangerText,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
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

        // Offers (orderable, sold at a set price) get tall cards that show
        // their whole flyer; plain discounts keep the banner strip. Both
        // slide on their own (AutoCarousel).
        final offers = promotions.where((p) => p.isOffer).toList();
        final banners = promotions.where((p) => !p.isOffer).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(title: 'Promotions'),
            if (offers.isNotEmpty)
              AutoCarousel(
                itemCount: offers.length,
                itemWidth: _OfferCard.width,
                height: _OfferCard.height,
                itemBuilder: (context, index) =>
                    _OfferCard(offer: offers[index]),
              ),
            if (banners.isNotEmpty) ...[
              if (offers.isNotEmpty) const SizedBox(height: 14),
              AutoCarousel(
                itemCount: banners.length,
                itemWidth: 260,
                height: 134,
                itemBuilder: (context, index) =>
                    _PromotionCard(promotion: banners[index]),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A fixed-price offer: its flyer in portrait, the price, and a tap into
/// [OfferScreen] to order it.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final Promotion offer;

  // Sized so the row shows on the first screen together with the services
  // above it; the offer page shows the flyer in full.
  static const double width = 185;
  // 3:4 -- the usual shape of a social-media flyer.
  static const double height = width * 4 / 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => OfferScreen(offer: offer))),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppPhoto(
                offer.photoUrl,
                icon: Icons.local_offer_outlined,
                iconSize: 40,
                alignment: Alignment.topCenter,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Dark enough at the bottom for the title to read over
                    // whatever text the flyer itself has there.
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 0.72, 1],
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.82),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(top: 8, left: 8, child: OfferTag()),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.restaurantName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD5DAE1),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            offer.discountLabel,
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            AppPhoto(
              promotion.photoUrl,
              icon: Icons.local_offer_outlined,
              iconSize: 36,
            ),
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
