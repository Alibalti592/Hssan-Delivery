import '../addresses/address_picker.dart';
import '../addresses/selected_address.dart';
import '../auth/auth_controller.dart';
import '../bills/bill_providers_screen.dart';
import '../cart/cart.dart';
import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/category_widgets.dart';
import '../orders/order_models.dart';
import '../orders/orders_repository.dart';
import '../promotions/auto_carousel.dart';
import '../promotions/promotion_model.dart';
import '../promotions/promotions_repository.dart';
import '../theme.dart';
import 'active_order_banner.dart';
import 'cart_screen.dart';
import 'dart:async';
import 'home_feed.dart';
import 'home_sections.dart';
import 'order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'parcel_form_screen.dart';
import 'product_detail_screen.dart';
import 'restaurant_menu_screen.dart';
import 'restaurants_screen.dart';
import 'search_screen.dart';

/// Pastel, organic-shaped service cards — the four entry points the client
/// can currently reach from the home screen. Restaurants, Courses, and Colis
/// are wired to a real backend (a grocery store is just a Restaurant row
/// with a different type — see RestaurantType; a Colis order is an Order
/// with no restaurant — see ParcelFormScreen). Factures sends a courier to
/// pay a bill or a mandat with the client's cash — see BillProvidersScreen.
class _Service {
  const _Service({
    required this.title,
    required this.image,
    this.restaurantType,
    this.isParcel = false,
    this.isBills = false,
  });

  final String title;

  /// The illustration on the tile (assets/services/).
  final String image;

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
    image: 'assets/services/restaurants.webp',
    restaurantType: RestaurantType.restaurant,
  ),
  _Service(
    title: 'Factures',
    image: 'assets/services/factures.webp',
    isBills: true,
  ),
  _Service(
    title: 'Courses',
    image: 'assets/services/courses.webp',
    restaurantType: RestaurantType.grocery,
  ),
  _Service(title: 'Colis', image: 'assets/services/colis.webp', isParcel: true),
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

  /// "Que souhaitez-vous manger ?", above the restaurants; empty (and left
  /// out) until loaded, and when no restaurant has a category yet.
  List<RestaurantCategory> _categories = const [];

  /// The category the restaurants below are filtered by; null is "Tout".
  int? _categoryId;

  /// "Vos plus commandés": dishes from the customer's own recent orders,
  /// still on the menu today. Empty (and left out) for a new customer.
  List<FavouriteDish> _favourites = const [];

  /// "Les plus commandés" and "Restaurants populaires": counts of every
  /// customer's delivered orders, from the server; empty (and left out)
  /// until there are enough orders.
  PopularFeed _popular = PopularFeed.empty;

  /// What [_favourites] was worked out from, so the 20-second order check
  /// doesn't fetch the menus again when nothing changed.
  String? _favouritesKey;

  Timer? _activePoll;
  StreamSubscription<int>? _orderChanges;

  @override
  void initState() {
    super.initState();
    _promotionsFuture = context.read<PromotionsRepository>().listActive();
    _restaurantsFuture = context.read<CatalogueRepository>().listRestaurants();
    _loadAddress();
    _loadActiveOrders();
    _loadCategories();
    _loadPopular();
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

  /// The orders still on their way, for the banner, and the dishes the
  /// customer orders most. Checked again every 20 seconds while an order
  /// is on its way; a failure keeps what was shown.
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
      await _loadFavourites(result.items);
    } catch (_) {
      // Best effort: the banner is a shortcut, Commandes has the full list.
    }
    if (mounted && _activeOrders.isNotEmpty) {
      _activePoll = Timer(const Duration(seconds: 20), _loadActiveOrders);
    }
  }

  /// Counts the dishes in [orders] and finds them on today's menus (those
  /// of the three restaurants they come from most), for their photo and
  /// current price. A failure leaves the section as it was.
  Future<void> _loadFavourites(List<ClientOrder> orders) async {
    final ordered = countOrderedDishes(orders);
    final key = ordered
        .map((d) => '${d.restaurantId}:${d.productId}:${d.orderCount}')
        .join(',');
    if (key == _favouritesKey) return;
    _favouritesKey = key;

    if (ordered.isEmpty) {
      if (_favourites.isNotEmpty) setState(() => _favourites = const []);
      return;
    }

    final catalogue = context.read<CatalogueRepository>();
    try {
      final restaurants = {for (final r in await _restaurantsFuture) r.id: r};
      final restaurantIds = ordered
          .map((d) => d.restaurantId)
          .where(restaurants.containsKey)
          .toSet()
          .take(3);
      final menus = <int, List<Product>>{};
      await Future.wait([
        for (final id in restaurantIds)
          catalogue.listProducts(id).then((products) => menus[id] = products),
      ]);
      if (!mounted) return;
      setState(() {
        _favourites = favouriteDishes(
          ordered: ordered,
          restaurants: restaurants,
          menus: menus,
        );
      });
    } catch (_) {
      // Try again on the next check; the rest of the feed doesn't need it.
      _favouritesKey = null;
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

  /// A failure (or a server without it) only leaves both sections out.
  Future<void> _loadPopular({bool refresh = false}) async {
    try {
      final popular = await context.read<CatalogueRepository>().popular(
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() => _popular = popular);
    } catch (_) {
      // Best effort: the rest of the feed doesn't need it.
    }
  }

  /// A failure only leaves the category row out.
  Future<void> _loadCategories({bool refresh = false}) async {
    try {
      final categories = await context
          .read<CatalogueRepository>()
          .listRestaurantCategories(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        // A filter with no tile to undo it would hide restaurants for good.
        if (!categories.any((c) => c.id == _categoryId)) _categoryId = null;
      });
    } catch (_) {
      // Best effort: the restaurants are all still one tap away.
    }
  }

  /// Pulled down: everything asked again, past the kept answers (TtlCache).
  Future<void> _refresh() async {
    final promotions = context.read<PromotionsRepository>().listActive(
      refresh: true,
    );
    final restaurants = context.read<CatalogueRepository>().listRestaurants(
      refresh: true,
    );
    setState(() {
      _promotionsFuture = promotions;
      _restaurantsFuture = restaurants;
    });
    // Menus may have changed too: look the favourite dishes up again.
    _favouritesKey = null;
    await Future.wait([
      promotions,
      restaurants,
      _loadAddress(),
      _loadActiveOrders(),
      _loadCategories(refresh: true),
      _loadPopular(refresh: true),
    ]);
  }

  /// The full restaurant list, on the category picked here if any.
  void _openRestaurants() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Restaurants')),
          body: RestaurantsScreen(initialCategoryId: _categoryId),
        ),
      ),
    );
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

  void _openDish(FavouriteDish dish) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: dish.product,
          restaurantName: dish.restaurant.name,
        ),
      ),
    );
  }

  /// "Les plus commandés" (dishes not already in "Vos plus commandés") and
  /// "Restaurants populaires", each left out when empty.
  List<Widget> _popularSections() {
    final mine = {for (final f in _favourites) f.product.id};
    final dishes = [
      for (final (product, restaurant, count) in _popular.dishes)
        if (!mine.contains(product.id))
          FavouriteDish(
            product: product,
            restaurant: restaurant,
            orderCount: count,
          ),
    ];
    final days = _popular.windowDays;
    final now = DateTime.now();

    return [
      if (dishes.isNotEmpty) ...[
        HomeSectionHeader(
          title: 'Les plus commandés',
          subtitle: 'Sur Delivery Hassen, ces $days derniers jours',
        ),
        HorizontalCards(
          height: FavouriteDishCard.height,
          itemCount: dishes.length,
          itemBuilder: (context, index) {
            final dish = dishes[index];
            return FavouriteDishCard(
              dish: dish,
              badge: '${dish.orderCount} commandes',
              badgeIcon: Icons.local_fire_department,
              onTap: () => _openDish(dish),
            );
          },
        ),
      ],
      if (_popular.restaurants.isNotEmpty) ...[
        HomeSectionHeader(
          title: 'Restaurants populaires',
          subtitle: 'Les plus commandés ces $days derniers jours',
        ),
        HorizontalCards(
          height: NewRestaurantCard.height,
          itemCount: _popular.restaurants.length,
          itemBuilder: (context, index) {
            final (restaurant, count) = _popular.restaurants[index];
            return NewRestaurantCard(
              restaurant: restaurant,
              now: now,
              badge: 'POPULAIRE',
              badgeIcon: Icons.local_fire_department,
              caption: '$count commandes',
              onTap: () => _openRestaurant(restaurant),
            );
          },
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Built lazily: what's below the fold, its photos included, waits until
    // scrolled near, so the first screen's photos load first. Each section,
    // once built, is kept (_KeptSection): a plain lazy list dropped those
    // scrolled out of sight and rebuilt them on the way back, each one
    // flashing its loading state and reloading its photos.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          for (final section in <Widget>[
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
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
            const SizedBox(height: 20),
            _ServicesGrid(onTap: _openService),
            // Below the services, not above: the services are how the app is
            // used, and the offers would otherwise push them below the fold
            // on small phones.
            _PromotionsSection(future: _promotionsFuture, onRetry: _refresh),
            if (_favourites.isNotEmpty) ...[
              const HomeSectionHeader(
                title: 'Vos plus commandés',
                subtitle: 'D’après vos dernières commandes',
              ),
              HorizontalCards(
                height: FavouriteDishCard.height,
                itemCount: _favourites.length,
                itemBuilder: (context, index) {
                  final dish = _favourites[index];
                  return FavouriteDishCard(
                    dish: dish,
                    onTap: () => _openDish(dish),
                  );
                },
              ),
            ],
            ..._popularSections(),
            // Right above the restaurants it filters.
            if (_categories.isNotEmpty) ...[
              const HomeSectionHeader(title: 'Que souhaitez-vous manger ?'),
              CategorySelector(
                categories: _categories,
                selectedId: _categoryId,
                onSelected: (id) => setState(() => _categoryId = id),
              ),
            ],
            HomeSectionHeader(
              title: 'Restaurants',
              subtitle: 'Les restaurants ouverts en premier',
              onSeeAll: _openRestaurants,
            ),
            _RestaurantsPreview(
              future: _restaurantsFuture,
              categoryId: _categoryId,
              onTapRestaurant: _openRestaurant,
            ),
            _NewArrivals(
              future: _restaurantsFuture,
              onTapRestaurant: _openRestaurant,
            ),
          ])
            _KeptSection(child: section),
        ],
      ),
    );
  }
}

/// A home section kept alive once built, though scrolled out of sight.
class _KeptSection extends StatefulWidget {
  const _KeptSection({required this.child});

  final Widget child;

  @override
  State<_KeptSection> createState() => _KeptSectionState();
}

class _KeptSectionState extends State<_KeptSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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

/// The four services, two by two: a big illustration on a light tile, the
/// name under it.
class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.onTap});

  final void Function(_Service) onTap;

  @override
  Widget build(BuildContext context) {
    Widget row(int first) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ServiceTile(
            service: _services[first],
            onTap: () => onTap(_services[first]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ServiceTile(
            service: _services[first + 1],
            onTap: () => onTap(_services[first + 1]),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [row(0), const SizedBox(height: 14), row(2)]),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final _Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: service.title,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.4,
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1E1E1E) : serviceTile,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  service.image,
                  fit: BoxFit.contain,
                  // Decoded at the size it's shown, not the file's.
                  cacheWidth: 360,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// The restaurants under the category row: open ones first, a few at
/// most ("Voir tout" has the full list).
class _RestaurantsPreview extends StatelessWidget {
  const _RestaurantsPreview({
    required this.future,
    required this.onTapRestaurant,
    this.categoryId,
  });

  final Future<List<Restaurant>> future;

  /// Only the restaurants with this category; null shows them all.
  final int? categoryId;
  final void Function(Restaurant) onTapRestaurant;

  static const int _shown = 4;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                HomeSkeleton(height: 210),
                SizedBox(height: 16),
                HomeSkeleton(height: 210),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text('Impossible de charger les restaurants.'),
          );
        }

        final categoryId = this.categoryId;
        final restaurants = openFirst(
          (snapshot.data ?? const <Restaurant>[]).where(
            (r) => categoryId == null || r.hasCategory(categoryId),
          ),
        ).take(_shown).toList();

        if (restaurants.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              categoryId == null
                  ? 'Aucun restaurant disponible pour le moment.'
                  : 'Aucun restaurant dans cette catégorie pour le moment.',
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final restaurant in restaurants)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RestaurantFeatureCard(
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

/// "Nouveautés": the restaurants added in the last 30 days, newest first;
/// left out when there are none.
class _NewArrivals extends StatelessWidget {
  const _NewArrivals({required this.future, required this.onTapRestaurant});

  final Future<List<Restaurant>> future;
  final void Function(Restaurant) onTapRestaurant;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: future,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final recent = newRestaurants(
          snapshot.data ?? const <Restaurant>[],
          now: now,
        );
        if (recent.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeSectionHeader(
              title: 'Nouveautés',
              subtitle: 'Les derniers arrivés sur Delivery Hassen',
            ),
            HorizontalCards(
              height: NewRestaurantCard.height,
              itemCount: recent.length,
              itemBuilder: (context, index) {
                final restaurant = recent[index];
                return NewRestaurantCard(
                  restaurant: restaurant,
                  now: now,
                  onTap: () => onTapRestaurant(restaurant),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// "Promotions" (discounts, as wide banners that slide on their own) and
/// "Combos & bons plans" (fixed-price offers to order straight away). Each
/// is left out when there's nothing in it: no placeholder, no made-up offer.
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
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: HomeSkeleton(height: PromotionBanner.height, radius: 22),
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

        final promotions = snapshot.data ?? const <Promotion>[];
        final offers = promotions.where((p) => p.isOffer).toList();
        final discounts = promotions.where((p) => !p.isOffer).toList();
        if (offers.isEmpty && discounts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Wide enough to read, narrow enough that the next one peeks in.
        final bannerWidth = MediaQuery.sizeOf(context).width - 56;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (discounts.isNotEmpty) ...[
              const HomeSectionHeader(
                title: 'Promotions',
                subtitle: 'Les réductions du moment',
              ),
              AutoCarousel(
                itemCount: discounts.length,
                itemWidth: bannerWidth,
                height: PromotionBanner.height,
                itemBuilder: (context, index) => PromotionBanner(
                  promotion: discounts[index],
                  width: bannerWidth,
                ),
              ),
            ],
            if (offers.isNotEmpty) ...[
              const HomeSectionHeader(
                title: 'Combos & bons plans',
                subtitle: 'Des menus à prix fixe, prêts à commander',
              ),
              HorizontalCards(
                height: ComboCard.height,
                itemCount: offers.length,
                itemBuilder: (context, index) =>
                    ComboCard(offer: offers[index]),
              ),
            ],
          ],
        );
      },
    );
  }
}
