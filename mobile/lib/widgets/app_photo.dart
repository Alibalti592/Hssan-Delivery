import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

/// A catalogue photo (restaurant, dish, offer) kept on the phone after the
/// first load, so menus open fast and work on a weak connection. While it
/// loads, or when there's no photo or it fails, a soft tile with [icon]
/// stands in, never a blank or broken box.
class AppPhoto extends StatelessWidget {
  const AppPhoto(
    this.path, {
    required this.icon,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.iconSize = 22,
    super.key,
  });

  /// The API's photoUrl ("/uploads/..."), or null when there's none.
  final String? path;
  final IconData icon;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    if (path == null || path.isEmpty) return _placeholder();

    // Decode at the size shown, never the full upload: a restaurant logo
    // can be several thousand pixels wide, and decoding a few of those at
    // full size makes the home feed stutter, then freeze the phone. Without
    // an explicit width, the space the parent gives is the size shown.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final shown = width?.isFinite == true ? width! : constraints.maxWidth;
        final pixels = decodeWidth(shown, ratio);
        Widget photo(String path, {Widget? onError}) => CachedNetworkImage(
          imageUrl: AppConfig.resolvePhotoUrl(path),
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          memCacheWidth: pixels,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, _) => _placeholder(),
          errorWidget: (_, _, _) => onError ?? _placeholder(),
        );

        // The server's smaller copy when one is wide enough (a menu photo
        // is a tenth of the original's weight); the original if it's
        // missing, e.g. for a photo the server hasn't made copies of yet.
        final smaller = variantPath(path, pixels);
        return smaller == null
            ? photo(path)
            : photo(smaller, onError: photo(path));
      },
    );
  }

  /// Widths of the copies the server keeps of each catalogue photo
  /// (backend PhotoVariants), next to it: "/uploads/products/w480/abc.webp"
  /// for "/uploads/products/abc.jpg".
  static const variantWidths = [480, 960];

  /// The path of the smallest copy of [path] good enough for [pixels], or
  /// null when only the original will do (no copies of it, or shown wider
  /// than the largest). A copy up to 15% narrower than the space passes:
  /// a full-width photo on most phones (about 1080 pixels) gets the
  /// 960-pixel copy, at a quarter of the original's weight.
  @visibleForTesting
  static String? variantPath(String path, int? pixels) {
    if (pixels == null) return null;
    final match = RegExp(
      r'^(.*/uploads/[^/]+)/([^/]+)\.(?:jpe?g|png|webp)$',
    ).firstMatch(path);
    if (match == null) return null;
    for (final width in variantWidths) {
      if (width * 1.15 >= pixels) return '${match[1]}/w$width/${match[2]}.webp';
    }
    return null;
  }

  /// The width, in pixels, to decode a photo shown [shown] logical pixels
  /// wide; null (full size) only when nothing bounds it.
  @visibleForTesting
  static int? decodeWidth(double shown, double devicePixelRatio) {
    if (!shown.isFinite || shown <= 0) return null;
    return (shown * devicePixelRatio).round();
  }

  Widget _placeholder() {
    // 200 only applies where nothing sizes it (the offer flyer while it
    // loads); everywhere else the parent's tight size wins.
    return Container(
      width: width,
      height: height ?? 200,
      color: fieldFill,
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: const Color(0xFF9FB0C4)),
    );
  }
}
