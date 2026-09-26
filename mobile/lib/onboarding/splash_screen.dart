import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown while [AuthController] restores a session on app start. Purely a
/// branded loading state — there is nothing to interact with here.
///
/// It takes over from the native launch screen, whose image
/// (assets/icon/splash_logo.png) is [SplashMonogram] rendered at 4x and
/// centered on screen. This screen keeps the monogram at the exact center
/// too, so the hand-off doesn't move it: only the name, tagline and spinner
/// fade in underneath.
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
                    SizedBox(height: 14),
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

/// The plain italic "DH" brand monogram. The native launch image and the
/// launcher icon are renders of this widget, so keep them in sync (see the
/// flutter_launcher_icons / flutter_native_splash notes in pubspec.yaml).
class SplashMonogram extends StatelessWidget {
  const SplashMonogram({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'DH',
      style: TextStyle(
        fontFamily: 'Roboto',
        color: Color(0xFFE8ECF2),
        fontSize: 56,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -2,
        height: 1,
        // Pinned rather than inherited: the Material theme sets `even`, the
        // icon/launch-image renders have no theme, and the two place the
        // glyphs differently inside the line box.
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}
