import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../addresses/address_models.dart';
import '../addresses/address_repository.dart';
import '../auth/auth_controller.dart';
import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart' show Restaurant, RestaurantType;
import '../catalogue/catalogue_repository.dart';
import '../config.dart';
import '../promotions/offer_screen.dart';
import '../promotions/promotion_model.dart';
import '../promotions/promotions_repository.dart';
import '../theme.dart';
import 'cart_screen.dart';
import 'parcel_form_screen.dart';
import 'restaurant_menu_screen.dart';
import 'restaurants_screen.dart';

/// Pastel, organic-shaped service cards — the four entry points the client
/// can currently reach from the home screen. Restaurants, Courses, and Colis
/// are wired to a real backend (a grocery store is just a Restaurant row
/// with a different type — see RestaurantType; a Colis order is an Order
/// with no restaurant — see ParcelFormScreen). Factures remains a UI-only
/// placeholder since there's no bill-payment backend yet.
class _Service {
  const _Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.comingSoon = false,
    this.restaurantType,
    this.isParcel = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool comingSoon;

  /// Set when tapping this card should open RestaurantsScreen browsing
  /// this type — null (and comingSoon true) for a placeholder service.
  final RestaurantType? restaurantType;

  /// Set when tapping this card should open ParcelFormScreen instead.
  final bool isParcel;
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
    comingSoon: true,
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Promotion>> _promotionsFuture;
  late Future<List<Restaurant>> _restaurantsFuture;
  late Future<List<SavedAddress>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _promotionsFuture = context.read<PromotionsRepository>().listActive();
    _restaurantsFuture = context.read<CatalogueRepository>().listRestaurants();
    _addressesFuture = context.read<AddressRepository>().list();
  }

  Future<void> _refresh() async {
    final promotions = context.read<PromotionsRepository>().listActive();
    final restaurants = context.read<CatalogueRepository>().listRestaurants();
    final addresses = context.read<AddressRepository>().list();
    setState(() {
      _promotionsFuture = promotions;
      _restaurantsFuture = restaurants;
      _addressesFuture = addresses;
    });
    await Future.wait([promotions, restaurants, addresses]);
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
          _TopBar(addressesFuture: _addressesFuture),
          const SizedBox(height: 18),
          const _Greeting(),
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
  const _TopBar({required this.addressesFuture});

  final Future<List<SavedAddress>> addressesFuture;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: mutedText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                FutureBuilder<List<SavedAddress>>(
                  future: addressesFuture,
                  builder: (context, snapshot) {
                    final addresses = snapshot.data ?? const [];
                    final label = addresses.isEmpty
                        ? 'Choisir une adresse'
                        : (addresses.firstWhere(
                            (a) => a.isDefault,
                            orElse: () => addresses.first,
                          )).label;
                    return Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: navy,
                        ),
                      ],
                    );
                  },
                ),
              ],
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
                Stack(
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
                    if (service.comingSoon)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: mutedText,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Bientôt',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
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
              child: restaurant.photoUrl != null
                  ? Image.network(
                      AppConfig.resolvePhotoUrl(restaurant.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: fieldFill,
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 36,
                        color: mutedText,
                      ),
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
        // their whole flyer; plain discounts keep the banner strip.
        final offers = promotions.where((p) => p.isOffer).toList();
        final banners = promotions.where((p) => !p.isOffer).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(title: 'Promotions'),
            if (offers.isNotEmpty)
              SizedBox(
                height: _OfferCard.height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: offers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _OfferCard(offer: offers[index]),
                ),
              ),
            if (banners.isNotEmpty)
              SizedBox(
                height: offers.isNotEmpty ? 146 : 134,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    offers.isNotEmpty ? 12 : 0,
                    16,
                    0,
                  ),
                  itemCount: banners.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _PromotionCard(promotion: banners[index]),
                ),
              ),
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
              offer.photoUrl != null
                  ? Image.network(
                      AppConfig.resolvePhotoUrl(offer.photoUrl!),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : Container(
                      color: fieldFill,
                      child: const Icon(
                        Icons.local_offer_outlined,
                        size: 40,
                        color: Color(0xFF9FB0C4),
                      ),
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
