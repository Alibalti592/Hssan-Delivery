import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/brand_logo.dart';
import 'auth_controller.dart';
import 'scooter_painter.dart';

/// Shown while a new client account is created: a courier riding through
/// the city while three steps tick off, then a welcome. Pops with the
/// error message when sign-up fails, so the form can show it.
class AccountCreationScreen extends StatefulWidget {
  const AccountCreationScreen({
    required this.name,
    required this.phone,
    required this.password,
    super.key,
  });

  final String name;
  final String phone;
  final String password;

  @override
  State<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

enum _Phase { creating, ready, failed }

class _AccountCreationScreenState extends State<AccountCreationScreen>
    with TickerProviderStateMixin {
  static const _steps = [
    'Vérification de votre numéro',
    'Sécurisation de votre mot de passe',
    'Préparation de votre espace',
  ];

  /// Each step shows for at least this long, so the screen reads as
  /// progress rather than a flash, however fast the server answers.
  static const _stepTime = Duration(milliseconds: 850);

  /// The road, buildings, speed lines and the courier's bounce.
  late final AnimationController _ride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The courier speeding off, then the welcome badge.
  late final AnimationController _finish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  _Phase _phase = _Phase.creating;
  int _doneSteps = 0;
  String? _error;
  Timer? _autoContinue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion (and widget tests): a still scene.
    if (MediaQuery.disableAnimationsOf(context)) {
      _ride.stop();
    } else if (!_ride.isAnimating && _phase == _Phase.creating) {
      _ride.repeat();
    }
  }

  @override
  void dispose() {
    _autoContinue?.cancel();
    _ride.dispose();
    _finish.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final auth = context.read<AuthController>();
    final result = auth.register(
      name: widget.name,
      phone: widget.phone,
      password: widget.password,
    );

    // The first two steps tick off on their own; the last one waits for
    // the server.
    for (var step = 0; step < _steps.length - 1; step++) {
      await Future<void>.delayed(_stepTime);
      if (!mounted) return;
      setState(() => _doneSteps = step + 1);
    }
    final results = await Future.wait([
      result,
      Future<void>.delayed(_stepTime).then((_) => null),
    ]);
    if (!mounted) return;

    final error = results.first;
    if (error != null) {
      _ride.stop();
      setState(() {
        _phase = _Phase.failed;
        _error = error;
      });
      return;
    }

    setState(() {
      _doneSteps = _steps.length;
      _phase = _Phase.ready;
    });
    await _finish.forward();
    _ride.stop();
    if (!mounted) return;
    _autoContinue = Timer(const Duration(milliseconds: 2600), _continue);
  }

  /// Signed in already (register() signs in): the app's root shows the
  /// client home under this screen and the form.
  void _continue() {
    _autoContinue?.cancel();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String get _firstName {
    final first = widget.name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? '' : first;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ready = _phase == _Phase.ready;
    final failed = _phase == _Phase.failed;

    return PopScope(
      // Nothing to go back to while the account is being created.
      canPop: failed,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BrandBackdrop(
          center: const Alignment(0, -0.2),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          const BrandMonogram(size: 40),
                          const Spacer(),
                          SizedBox(
                            // Smaller on short phones, so everything fits.
                            height: (box.maxHeight * 0.28).clamp(150.0, 210.0),
                            child: _Scene(
                              ride: _ride,
                              finish: _finish,
                              stopped: failed,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: Column(
                              key: ValueKey(_phase),
                              children: [
                                Text(
                                  ready
                                      ? (_firstName.isEmpty
                                            ? 'Bienvenue !'
                                            : 'Bienvenue, $_firstName !')
                                      : failed
                                      ? "Le compte n'a pas pu être créé"
                                      : 'Votre compte est en cours de création',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 21,
                                    height: 1.25,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ready
                                      ? 'Votre compte est prêt. Bonne commande !'
                                      : failed
                                      ? _error!
                                      : 'Nous préparons tout pour vos premières '
                                            'commandes.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: failed
                                        ? const Color(0xFFF2A7A7)
                                        : const Color(0xFFB4BAC2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (!ready)
                            _StepsCard(
                              steps: _steps,
                              done: _doneSteps,
                              failed: failed,
                            ),
                          if (ready) const SizedBox(height: 8),
                          const Spacer(),
                          if (!failed)
                            _ProgressBar(
                              value: (_doneSteps / _steps.length).clamp(
                                0.08,
                                1,
                              ),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: ready
                                ? _LightButton(
                                    label: "C'EST PARTI",
                                    onPressed: _continue,
                                  )
                                : failed
                                ? _LightButton(
                                    label: 'MODIFIER MES INFORMATIONS',
                                    onPressed: () =>
                                        Navigator.of(context).pop(_error),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The night street: two rows of buildings sliding by at different
/// speeds, the road's dashed line, the courier bobbing on the scooter
/// with speed lines and exhaust behind, then racing off and a check
/// badge once the account is ready.
class _Scene extends StatelessWidget {
  const _Scene({
    required this.ride,
    required this.finish,
    required this.stopped,
  });

  final Animation<double> ride;
  final Animation<double> finish;
  final bool stopped;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ride, finish]),
      builder: (context, _) {
        final t = ride.value;
        final f = finish.value;
        // Off to the right, accelerating, during the first 60 % of finish.
        final dash = Curves.easeIn.transform((f / 0.6).clamp(0, 1));
        final badge = Curves.elasticOut.transform(
          ((f - 0.45) / 0.55).clamp(0, 1),
        );
        final bounce = math.sin(t * 2 * math.pi * 4) * 2.5;

        return LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            return ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _StreetPainter(t: t)),
                  ),
                  // Courier.
                  Positioned(
                    left: width / 2 - 95 + dash * (width / 2 + 190),
                    bottom: 30 + bounce,
                    child: Opacity(
                      opacity: stopped ? 0.55 : 1,
                      child: _Courier(t: t, speeding: dash > 0),
                    ),
                  ),
                  if (badge > 0)
                    Center(
                      child: Transform.scale(
                        scale: badge,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF34C77B),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF34C77B,
                                ).withValues(alpha: 0.45),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 54,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The silver courier on his scooter, speed lines and exhaust puffs
/// trailing behind.
class _Courier extends StatelessWidget {
  const _Courier({required this.t, required this.speeding});

  final double t;
  final bool speeding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Speed lines and puffs, behind the scooter (on its left).
          Positioned.fill(
            child: CustomPaint(
              painter: _TrailPainter(t: t, long: speeding),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: 150,
              height: 120,
              child: CustomPaint(painter: ScooterPainter(t: t)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.t, required this.long});

  final double t;
  final bool long;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    // Three speed lines streaming back from the scooter.
    for (var i = 0; i < 3; i++) {
      final phase = (t * 2 + i / 3) % 1;
      final y = size.height * (0.38 + i * 0.13);
      final length = (long ? 70.0 : 34.0) + 14 * i;
      final x = size.width * 0.32 - phase * 60;
      line.color = Colors.white.withValues(alpha: 0.5 * (1 - phase));
      canvas.drawLine(Offset(x, y), Offset(x - length, y), line);
    }
    // Exhaust puffs from the back wheel, growing and fading.
    final puff = Paint();
    for (var i = 0; i < 3; i++) {
      final phase = (t * 1.5 + i / 3) % 1;
      puff.color = const Color(
        0xFFB4BAC2,
      ).withValues(alpha: 0.35 * (1 - phase));
      canvas.drawCircle(
        Offset(size.width * 0.36 - phase * 46, size.height * 0.86 - phase * 10),
        3 + phase * 7,
        puff,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.t != t || old.long != long;
}

class _StreetPainter extends CustomPainter {
  _StreetPainter({required this.t});

  final double t;

  // Building widths and heights (as fractions of the scene height),
  // repeated along the street.
  static const _far = [
    [36.0, 0.42],
    [24.0, 0.58],
    [44.0, 0.36],
    [30.0, 0.66],
    [40.0, 0.48],
    [28.0, 0.54],
    [50.0, 0.40],
    [26.0, 0.62],
  ];
  static const _near = [
    [52.0, 0.34],
    [38.0, 0.46],
    [60.0, 0.30],
    [44.0, 0.52],
    [56.0, 0.38],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final roadTop = size.height - 34;

    // A faint moon-glow behind the city.
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.2),
      28,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    _skyline(
      canvas,
      size,
      roadTop,
      _far,
      const Color(0xFF26282C),
      t * 40,
      withWindows: false,
    );
    _skyline(
      canvas,
      size,
      roadTop,
      _near,
      const Color(0xFF1C1D20),
      t * 110,
      withWindows: true,
    );

    // Road and its dashed centre line.
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, size.width, size.height - roadTop),
      Paint()..color = const Color(0xFF0E0E0F),
    );
    canvas.drawLine(
      Offset(0, roadTop),
      Offset(size.width, roadTop),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashLength = 22.0;
    const gap = 18.0;
    final shift = (t * 4 * (dashLength + gap)) % (dashLength + gap);
    final y = roadTop + 18;
    for (var x = -shift; x < size.width; x += dashLength + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dashLength, y), dash);
    }
  }

  void _skyline(
    Canvas canvas,
    Size size,
    double ground,
    List<List<double>> buildings,
    Color color,
    double scroll, {
    required bool withWindows,
  }) {
    final pattern = buildings.fold<double>(0, (sum, b) => sum + b[0] + 6);
    final body = Paint()..color = color;
    final window = Paint()
      ..color = const Color(0xFFE8C77A).withValues(alpha: 0.28);
    var x = -(scroll % pattern);
    var index = 0;
    while (x < size.width) {
      final b = buildings[index % buildings.length];
      final height = (ground - 8) * b[1];
      final rect = Rect.fromLTWH(x, ground - height, b[0], height);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        body,
      );
      if (withWindows) {
        for (var wy = rect.top + 8; wy < ground - 10; wy += 12) {
          for (var wx = rect.left + 7; wx < rect.right - 8; wx += 11) {
            // A fixed scatter of lit windows.
            if (((wx * 7 + wy * 13 + index * 31) ~/ 1) % 5 == 0) {
              canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 5), window);
            }
          }
        }
      }
      x += b[0] + 6;
      index++;
    }
  }

  @override
  bool shouldRepaint(_StreetPainter old) => old.t != t;
}

/// The three steps, each waiting, in progress or done.
class _StepsCard extends StatelessWidget {
  const _StepsCard({
    required this.steps,
    required this.done,
    required this.failed,
  });

  final List<String> steps;
  final int done;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _StepRow(
                label: steps[i],
                state: i < done
                    ? _StepState.done
                    : i == done
                    ? (failed ? _StepState.failed : _StepState.active)
                    : _StepState.waiting,
              ),
            ),
        ],
      ),
    );
  }
}

enum _StepState { waiting, active, done, failed }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Widget mark = switch (state) {
      _StepState.done => Container(
        key: const ValueKey('done'),
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF34C77B),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      ),
      _StepState.active => const SizedBox(
        key: ValueKey('active'),
        width: 22,
        height: 22,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFE4E7EB)),
          ),
        ),
      ),
      _StepState.failed => Container(
        key: const ValueKey('failed'),
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFD64545),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
      ),
      _StepState.waiting => Container(
        key: const ValueKey('waiting'),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
      ),
    };

    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: mark,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: state == _StepState.waiting
                  ? FontWeight.w400
                  : FontWeight.w600,
              color: state == _StepState.waiting
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.white,
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            Container(height: 5, color: Colors.white.withValues(alpha: 0.1)),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 5,
                decoration: const BoxDecoration(gradient: BrandMonogram.silver),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White on the dark backdrop, the brand's primary action.
class _LightButton extends StatelessWidget {
  const _LightButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
