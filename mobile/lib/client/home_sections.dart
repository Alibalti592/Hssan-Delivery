import 'package:flutter/material.dart';

import '../catalogue/catalogue_models.dart';
import '../catalogue/category_widgets.dart';
import '../promotions/offer_screen.dart';
import '../promotions/promotion_model.dart';
import '../promotions/promotion_sheet.dart';
import '../theme.dart';
import '../widgets/app_photo.dart';
import 'home_feed.dart';

/// The building blocks of the home feed: section titles, the sideways
/// rows, and one card per kind of thing the feed shows.

/// A section's title, an optional line under it, and "Voir tout".
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    required this.title,
    this.subtitle,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, color: mutedText),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: navy,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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

/// A row of cards that scrolls sideways, aligned with the section titles.
class HorizontalCards extends StatelessWidget {
  const HorizontalCards({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        clipBehavior: Clip.none,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// A grey block where content is about to appear, the same size as it,
/// so the feed doesn't jump when it arrives.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({
    required this.height,
    this.width,
    this.radius = 20,
    super.key,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fieldFillOf(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A small label laid over a photo ("Ouvert", "Nouveau", "Commandé 3 fois").
class PhotoBadge extends StatelessWidget {
  const PhotoBadge(
    this.label, {
    this.background = Colors.white,
    this.foreground = navy,
    this.icon,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The frame every feed card shares: rounded, a hairline border, a soft
/// shadow and the ripple.
class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.child,
    required this.onTap,
    this.radius = 20,
  });

  final Widget child;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: cardBorderOf(context)),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

String _priceLabel(Product product) =>
    product.hasOptions ? 'Dès ${product.price} DT' : '${product.price} DT';

// ---------------------------------------------------------------------------
// Promotions

/// A discount ("-10 %", "-5 DT") as a wide banner; a tap shows its terms
/// and code.
class PromotionBanner extends StatelessWidget {
  const PromotionBanner({
    required this.promotion,
    required this.width,
    super.key,
  });

  final Promotion promotion;
  final double width;

  static const double height = 160;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = promotion.photoUrl?.isNotEmpty == true;
    final where = promotion.restaurantName ?? 'Sur tous les restaurants';

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF15171B),
        child: InkWell(
          onTap: () => showPromotionSheet(context, promotion),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto)
                AppPhoto(
                  promotion.photoUrl,
                  icon: Icons.local_offer_outlined,
                  iconSize: 36,
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF15171B), Color(0xFF34373F)],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment(1.15, 0.2),
                    child: Icon(
                      Icons.local_offer,
                      size: 150,
                      color: Color(0x14FFFFFF),
                    ),
                  ),
                ),
              // Dark on the left, where the words are, whatever the photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xE6000000), Color(0x33000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        promotion.discountLabel,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: width * 0.68,
                      child: Text(
                        promotion.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            where,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD5DAE1),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (promotion.hasCode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0x99FFFFFF),
                              ),
                            ),
                            child: Text(
                              'Code ${promotion.promoCode}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
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

// ---------------------------------------------------------------------------
// Combos & bons plans

/// A fixed-price offer ("2 sandwiches + frites — 11 DT"): its photo, what's
/// in it, its price, and a tap into [OfferScreen] to order it.
class ComboCard extends StatelessWidget {
  const ComboCard({required this.offer, super.key});

  final Promotion offer;

  static const double width = 210;
  static const double height = 262;

  @override
  Widget build(BuildContext context) {
    final contents = offer.items.isNotEmpty
        ? offer.items.join(' • ')
        : (offer.description ?? '');

    return SizedBox(
      width: width,
      height: height,
      child: _CardFrame(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => OfferScreen(offer: offer))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 136,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppPhoto(
                    offer.photoUrl,
                    icon: Icons.local_offer_outlined,
                    iconSize: 36,
                    alignment: Alignment.topCenter,
                  ),
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: PhotoBadge(
                      'COMBO',
                      background: warnBg,
                      foreground: warnText,
                      icon: Icons.bolt,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    if (contents.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        contents,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: mutedText,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.restaurantName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: navy,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            offer.discountLabel,
                            style: const TextStyle(
                              color: Colors.white,
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
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vos plus commandés

/// A dish the customer keeps coming back to, with how often (from their
/// own orders); a tap opens it, ready to add again.
class FavouriteDishCard extends StatelessWidget {
  const FavouriteDishCard({
    required this.dish,
    required this.onTap,
    this.badge,
    this.badgeIcon = Icons.replay,
    super.key,
  });

  final FavouriteDish dish;
  final VoidCallback onTap;

  /// The label on the photo; by default how often this customer ordered it.
  final String? badge;
  final IconData badgeIcon;

  static const double width = 160;
  static const double height = 232;

  @override
  Widget build(BuildContext context) {
    final count = dish.orderCount;
    return SizedBox(
      width: width,
      height: height,
      child: _CardFrame(
        radius: 18,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 118,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppPhoto(
                    dish.product.photoUrl,
                    icon: Icons.restaurant_outlined,
                    iconSize: 30,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: PhotoBadge(
                      badge ??
                          (count > 1
                              ? 'Commandé $count fois'
                              : 'Déjà commandé'),
                      icon: badgeIcon,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dish.restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: mutedText),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _priceLabel(dish.product),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: navy,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// Restaurants

/// The grey version of a closed restaurant's photo.
const _greyscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return open
        ? const PhotoBadge(
            'Ouvert',
            background: successBg,
            foreground: successText,
          )
        : const PhotoBadge(
            'Fermé',
            background: Color(0xE6202226),
            foreground: Colors.white,
          );
  }
}

/// A restaurant as a large card: its photo, open or closed, what it
/// serves and its description.
class RestaurantFeatureCard extends StatelessWidget {
  const RestaurantFeatureCard({
    required this.restaurant,
    required this.onTap,
    super.key,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = restaurant.isAvailable;
    final description = restaurant.description;

    Widget photo = AppPhoto(
      restaurant.photoUrl,
      icon: Icons.storefront_outlined,
      iconSize: 36,
    );
    if (!open) photo = ColorFiltered(colorFilter: _greyscale, child: photo);

    return _CardFrame(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2.1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                photo,
                Positioned(top: 12, right: 12, child: _OpenBadge(open: open)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (restaurant.categories.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        CategoryLabels(restaurant.categories),
                      ],
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
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
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: open ? navy : fieldFillOf(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: open ? Colors.white : mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nouveautés

/// A restaurant that just joined: its photo, "Nouveau", and since when.
class NewRestaurantCard extends StatelessWidget {
  const NewRestaurantCard({
    required this.restaurant,
    required this.now,
    required this.onTap,
    this.badge = 'NOUVEAU',
    this.badgeIcon = Icons.auto_awesome,
    this.caption,
    super.key,
  });

  final Restaurant restaurant;
  final DateTime now;
  final VoidCallback onTap;

  /// The label on the photo, and the line under the name instead of
  /// "Ajouté il y a…" ("Restaurants populaires" uses the same card).
  final String badge;
  final IconData badgeIcon;
  final String? caption;

  static const double width = 236;
  static const double height = 200;

  @override
  Widget build(BuildContext context) {
    final createdAt = restaurant.createdAt;
    final serves = restaurant.categories.map((c) => c.name).take(2).join(' · ');

    return SizedBox(
      width: width,
      height: height,
      child: _CardFrame(
        radius: 18,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 126,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppPhoto(
                    restaurant.photoUrl,
                    icon: Icons.storefront_outlined,
                    iconSize: 32,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: PhotoBadge(
                      badge,
                      background: navy,
                      foreground: Colors.white,
                      icon: badgeIcon,
                    ),
                  ),
                  if (!restaurant.isAvailable)
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: _OpenBadge(open: false),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (serves.isNotEmpty) serves,
                        if (caption case final caption?)
                          caption
                        else if (createdAt != null)
                          addedLabel(createdAt, now),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: mutedText),
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
