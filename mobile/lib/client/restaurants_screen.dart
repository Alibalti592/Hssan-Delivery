import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import 'restaurant_menu_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  late Future<List<Restaurant>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Restaurant>> _load() {
    return context.read<CatalogueRepository>().listRestaurants();
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

          final restaurants = snapshot.data ?? const [];
          if (restaurants.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 100),
                Center(child: Text('Aucun restaurant disponible pour le moment.')),
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
                    builder: (_) => RestaurantMenuScreen(restaurant: restaurant),
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
                  ? Image.network(restaurant.photoUrl!, fit: BoxFit.cover)
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
                  Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
