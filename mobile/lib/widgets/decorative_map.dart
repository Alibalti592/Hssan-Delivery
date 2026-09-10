import 'package:flutter/material.dart';

import '../theme.dart';

/// A stylized, non-interactive map illustration matching the design mockup
/// (flat background, a couple of "road" bars, and pin markers connected by a
/// dashed route). There's no real geolocation data behind it — restaurants,
/// delivery zones and addresses don't carry lat/lng in this app — so this is
/// purely decorative, the same way a missing photo falls back to a plain
/// icon tile elsewhere in the app.
class DecorativeMap extends StatelessWidget {
  const DecorativeMap({this.height = 150, this.twoPins = true, super.key});

  final double height;
  final bool twoPins;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _MapPainter(withRoute: twoPins)),
          if (twoPins) ...[
            const Align(
              alignment: Alignment(-0.55, -0.25),
              child: Icon(Icons.location_on, color: navy, size: 26),
            ),
            const Align(
              alignment: Alignment(0.4, 0.3),
              child: Icon(Icons.location_on, color: successText, size: 26),
            ),
          ] else
            const Align(
              alignment: Alignment(0, -0.1),
              child: Icon(Icons.location_on, color: navy, size: 30),
            ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.withRoute});

  final bool withRoute;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFDDE4EC),
    );

    final road = Paint()..color = const Color(0xFFEEF2F7);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.33, size.width, size.height * 0.07),
      road,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.58, 0, size.width * 0.035, size.height),
      road,
    );

    if (withRoute) {
      final routePaint = Paint()
        ..color = navy.withValues(alpha: 0.5)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      _drawDashedLine(
        canvas,
        Offset(size.width * 0.2, size.height * 0.43),
        Offset(size.width * 0.64, size.height * 0.58),
        routePaint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final direction = (b - a) / total;
    var distance = 0.0;
    while (distance < total) {
      final start = a + direction * distance;
      final end = a + direction * (distance + dashWidth).clamp(0, total);
      canvas.drawLine(start, end, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.withRoute != withRoute;
}
