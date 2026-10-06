import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The Delivery Hassen logo, as the client's artwork: a brushed-silver
/// script "DH", "Delivery Hassen" and "As Fast as you think" under it.
///
/// The launcher icon and the native launch image are renders of
/// [BrandMonogram] (see tool/render_brand_assets.dart), so the logo looks
/// the same from the home screen icon to the app itself.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.monogramSize = 84, this.showTagline = true, super.key});

  /// Height of the "DH" glyphs; the name and tagline scale with it.
  final double monogramSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final scale = monogramSize / 84;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMonogram(size: monogramSize),
        SizedBox(height: 6 * scale),
        BrandName(fontSize: 21 * scale),
        if (showTagline) ...[
          SizedBox(height: 3 * scale),
          BrandTagline(fontSize: 11.5 * scale),
        ],
      ],
    );
  }
}

/// The script "DH" in brushed silver: light at the top, a darker band
/// across the middle, bright again at the bottom, like the artwork.
class BrandMonogram extends StatelessWidget {
  const BrandMonogram({this.size = 84, super.key});

  final double size;

  /// Polished chrome, lit from above like the artwork: bright on top,
  /// cooler grey towards the bottom, with a faint reflection at the base.
  static const silver = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF3F5F7),
      Color(0xFFCDD2D8),
      Color(0xFF9AA1A9),
      Color(0xFFC9CED4),
    ],
    stops: [0, 0.34, 0.58, 0.82, 1],
  );

  @override
  Widget build(BuildContext context) {
    TextStyle style({Paint? foreground, Color? color}) => TextStyle(
      fontFamily: 'AlexBrush',
      fontSize: size,
      height: 1.05,
      // Tucks the H against the D, as on the artwork.
      letterSpacing: -0.07 * size,
      color: foreground == null ? (color ?? Colors.white) : null,
      foreground: foreground,
      // Pinned rather than inherited, so the renders made without a theme
      // place the glyphs exactly like the app does.
      leadingDistribution: TextLeadingDistribution.even,
      decoration: TextDecoration.none,
    );

    // The brush font is thin: a stroke around the letters gives them the
    // weight of the artwork, and never less than a pixel and a bit, so the
    // small app-icon tile stays legible.
    final weight = math.max(size * 0.04, 1.3);
    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;

    Widget word({Paint? foreground, Color? color}) => Text(
      'DH',
      softWrap: false,
      style: style(foreground: foreground, color: color),
    );

    // The script's H flourish reaches well past the text box on the right:
    // shift the letters so what you see is centred, not the box.
    return Transform.translate(
      offset: Offset(-0.12 * size, 0.08 * size),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Drop shadow, below and slightly right, as on the artwork.
          Transform.translate(
            offset: Offset(size * 0.025, size * 0.07),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: size * 0.035,
                sigmaY: size * 0.035,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  word(
                    foreground: stroke(
                      weight,
                      Colors.black.withValues(alpha: 0.75),
                    ),
                  ),
                  word(color: Colors.black.withValues(alpha: 0.75)),
                ],
              ),
            ),
          ),
          // A darker rim that gives the chrome an edge.
          word(
            foreground: stroke(
              weight + math.max(size * 0.018, 0.8),
              const Color(0xFF4B5058),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: silver.createShader,
            child: Stack(
              alignment: Alignment.center,
              children: [
                word(foreground: stroke(weight, Colors.white)),
                word(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BrandName extends StatelessWidget {
  const BrandName({this.fontSize = 21, this.color = Colors.white, super.key});

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
        letterSpacing: 0.2,
        height: 1.2,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class BrandTagline extends StatelessWidget {
  const BrandTagline({this.fontSize = 11.5, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'As Fast as you think',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
        fontSize: fontSize,
        color: const Color(0xFFB4BAC2),
        letterSpacing: 0.3,
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
