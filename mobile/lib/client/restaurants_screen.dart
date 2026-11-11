import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/category_widgets.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import 'restaurant_menu_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({
    this.type = RestaurantType.restaurant,
    this.initialCategoryId,
    super.key,
  });

  /// Which vertical to browse — restaurants or grocery stores (see mobile
  /// HomeScreen's "Restaurants"/"Courses" services). Both reuse this same
  /// screen; only the copy and the backend filter differ.
  final RestaurantType type;

  /// The restaurant category to open on (the one picked on the home
  /// screen); the client can change it or go back to "Tout".
  final int? initialCategoryId;

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  late Future<List<Restaurant>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  /// The categories to filter by; empty until loaded, and when there are
  /// none (the row is then left out).
  List<RestaurantCategory> _categories = const [];
  int? _categoryId;

  bool get _isGrocery => widget.type == RestaurantType.grocery;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _future = _load();
    _loadCategories();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Restaurant>> _load() {
    return context.read<CatalogueRepository>().listRestaurants(
      type: widget.type,
    );
  }

  /// Best effort: without the categories the list simply isn't filtered.
  Future<void> _loadCategories() async {
    List<RestaurantCategory> categories = const [];
    try {
      categories = await context
          .read<CatalogueRepository>()
          .listRestaurantCategories(type: widget.type);
    } catch (_) {
      // Offline, or a server older than this app: no category row.
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      // A filter with no tile to undo it would trap the client.
      if (!categories.any((c) => c.id == _categoryId)) _categoryId = null;
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await Future.wait([future, _loadCategories()]);
  }

  /// The search and the category work together: a restaurant shows when it
  /// has the selected category (if any) and matches what was typed (if
  /// anything) — by its name, its description or one of its categories.
  bool _matches(Restaurant restaurant) {
    final categoryId = _categoryId;
    if (categoryId != null && !restaurant.hasCategory(categoryId)) {
      return false;
    }
    if (_query.isEmpty) return true;
    return restaurant.name.toLowerCase().contains(_query) ||
        (restaurant.description?.toLowerCase().contains(_query) ?? false) ||
        restaurant.categories.any((c) => c.name.toLowerCase().contains(_query));
  }

  String _nothingMatches() {
    if (_query.isNotEmpty) {
      return _isGrocery
          ? 'Aucun magasin ne correspond à votre recherche.'
          : 'Aucun restaurant ne correspond à votre recherche.';
    }
    return _isGrocery
        ? 'Aucun magasin dans cette catégorie pour le moment.'
        : 'Aucun restaurant dans cette catégorie pour le moment.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: _isGrocery
                  ? 'Rechercher un magasin'
                  : 'Rechercher un restaurant',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _searchController.clear,
                    ),
            ),
          ),
        ),
        if (_categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CategorySelector(
              categories: _categories,
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Restaurant>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ListView(
                    children: [
                      const SizedBox(height: 100),
                      Icon(
                        Icons.wifi_off,
                        size: 56,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isGrocery
                            ? 'Impossible de charger les magasins'
                            : 'Impossible de charger les restaurants',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Réessayer'),
                        ),
                      ),
                    ],
                  );
                }

                final all = snapshot.data ?? const [];
                final restaurants = all.where(_matches).toList();

                if (all.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Text(
                          _isGrocery
                              ? 'Aucun magasin disponible pour le moment.'
                              : 'Aucun restaurant disponible pour le moment.',
                        ),
                      ),
                    ],
                  );
                }

                if (restaurants.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(child: Text(_nothingMatches())),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: restaurants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final restaurant = restaurants[index];
                    return _RestaurantCard(
                      restaurant: restaurant,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RestaurantMenuScreen(restaurant: restaurant),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant, required this.onTap});

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
                icon: restaurant.type == RestaurantType.grocery
                    ? Icons.shopping_basket_outlined
                    : Icons.storefront_outlined,
                iconSize: 40,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: successBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Ouvert',
                          style: TextStyle(
                            color: successText,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (restaurant.categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    CategoryLabels(restaurant.categories),
                  ],
                  if (restaurant.description != null &&
                      restaurant.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
