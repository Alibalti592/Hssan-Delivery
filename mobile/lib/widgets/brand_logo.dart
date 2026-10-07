import 'package:flutter/material.dart';

import 'brand_monogram.dart';

export 'brand_monogram.dart';

/// The Delivery Hassen logo, as the client's artwork: the chrome script
/// "DH", "Delivery Hassen" as wide as it, and "As Fast as you think" under
/// it.
///
/// The launcher icon and the native launch image are renders of
/// [BrandMonogram] (see tool/render_brand_assets.dart), so the logo looks
/// the same from the home screen icon to the app itself.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.width = 150, this.showTagline = true, super.key});

  /// Width of the "DH", which the name matches; the rest scales with it.
  final double width;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMonogram(width: width),
        SizedBox(height: 0.12 * width),
        // Poppins SemiBold sets "Delivery Hassen" 8.1 ems wide.
        BrandName(fontSize: width / 8.1),
        if (showTagline) ...[
          SizedBox(height: 0.01 * width),
          // Three fifths of the name's width, as on the artwork.
          BrandTagline(fontSize: width / 16.5),
        ],
      ],
    );
  }
}

class BrandName extends StatelessWidget {
  const BrandName({
    this.fontSize = 18.5,
    this.color = const Color(0xFFDCDCDC),
    super.key,
  });

  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Delivery Hassen',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        color: color,
        height: 1.2,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class BrandTagline extends StatelessWidget {
  const BrandTagline({this.fontSize = 9, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'As Fast as you think',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        color: const Color(0xFFE8E8E8),
        height: 1.2,
        decoration: TextDecoration.none,
      ),
    );
  }
}

/// The artwork's backdrop: near-black with a soft grey glow behind the
/// logo, so the silver reads.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({
    required this.child,
    this.center = const Alignment(0, -0.35),
    super.key,
  });

  final Widget child;

  /// Where the glow sits (usually behind the logo).
  final Alignment center;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 1.1,
          colors: const [
            Color(0xFF2B2B2D),
            Color(0xFF141415),
            Color(0xFF070707),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
