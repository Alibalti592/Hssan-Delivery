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

    // Decode at the size shown, not the full upload: lighter on memory.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return CachedNetworkImage(
      imageUrl: AppConfig.resolvePhotoUrl(path),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: width?.isFinite == true ? (width! * ratio).round() : null,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => _placeholder(),
    );
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
