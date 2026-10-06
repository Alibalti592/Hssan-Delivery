import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_controller.dart';
import 'scooter_painter.dart';

/// Shown while a new client account is created. Deliberately quiet: the
/// courier riding along a single line, one sentence, the current step in
/// grey and a hairline of progress; then a short welcome. Pops with the
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

  /// The road's dashes, the wheels and the courier's bounce.
  late final AnimationController _ride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The courier riding off, then the check.
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
    _autoContinue = Timer(const Duration(milliseconds: 2200), _continue);
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
    final ready = _phase == _Phase.ready;
    final failed = _phase == _Phase.failed;

    final title = ready
        ? (_firstName.isEmpty ? 'Bienvenue !' : 'Bienvenue, $_firstName !')
        : failed
        ? "Le compte n'a pas pu être créé"
        : 'Votre compte est en cours de création';
    final detail = ready
        ? 'Votre compte est prêt.'
        : failed
        ? _error!
        : '${_steps[_doneSteps.clamp(0, _steps.length - 1)]}…';

    return PopScope(
      // Nothing to go back to while the account is being created.
      canPop: failed,
      child: Scaffold(
        backgroundColor: _ink,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        SizedBox(
                          height: 130,
                          child: _Scene(
                            ride: _ride,
                            finish: _finish,
                            stopped: failed,
                          ),
                        ),
                        const SizedBox(height: 40),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            title,
                            key: ValueKey(title),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              fontSize: 19,
                              height: 1.3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            detail,
                            key: ValueKey(detail),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: failed
                                  ? const Color(0xFFE8A0A0)
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: failed || ready ? 0 : 1,
                          child: _Hairline(
                            value: ((_doneSteps + 0.4) / _steps.length).clamp(
                              0,
                              1,
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        SizedBox(
                          height: 52,
                          child: failed
                              ? _OutlineButton(
                                  label: 'Modifier mes informations',
                                  onPressed: () =>
                                      Navigator.of(context).pop(_error),
                                )
                              : ready
                              ? _OutlineButton(
                                  label: 'Continuer',
                                  onPressed: _continue,
                                )
                              : null,
                        ),
                        const SizedBox(height: 24),
                      ],
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

const _ink = Color(0xFF0B0B0C);

/// The courier on a single line of road, its dashes passing under him;
/// when the account is ready he rides off and a small check takes his
/// place.
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
        final away = Curves.easeIn.transform((f / 0.6).clamp(0, 1));
        final check = Curves.easeOutBack.transform(
          ((f - 0.5) / 0.5).clamp(0, 1),
        );

        return LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoadPainter(t: t, fade: 1 - check),
                  ),
                ),
                Positioned(
                  left: width / 2 - 62 + away * (width / 2 + 120),
                  bottom: 8,
                  child: Opacity(
                    opacity: (stopped ? 0.4 : 1) * (1 - away * 0.6),
                    child: SizedBox(
                      width: 125,
                      height: 100,
                      child: CustomPaint(painter: ScooterPainter(t: t)),
                    ),
                  ),
                ),
                if (check > 0)
                  Center(
                    child: Opacity(
                      opacity: check.clamp(0, 1),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * check,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.6),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// One hairline of road fading out at both ends, with short dashes
/// sliding under the courier.
class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.t, required this.fade});

  final double t;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0) return;
    final y = size.height - 6;
    final edges = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.22 * fade),
        Colors.white.withValues(alpha: 0.22 * fade),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0, 0.25, 0.75, 1],
    ).createShader(Rect.fromLTWH(0, y, size.width, 1));
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..shader = edges
        ..strokeWidth = 1,
    );

    const dash = 14.0;
    const gap = 26.0;
    final shift = (t * 3 * (dash + gap)) % (dash + gap);
    final paint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var x = -shift; x < size.width; x += dash + gap) {
      // Dimmer towards the edges, like the line.
      final mid = (x + dash / 2) / size.width;
      final strength = (1 - (mid - 0.5).abs() * 2).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: 0.35 * strength * fade);
      canvas.drawLine(Offset(x, y + 6), Offset(x + dash, y + 6), paint);
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.t != t || old.fade != fade;
}

/// Progress as a single thin line.
class _Hairline extends StatelessWidget {
  const _Hairline({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: Stack(
            children: [
              Container(height: 2, color: Colors.white.withValues(alpha: 0.12)),
              FractionallySizedBox(
                widthFactor: v,
                child: Container(height: 2, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
