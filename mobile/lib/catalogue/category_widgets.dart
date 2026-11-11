import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_photo.dart';
import 'catalogue_models.dart';

/// The icon drawn for a restaurant category without an image of its own.
/// The keys mirror the backend's RestaurantCategory::ICONS; an unknown one
/// (a newer server) falls back to the fork and knife.
IconData categoryIconData(String key) => switch (key) {
  'fast_food' => Icons.fastfood_outlined,
  'burger' => Icons.lunch_dining_outlined,
  'pizza' => Icons.local_pizza_outlined,
  'kebab' => Icons.kebab_dining_outlined,
  'grill' => Icons.outdoor_grill_outlined,
  'bowl' => Icons.rice_bowl_outlined,
  'soup' => Icons.soup_kitchen_outlined,
  'pasta' => Icons.ramen_dining_outlined,
  'fish' => Icons.set_meal_outlined,
  'tapas' => Icons.tapas_outlined,
  'croissant' => Icons.bakery_dining_outlined,
  'breakfast' => Icons.breakfast_dining_outlined,
  'leaf' => Icons.eco_outlined,
  'cake' => Icons.cake_outlined,
  'ice_cream' => Icons.icecream_outlined,
  'coffee' => Icons.local_cafe_outlined,
  'drink' => Icons.local_drink_outlined,
  'basket' => Icons.shopping_basket_outlined,
  _ => Icons.restaurant_outlined,
};

/// The row of restaurant categories under a search bar: a round tile and a
/// name each, scrolling sideways.
///
/// With [showAll], a "Tout" tile comes first and the row is a filter: the
/// tile of [selectedId] (or "Tout" when null) is highlighted, and [onSelected]
/// gets the tapped category's id, or null for "Tout" and for a second tap on
/// the selected one. Without it, the tiles are plain shortcuts.
class CategorySelector extends StatefulWidget {
  const CategorySelector({
    required this.categories,
    required this.onSelected,
    this.selectedId,
    this.showAll = true,
    super.key,
  });

  final List<RestaurantCategory> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final bool showAll;

  static const double _tileWidth = 76;
  static const double _gap = 4;
  static const double _padding = 12;

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Opened on a category further right than the screen is wide (from the
    // home screen's row): bring its tile into view, moving as little as
    // possible so "Tout" stays in sight when it can.
    final index = widget.categories.indexWhere(
      (c) => c.id == widget.selectedId,
    );
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      const extent = CategorySelector._tileWidth + CategorySelector._gap;
      final position = _scroll.position;
      final tileEnd =
          CategorySelector._padding +
          (index + (widget.showAll ? 1 : 0)) * extent +
          CategorySelector._tileWidth;
      final overflow =
          tileEnd + CategorySelector._padding - position.viewportDimension;
      if (overflow > 0) {
        _scroll.jumpTo(overflow.clamp(0, position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final leading = widget.showAll ? 1 : 0;

    return SizedBox(
      // Room for a name on two lines ("Cuisine Tunisienne").
      height: 100,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CategorySelector._padding,
        ),
        itemCount: categories.length + leading,
        separatorBuilder: (_, _) =>
            const SizedBox(width: CategorySelector._gap),
        itemBuilder: (context, index) {
          if (index < leading) {
            return _CategoryTile(
              name: 'Tout',
              icon: Icons.grid_view_rounded,
              selected: widget.selectedId == null,
              onTap: () => widget.onSelected(null),
            );
          }
          final category = categories[index - leading];
          final selected = widget.showAll && category.id == widget.selectedId;
          return _CategoryTile(
            name: category.name,
            icon: categoryIconData(category.icon),
            imageUrl: category.imageUrl,
            selected: selected,
            onTap: () => widget.onSelected(selected ? null : category.id),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  final String name;
  final IconData icon;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: CategorySelector._tileWidth,
          child: Column(
            children: [
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: _size,
                height: _size,
                // The ring around a selected image; an icon tile fills instead.
                padding: EdgeInsets.all(hasImage && selected ? 2.5 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : fieldFillOf(context),
                ),
                child: hasImage
                    ? ClipOval(
                        child: AppPhoto(
                          imageUrl,
                          icon: icon,
                          width: _size,
                          height: _size,
                        ),
                      )
                    : Icon(
                        icon,
                        size: 24,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : accent,
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? accent : mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a restaurant serves, as small pills on its card: the first [max]
/// of its categories, then "+N" for the rest. Nothing when it has none.
class CategoryLabels extends StatelessWidget {
  const CategoryLabels(this.categories, {this.max = 3, super.key});

  final List<RestaurantCategory> categories;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final shown = categories.take(max).toList();
    final more = categories.length - shown.length;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final category in shown) _pill(context, category.name),
        if (more > 0) _pill(context, '+$more'),
      ],
    );
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fieldFillOf(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A5261),
        ),
      ),
    );
  }
}
