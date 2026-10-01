import '../catalogue/catalogue_models.dart';
import '../catalogue/catalogue_repository.dart';
import '../core/api_exception.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import '../widgets/empty_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'product_detail_screen.dart';
import 'restaurant_menu_screen.dart';

/// "Rechercher un plat, un restaurant": results as you type, dishes with
/// the place that sells them, one tap from adding to the cart.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _minLength = 2;

  final _controller = TextEditingController();
  Timer? _debounce;

  /// Only the answer to the latest query is shown, whatever order the
  /// responses come back in.
  int _generation = 0;
  String _query = '';
  SearchResults _results = SearchResults.empty;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < _minLength) {
      _generation++;
      setState(() {
        _query = query;
        _results = SearchResults.empty;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _query = query);
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<CatalogueRepository>().search(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(generation, e.message);
    } on NetworkException catch (e) {
      _fail(generation, e.message);
    }
  }

  void _fail(int generation, String message) {
    if (!mounted || generation != _generation) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _openRestaurant(Restaurant restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantMenuScreen(restaurant: restaurant),
      ),
    );
  }

  void _openDish(DishResult dish) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: dish.product,
          restaurantName: dish.restaurant.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (text) {
              if (text.trim().length >= _minLength) {
                _debounce?.cancel();
                _search(text.trim());
              }
            },
            decoration: InputDecoration(
              hintText: 'Rechercher un plat, un restaurant',
              isDense: true,
              filled: true,
              fillColor: fieldFill,
              prefixIcon: const Icon(Icons.search, color: mutedText),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loading
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_query.length < _minLength) {
      return const EmptyState(
        icon: Icons.restaurant_menu,
        title: 'Que voulez-vous commander ?',
        detail:
            'Un plat, un restaurant ou un magasin : tapez au moins 2 '
            'lettres.',
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'La recherche n\'a pas abouti',
        detail: _error,
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh,
        onAction: () => _search(_query),
      );
    }
    if (_results.isEmpty) {
      if (_loading) return const SizedBox.shrink();
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat pour « $_query »',
        detail: 'Essayez un autre mot, ou parcourez les restaurants.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_results.restaurants.isNotEmpty) ...[
          const _SectionTitle('Restaurants et magasins'),
          for (final restaurant in _results.restaurants)
            _RestaurantTile(
              restaurant: restaurant,
              onTap: () => _openRestaurant(restaurant),
            ),
        ],
        if (_results.dishes.isNotEmpty) ...[
          const _SectionTitle('Plats et produits'),
          for (final dish in _results.dishes)
            _DishTile(dish: dish, onTap: () => _openDish(dish)),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: mutedText,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({required this.restaurant, required this.onTap});

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGrocery = restaurant.type == RestaurantType.grocery;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppPhoto(
          restaurant.photoUrl,
          icon: isGrocery
              ? Icons.shopping_basket_outlined
              : Icons.storefront_outlined,
          width: 52,
          height: 52,
        ),
      ),
      title: Text(
        restaurant.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(isGrocery ? 'Magasin' : 'Restaurant'),
      trailing: const Icon(Icons.chevron_right, color: mutedText),
    );
  }
}

class _DishTile extends StatelessWidget {
  const _DishTile({required this.dish, required this.onTap});

  final DishResult dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = dish.product;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppPhoto(
                product.photoUrl,
                icon: Icons.restaurant_outlined,
                width: 64,
                height: 64,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: mutedText,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          dish.restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.hasOptions
                        ? 'À partir de ${product.price} DT'
                        : '${product.price} DT',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
