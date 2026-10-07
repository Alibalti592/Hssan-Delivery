// Renders the launcher icon and native launch images from BrandMonogram, so
// they are the logo pixel for pixel. Run it after changing the logo, then
// regenerate the platform files:
//
//   flutter test tool/render_brand_assets.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/onboarding/splash_screen.dart';
import 'package:mobile/widgets/brand_logo.dart';

Future<void> _render(
  WidgetTester tester, {
  required String path,
  required double canvas,
  required Widget child,
  double pixelRatio = 1,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.square(dimension: canvas, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render brand assets', (tester) async {
    tester.view.physicalSize = const Size(4000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Launcher icon: the monogram on the logo's backdrop.
    await _render(
      tester,
      path: 'assets/icon/app_icon.png',
      canvas: 1024,
      child: const BrandBackdrop(
        center: Alignment.center,
        child: Center(child: BrandMonogram(width: 760)),
      ),
    );

    // Android adaptive icon foreground: inside the central safe zone.
    await _render(
      tester,
      path: 'assets/icon/app_icon_foreground.png',
      canvas: 1024,
      child: const Center(child: BrandMonogram(width: 570)),
    );

    // Launch image: SplashScreen's monogram at 4x, centered in the 288dp
    // (1152px) square Android 12+ expects; 172 wide keeps it inside the
    // central 192dp circle that Android 12+ shows.
    await _render(
      tester,
      path: 'assets/icon/splash_logo.png',
      canvas: 288,
      pixelRatio: 4,
      child: const Center(child: BrandMonogram(width: splashMonogramWidth)),
    );
  });
}
