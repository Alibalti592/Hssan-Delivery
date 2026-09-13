import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalogue/catalogue_models.dart';
import '../config.dart';
import '../catalogue/catalogue_repository.dart';
import '../theme.dart';
import 'restaurant_menu_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  late Future<List<Restaurant>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
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
    return context.read<CatalogueRepository>().listRestaurants();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  bool _matches(Restaurant restaurant) {
    if (_query.isEmpty) return true;
    return restaurant.name.toLowerCase().contains(_query) ||
        (restaurant.description?.toLowerCase().contains(_query) ?? false);
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
              hintText: 'Rechercher un restaurant',
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
                        'Impossible de charger les restaurants',
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
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'Aucun restaurant disponible pour le moment.',
                        ),
                      ),
                    ],
                  );
                }

                if (restaurants.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Text(
                          'Aucun restaurant ne correspond à votre recherche.',
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: restaurants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
              child: restaurant.photoUrl != null
                  ? Image.network(
                      AppConfig.resolvePhotoUrl(restaurant.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
