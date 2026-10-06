import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A pizza seen from above (or its golden underside, mid-flip): crust,
/// sauce, melted cheese, pepperoni, basil and the cut lines. Fills the
/// square it is given.
class PizzaPainter extends CustomPainter {
  const PizzaPainter({this.underside = false});

  /// The bottom of the pizza, shown while it is upside down in the air.
  final bool underside;

  static const _crust = Color(0xFFE9B46C);
  static const _crustEdge = Color(0xFFC88A3E);
  static const _sauce = Color(0xFFD8452C);
  static const _cheese = Color(0xFFF8D56E);
  static const _pepperoni = Color(0xFFB8322A);
  static const _basil = Color(0xFF3F8F45);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    if (underside) {
      _underside(canvas, c, r);
      return;
    }

    // Crust, with a toasted rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: const [_crust, _crust, _crustEdge],
          stops: const [0, 0.8, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(c, r * 0.84, Paint()..color = _sauce);

    // Melted cheese: a wavy blob that leaves a little sauce at the edge.
    final cheese = Path();
    for (var i = 0; i <= 72; i++) {
      final a = i / 72 * 2 * math.pi;
      final wobble = 1 + 0.035 * math.sin(a * 7) + 0.025 * math.cos(a * 11);
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.78 * wobble;
      i == 0 ? cheese.moveTo(p.dx, p.dy) : cheese.lineTo(p.dx, p.dy);
    }
    cheese.close();
    canvas.drawPath(cheese, Paint()..color = _cheese);

    // Cut lines: eight slices.
    final cut = Paint()
      ..color = const Color(0xFFD9A04F).withValues(alpha: 0.55)
      ..strokeWidth = r * 0.018;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final d = Offset(math.cos(a), math.sin(a)) * r * 0.8;
      canvas.drawLine(c - d, c + d, cut);
    }

    // Pepperoni.
    const spots = [
      Offset(-0.42, -0.30),
      Offset(0.10, -0.52),
      Offset(0.48, -0.18),
      Offset(-0.12, -0.05),
      Offset(0.32, 0.30),
      Offset(-0.46, 0.26),
      Offset(0.02, 0.50),
      Offset(0.55, 0.15),
    ];
    for (final s in spots) {
      final p = c + s * r;
      canvas.drawCircle(p, r * 0.12, Paint()..color = _pepperoni);
      canvas.drawCircle(
        p + Offset(-r * 0.03, -r * 0.03),
        r * 0.035,
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }

    // Basil leaves.
    const leaves = [
      (Offset(-0.20, -0.38), 0.6),
      (Offset(0.30, -0.02), -0.4),
      (Offset(-0.28, 0.48), 1.2),
    ];
    for (final (pos, angle) in leaves) {
      canvas.save();
      canvas.translate(c.dx + pos.dx * r, c.dy + pos.dy * r);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 0.2, height: r * 0.1),
        Paint()..color = _basil,
      );
      canvas.restore();
    }
  }

  void _underside(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFFE2A85E), Color(0xFFD99B4E), _crustEdge],
          stops: const [0, 0.75, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Oven marks.
    final mark = Paint()
      ..color = const Color(0xFF9C6428).withValues(alpha: 0.35);
    const marks = [
      Offset(-0.4, -0.2),
      Offset(0.2, -0.45),
      Offset(0.45, 0.25),
      Offset(-0.1, 0.4),
      Offset(0.05, -0.05),
      Offset(-0.5, 0.35),
    ];
    for (final m in marks) {
      canvas.drawCircle(c + m * r, r * 0.06, mark);
    }
  }

  @override
  bool shouldRepaint(PizzaPainter old) => old.underside != underside;
}

/// The pizza tossed up, flipping over once, and landing, its shadow on the
/// counter shrinking as it rises. [t] goes from 0 to 1 per toss.
class TossedPizza extends StatelessWidget {
  const TossedPizza({
    required this.t,
    this.size = 120,
    this.height = 70,
    super.key,
  });

  final double t;
  final double size;

  /// How high the toss goes.
  final double height;

  @override
  Widget build(BuildContext context) {
    // Up and down: a quick toss, then a pause on the counter.
    final air = (t / 0.75).clamp(0.0, 1.0);
    final lift = t < 0.75 ? math.sin(air * math.pi) : 0.0;
    final flip = Curves.easeInOut.transform(air) * math.pi * 2;
    final spin = Curves.easeInOut.transform(air) * 0.6;
    final underside = math.cos(flip) < 0;

    return SizedBox(
      width: size * 1.4,
      height: size + height + 24,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Shadow on the counter.
          Positioned(
            bottom: 0,
            child: Opacity(
              opacity: 0.18 * (1 - lift * 0.6),
              child: Container(
                width: size * (1 - lift * 0.35),
                height: 14 * (1 - lift * 0.35),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(size),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8 + lift * height,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX(flip)
                ..rotateZ(spin),
              child: SizedBox.square(
                dimension: size,
                child: CustomPaint(painter: PizzaPainter(underside: underside)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
