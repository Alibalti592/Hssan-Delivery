import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown while [AuthController] restores a session on app start. Purely a
/// branded loading state — there is nothing to interact with here.
///
/// It takes over from the native launch screen, which shows the same
/// [SplashMonogram.image] at the same size in the center of the screen, so
/// the hand-off doesn't move the logo: only the name, tagline and spinner
/// fade in underneath it.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Equal flex above and below keeps the monogram dead center whatever
    // the screen height; the details hang off its bottom edge.
    return Scaffold(
      backgroundColor: navy,
      body: SizedBox.expand(
        child: Column(
          children: [
            const Spacer(),
            const SplashMonogram(),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 350),
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: const Column(
                  children: [
                    SizedBox(height: 18),
                    Text(
                      'Delivery Hassen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Aussi rapide que votre pensée',
                      style: TextStyle(color: Color(0xFF9AA5B6), fontSize: 13),
                    ),
                    SizedBox(height: 40),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF6B7787)),
                      ),
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

/// The chrome "DH" script monogram, drawn from the very image the native
/// launch screen uses (see flutter_native_splash in pubspec.yaml).
///
/// That image is a 1152x1152 transparent square with the glyph centered.
/// flutter_native_splash treats it as 4x, and Android 12+ shows its splash
/// icon in a [imageSize] box, so drawing it here in the same box at the
/// center of the screen lines the two up exactly. The widget only claims the
/// glyph's own height, so the text below sits under the glyph rather than
/// under the square's transparent padding.
class SplashMonogram extends StatelessWidget {
  const SplashMonogram({super.key});

  static const image = AssetImage('assets/icon/splash_logo.png');
  static const double imageSize = 288;
  static const double glyphHeight = 71.5;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: imageSize,
      height: glyphHeight,
      child: OverflowBox(
        maxWidth: imageSize,
        maxHeight: imageSize,
        child: Image(image: image, width: imageSize, height: imageSize),
      ),
    );
  }
}
