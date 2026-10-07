import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';

/// Shown while [AuthController] restores a session on app start. Purely a
/// branded loading state — there is nothing to interact with here.
///
/// It takes over from the native launch screen, whose image
/// (assets/icon/splash_logo.png) is [BrandMonogram] rendered at 4x and
/// centered on screen. This screen keeps the monogram at the exact center
/// too, so the hand-off doesn't move it: only the name, tagline and spinner
/// fade in underneath.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The native launch screen is flat black with the monogram centered:
    // the monogram stays exactly there, while the backdrop's glow, the name
    // and the tagline fade in around it.
    return Scaffold(
      backgroundColor: navy,
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (context, t, child) => Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: t,
              child: const BrandBackdrop(
                center: Alignment.center,
                child: SizedBox.expand(),
              ),
            ),
            child!,
          ],
        ),
        child: SizedBox.expand(
          child: Column(
            children: [
              const Spacer(),
              const BrandMonogram(width: splashMonogramWidth),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: const Column(
                    children: [
                      // The artwork's proportions, as in BrandLogo.
                      SizedBox(height: 0.12 * splashMonogramWidth),
                      BrandName(fontSize: splashMonogramWidth / 8.1),
                      SizedBox(height: 0.01 * splashMonogramWidth),
                      BrandTagline(fontSize: splashMonogramWidth / 16.5),
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
      ),
    );
  }
}

/// The launch image (assets/icon/splash_logo.png) is [BrandMonogram] at
/// this width, rendered at 4x by tool/render_brand_assets.dart: change both
/// together.
const double splashMonogramWidth = 172;
