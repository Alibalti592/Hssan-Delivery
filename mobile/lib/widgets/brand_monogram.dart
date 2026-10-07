import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// The script "DH" of the client's artwork, in polished chrome.
///
/// The letters are the artwork's own: their centre lines were traced from
/// it, and they are drawn as one even-width tube (the artwork's monoline
/// script), tapering where its strokes do. So the monogram is the same
/// shape at every size, from the launcher icon to the admin sidebar.
class BrandMonogram extends StatelessWidget {
  const BrandMonogram({this.width = 140, super.key});

  /// Width of the letters; the height follows (the "DH" is
  /// [aspectRatio] times wider than tall).
  final double width;

  static const double aspectRatio = _boxWidth / _boxHeight;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, width / aspectRatio),
        painter: const _MonogramPainter(),
      ),
    );
  }
}

/// Size of the traced letters, in the units of [_strokes].
const double _boxWidth = 846;
const double _boxHeight = 323;

/// The tube's width, in the same units.
const double _tube = 38;

class _Stroke {
  const _Stroke(
    this.points, {
    this.width = 1,
    this.taperStart = 1,
    this.taperEnd = 1,
  });

  /// Centre line: x, y pairs every ~14 units, smoothed into a curve.
  final List<double> points;

  /// Width as a share of [_tube].
  final double width;

  /// Width at each end as a share of [width]: the artwork's pen thins out
  /// at a few of its ends.
  final double taperStart;
  final double taperEnd;
}

const _strokes = [
  // D
  _Stroke(
    [
      101,
      161,
      100.6,
      147.1,
      98.3,
      133.2,
      97.8,
      119.3,
      99.7,
      105.4,
      104.2,
      92.2,
      110.6,
      79.7,
      118.7,
      68.4,
      128.3,
      58.2,
      139.2,
      49.4,
      151.3,
      42.3,
      164.2,
      36.8,
      177.5,
      32.5,
      191.2,
      30,
      205.2,
      29.3,
      218.9,
      31.5,
      226,
      42.5,
      223.7,
      56.3,
      218.9,
      69.5,
      212.2,
      81.7,
      205.1,
      93.8,
      197.9,
      105.8,
      190.8,
      117.9,
      183.9,
      130,
      176.8,
      142.1,
      169.6,
      154.2,
      162.4,
      166.2,
      155.2,
      178.1,
      148.1,
      190.2,
      141.1,
      202.3,
      134,
      214.4,
      127,
      226.5,
      120,
      238.7,
      113.4,
      251,
      106,
      262.8,
      96.6,
      273.2,
      87.9,
      284.2,
      78.3,
      294.3,
      66,
      300.8,
      52.2,
      303.2,
      38.4,
      301.6,
      26.1,
      295.2,
      19.2,
      283.3,
      19.5,
      269.4,
      27.8,
      258.5,
      41,
      254.2,
      55,
      253.8,
      68.9,
      255.6,
      82.5,
      258.6,
      95.2,
      264.4,
      106.3,
      272.9,
      118.1,
      280.4,
      130.8,
      286.5,
      143.5,
      292.2,
      156.8,
      296.7,
      170.5,
      299.2,
      184.5,
      299.9,
      198.5,
      299.5,
      212.3,
      297.3,
      225.6,
      292.9,
      238.1,
      286.6,
      249.6,
      278.7,
      260.5,
      270,
      270.7,
      260.3,
      279.7,
      249.6,
      287.5,
      238,
      294.1,
      225.6,
      300.2,
      213,
      306.5,
      200.6,
      312.1,
      187.8,
      314.5,
      174,
      315.5,
      160,
      315.9,
      146,
      315.9,
      132,
      315,
      118.1,
      312.5,
      104.3,
      308,
      91,
      302,
      78.4,
      294.1,
      66.9,
      284.4,
      56.8,
      273.1,
      48.6,
      260.3,
      43,
      246.6,
      40,
      230,
      38,
    ],
    width: 1,
    taperStart: 0.75,
    taperEnd: 1,
  ),
  // Hleft
  _Stroke(
    [
      399,
      129,
      388.4,
      138.1,
      377.4,
      146.7,
      367.5,
      156.6,
      358.8,
      167.6,
      350.8,
      179.1,
      344.8,
      191.6,
      345,
      205.6,
      345.9,
      219.5,
      347.6,
      233.4,
      352.1,
      246.6,
      359.2,
      258.7,
      368.2,
      269.4,
      378.9,
      278.3,
      390.9,
      285.6,
      403.9,
      290.7,
      417.5,
      294.2,
      431.3,
      296.2,
      445.3,
      296.6,
      459.2,
      295,
      472.8,
      291.7,
      486.1,
      287.3,
      498.5,
      280.9,
      510.4,
      273.5,
      521.5,
      265,
      531.9,
      255.6,
      541.7,
      245.6,
      550.8,
      235,
      559.1,
      223.7,
      566.9,
      212.1,
      574.3,
      200.2,
      581.5,
      188.2,
      588.7,
      176.2,
      596.6,
      164.6,
      606.2,
      154.4,
      613.2,
      142.5,
      617.6,
      129.2,
      623.7,
      116.6,
      630.8,
      104.5,
      637.8,
      92.4,
      643.5,
      79.6,
      647.3,
      66.2,
      651.5,
      52.8,
      658.6,
      40.8,
      664.7,
      28.2,
      667,
      19,
    ],
    width: 1,
    taperStart: 0.8,
    taperEnd: 0.45,
  ),
  // Htop
  _Stroke(
    [
      503,
      161,
      495.5,
      149.2,
      490.7,
      136.1,
      489.8,
      122.2,
      493.4,
      108.7,
      500.3,
      96.6,
      510.2,
      86.8,
      522.1,
      79.4,
      534.8,
      73.7,
      548.1,
      69.1,
      561.5,
      65.1,
      575,
      61.6,
      588.5,
      57.8,
      602,
      54.1,
      615.7,
      51,
      629.5,
      48.8,
      643.4,
      47.1,
      651,
      47,
    ],
    width: 1,
    taperStart: 1,
    taperEnd: 1,
  ),
  // Hbar
  _Stroke(
    [
      611,
      153,
      623.5,
      159.1,
      637.3,
      160.8,
      651.3,
      161.1,
      665.3,
      162.1,
      678.6,
      166.2,
      683,
      169,
    ],
    width: 0.8,
    taperStart: 1,
    taperEnd: 1,
  ),
  // Hright
  _Stroke(
    [
      612,
      286,
      623.8,
      278.6,
      633,
      268,
      640.3,
      256.1,
      647.6,
      244.2,
      654.7,
      232.1,
      661.8,
      220,
      668.8,
      207.9,
      675.4,
      195.6,
      680,
      182.4,
      685.9,
      169.7,
      695.2,
      159.3,
      703.6,
      148.2,
      711,
      136.2,
      718,
      124.1,
      725.1,
      112.1,
      732.1,
      100,
      739.2,
      87.9,
      746.3,
      75.8,
      753.5,
      63.8,
      761.1,
      52.1,
      769.6,
      40.9,
      779.7,
      31.3,
      792,
      24.8,
      805.8,
      23.4,
      819,
      28,
      827,
      34,
    ],
    width: 1,
    taperStart: 0.45,
    taperEnd: 0.75,
  ),
];

/// A stroke as a dense line with a width at each point.
class _Line {
  _Line(this.points, this.widths);
  final List<Offset> points;
  final List<double> widths;
}

/// The strokes sampled along Catmull-Rom curves through their points.
final List<_Line> _lines = [for (final stroke in _strokes) _sample(stroke)];

_Line _sample(_Stroke stroke) {
  final p = [
    for (var i = 0; i < stroke.points.length; i += 2)
      Offset(stroke.points[i], stroke.points[i + 1]),
  ];
  Offset at(int i) {
    if (i < 0) return p[0] * 2 - p[1];
    if (i >= p.length) return p[p.length - 1] * 2 - p[p.length - 2];
    return p[i];
  }

  const steps = 6;
  final points = <Offset>[];
  for (var i = 0; i < p.length - 1; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    for (var s = 0; s < steps; s++) {
      final t = s / steps, t2 = t * t, t3 = t2 * t;
      points.add(
        (p1 * 2 +
                (p2 - p0) * t +
                (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
                (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
            0.5,
      );
    }
  }
  points.add(p.last);

  final along = <double>[0];
  for (var i = 1; i < points.length; i++) {
    along.add(along.last + (points[i] - points[i - 1]).distance);
  }
  final length = along.last;
  const taper = 60.0;
  double ease(double x) => x * x * (3 - 2 * x);
  final widths = [
    for (final s in along)
      stroke.width *
          (s < taper
              ? stroke.taperStart + (1 - stroke.taperStart) * ease(s / taper)
              : 1) *
          (length - s < taper
              ? stroke.taperEnd +
                    (1 - stroke.taperEnd) * ease((length - s) / taper)
              : 1),
  ];
  return _Line(points, widths);
}

class _MonogramPainter extends CustomPainter {
  const _MonogramPainter();

  /// Chrome lit from the top right, as on the artwork: white there, a
  /// cooler grey towards the bottom left.
  static const _edge = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFF0F0F1),
      Color(0xFFDDDEE0),
      Color(0xFFB2B4B7),
      Color(0xFF999B9F),
    ],
    stops: [0, 0.4, 0.75, 1],
  );
  static const _shine = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFAFAFA),
      Color(0xFFDADBDD),
      Color(0xFFB7B9BC),
    ],
    stops: [0, 0.45, 0.8, 1],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _boxWidth;
    final box = Offset.zero & const Size(_boxWidth, _boxHeight);
    // Never thinner than two pixels, so the small tiles stay legible.
    final tube = math.max(_tube, 2 / scale);

    void inBox(Offset shift, void Function() draw) {
      canvas
        ..save()
        ..scale(scale)
        ..translate(shift.dx, shift.dy);
      draw();
      canvas.restore();
    }

    ui.ImageFilter blur(double sigma) =>
        ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

    // Soft drop shadow, below the letters.
    canvas.saveLayer(
      null,
      Paint()
        ..color = const Color(0xC0000000)
        ..imageFilter = blur(10 * scale),
    );
    inBox(const Offset(3, 14), () {
      _draw(canvas, tube, Paint()..color = const Color(0xFF000000));
    });
    canvas.restore();

    // The tube: its grey edge, then a bright core lit from above, kept
    // inside the letters (srcATop) so it never spills past a thin tip.
    canvas.saveLayer(null, Paint());
    inBox(Offset.zero, () {
      _draw(canvas, tube, Paint()..shader = _edge.createShader(box));
    });
    canvas.saveLayer(
      null,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..imageFilter = blur(math.max(2 * scale, 0.3)),
    );
    inBox(Offset(-0.03 * tube, -0.08 * tube), () {
      _draw(canvas, tube * 0.72, Paint()..shader = _shine.createShader(box));
    });
    canvas
      ..restore()
      ..restore();
  }

  /// Every stroke at [tube] width with [paint]: runs of even width as one
  /// path, the tapering ends a segment at a time.
  static void _draw(Canvas canvas, double tube, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final line in _lines) {
      final p = line.points, w = line.widths;
      var i = 0;
      while (i < p.length - 1) {
        var j = i + 1;
        while (j < p.length - 1 && w[j] == w[i]) {
          j++;
        }
        final path = Path()..moveTo(p[i].dx, p[i].dy);
        for (var k = i + 1; k <= j; k++) {
          path.lineTo(p[k].dx, p[k].dy);
        }
        canvas.drawPath(path, paint..strokeWidth = tube * w[i]);
        i = j;
      }
    }
  }

  @override
  bool shouldRepaint(_MonogramPainter oldDelegate) => false;
}
