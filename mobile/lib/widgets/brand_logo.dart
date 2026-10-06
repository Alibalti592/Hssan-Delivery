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

  static const silver = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFE4E7EB),
      Color(0xFF9AA0A8),
      Color(0xFFF4F5F7),
      Color(0xFFB9BEC5),
    ],
    stops: [0, 0.32, 0.55, 0.78, 1],
  );

  @override
  Widget build(BuildContext context) {
    TextStyle style([Paint? foreground]) => TextStyle(
      fontFamily: 'AlexBrush',
      fontSize: size,
      height: 1.05,
      color: foreground == null ? Colors.white : null,
      foreground: foreground,
      // Pinned rather than inherited, so the renders made without a theme
      // place the glyphs exactly like the app does.
      leadingDistribution: TextLeadingDistribution.even,
      decoration: TextDecoration.none,
    );

    // Brush strokes are thin at small sizes: a stroke of the same silver
    // around the fill gives the weight of the artwork.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.022
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    // The script's H flourish reaches well past the text box on the right:
    // shift the letters so what you see is centred, not the box.
    return Transform.translate(
      offset: Offset(-0.16 * size, 0.08 * size),
      child: _letters(style, outline),
    );
  }

  Widget _letters(TextStyle Function([Paint?]) style, Paint outline) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft shadow under the letters, as on the artwork.
        Transform.translate(
          offset: Offset(0, size * 0.04),
          child: Text(
            'DH',
            softWrap: false,
            style: style().copyWith(
              color: Colors.black.withValues(alpha: 0.55),
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: size * 0.08,
                ),
              ],
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: silver.createShader,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('DH', softWrap: false, style: style(outline)),
              Text('DH', softWrap: false, style: style()),
            ],
          ),
        ),
      ],
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
