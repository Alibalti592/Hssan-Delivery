import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A Delivery Hassen courier on his scooter, facing right: silver scooter,
/// helmeted rider leaning into the ride, and the red delivery box with the
/// script "DH" on the back, steaming like a hot pizza. Drawn on a 150×120
/// canvas (scaled to whatever size it is given).
///
/// [t] runs from 0 to 1 and repeats: the wheels turn, the rider bobs and
/// the steam rises with it.
class ScooterPainter extends CustomPainter {
  ScooterPainter({required this.t});

  final double t;

  static const _silver = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFD5D9DE), Color(0xFF8F959D)],
  );
  static const _tire = Color(0xFF0B0B0C);
  static const _boxRed = Color(0xFFC8372D);
  static const _jacket = Color(0xFFE7EAEE);
  static const _pants = Color(0xFF8E949C);
  static const _dark = Color(0xFF1B1C1F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 150, size.height / 120);

    // The body bobs over the road; the wheels stay on it.
    final bob = math.sin(t * 2 * math.pi * 4) * 1.6;
    final spin = t * 2 * math.pi * 6;

    _wheel(canvas, const Offset(30, 98), spin);

    canvas.save();
    canvas.translate(0, bob);
    _steam(canvas);
    _box(canvas);
    _scooter(canvas);
    _rider(canvas);
    canvas.restore();

    _wheel(canvas, const Offset(120, 98), spin);
    // Front fork over the front wheel.
    canvas.drawLine(
      Offset(120, 98),
      Offset(112, 62 + bob),
      Paint()
        ..color = const Color(0xFFB8BDC4)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  void _wheel(Canvas canvas, Offset c, double spin) {
    canvas.drawCircle(c, 17, Paint()..color = _tire);
    canvas.drawCircle(
      c,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFC9CED4),
    );
    final spoke = Paint()
      ..color = const Color(0xFF9AA0A8)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = spin + i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a)) * 10;
      canvas.drawLine(c - d, c + d, spoke);
    }
    canvas.drawCircle(c, 3, Paint()..color = const Color(0xFFE4E7EB));
  }

  void _scooter(Canvas canvas) {
    final silver = Paint()
      ..shader = _silver.createShader(const Rect.fromLTWH(0, 50, 150, 50));

    // Rear body under the seat, over the back wheel.
    final rear = Path()
      ..moveTo(10, 88)
      ..quadraticBezierTo(12, 68, 34, 66)
      ..lineTo(80, 64)
      ..quadraticBezierTo(88, 66, 86, 76)
      ..lineTo(70, 90)
      ..quadraticBezierTo(42, 96, 10, 88)
      ..close();
    canvas.drawPath(rear, silver);

    // Seat.
    canvas.drawRRect(
      RRect.fromLTRBR(36, 58, 80, 66, const Radius.circular(4)),
      Paint()..color = _dark,
    );

    // Footboard to the front shield.
    final front = Path()
      ..moveTo(62, 88)
      ..lineTo(104, 88)
      ..quadraticBezierTo(112, 86, 114, 74)
      ..lineTo(118, 52)
      ..lineTo(110, 50)
      ..lineTo(104, 76)
      ..quadraticBezierTo(102, 82, 94, 82)
      ..lineTo(62, 82)
      ..close();
    canvas.drawPath(front, silver);

    // Front mudguard.
    canvas.drawArc(
      const Rect.fromLTWH(101, 79, 38, 38),
      math.pi * 1.05,
      math.pi * 0.75,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD5D9DE),
    );

    // Handlebar and headlight with its warm glow.
    canvas.drawLine(
      const Offset(110, 46),
      const Offset(124, 42),
      Paint()
        ..color = _dark
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(122, 56),
      9,
      Paint()
        ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      const Offset(121, 56),
      3.4,
      Paint()..color = const Color(0xFFFFF1C9),
    );
  }

  void _box(Canvas canvas) {
    const box = Rect.fromLTWH(6, 26, 44, 36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE04A3F), _boxRed, Color(0xFF9E2A22)],
        ).createShader(box),
    );
    // Lid line.
    canvas.drawLine(
      const Offset(8, 34),
      const Offset(48, 34),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..strokeWidth = 1.2,
    );
    final label = TextPainter(
      text: const TextSpan(
        text: 'DH',
        style: TextStyle(
          fontFamily: 'AlexBrush',
          fontSize: 17,
          color: Colors.white,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // The script's H overhangs its box: nudge left so it looks centred.
    label.paint(canvas, Offset(box.center.dx - label.width / 2 - 3, 38));
  }

  void _steam(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final phase = (t * 2 + i / 3) % 1;
      final x = 16.0 + i * 12;
      final base = 22 - phase * 14;
      paint.color = Colors.white.withValues(alpha: 0.3 * (1 - phase));
      final path = Path()..moveTo(x, base);
      for (var k = 1; k <= 3; k++) {
        path.quadraticBezierTo(
          x + (k.isOdd ? 3 : -3),
          base - k * 3 + 1.5,
          x,
          base - k * 3,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _rider(Canvas canvas) {
    Paint limb(Color color, double width) => Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Leg: hip, knee, foot on the board.
    final leg = Path()
      ..moveTo(66, 58)
      ..lineTo(86, 66)
      ..lineTo(92, 84);
    canvas.drawPath(leg, limb(_pants, 9));
    canvas.drawRRect(
      RRect.fromLTRBR(88, 82, 100, 88, const Radius.circular(3)),
      Paint()..color = _dark,
    );

    // Torso, leaning into the ride.
    canvas.drawLine(
      const Offset(66, 56),
      const Offset(84, 32),
      limb(_jacket, 17),
    );
    // A darker stripe across the jacket.
    canvas.drawLine(
      const Offset(70, 52),
      const Offset(80, 39),
      limb(_boxRed.withValues(alpha: 0.85), 3),
    );

    // Arm to the handlebar, gloved hand.
    final arm = Path()
      ..moveTo(84, 34)
      ..lineTo(98, 44)
      ..lineTo(111, 44);
    canvas.drawPath(arm, limb(_jacket, 7));
    canvas.drawCircle(const Offset(112, 44), 3.6, Paint()..color = _dark);

    // Helmet with its visor facing the road ahead.
    const head = Offset(90, 20);
    canvas.drawCircle(
      head,
      12,
      Paint()
        ..shader = _silver.createShader(
          Rect.fromCircle(center: head, radius: 12),
        ),
    );
    final visor = Path()
      ..moveTo(90, 15)
      ..quadraticBezierTo(101, 14, 102, 21)
      ..quadraticBezierTo(101, 27, 92, 26)
      ..close();
    canvas.drawPath(visor, Paint()..color = _dark);
    // A glint on the visor.
    canvas.drawLine(
      const Offset(95, 17),
      const Offset(99, 18),
      limb(Colors.white.withValues(alpha: 0.6), 1.4),
    );
  }

  @override
  bool shouldRepaint(ScooterPainter old) => old.t != t;
}
