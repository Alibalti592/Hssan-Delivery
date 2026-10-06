import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'auth_controller.dart';
import 'pizza_painter.dart';

/// Shown while a new client account is created. A white, quiet screen: a
/// pizza tossed and flipped, one sentence, the current step in grey and a
/// hairline of progress; then a short welcome. Pops with the
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

  /// One toss of the pizza: up, a flip, down, a short rest.
  late final AnimationController _ride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  /// The pizza fading out, then the check.
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.white,
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
                            height: 210,
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
                                color: _ink,
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
                                    ? const Color(0xFFC53030)
                                    : const Color(0xFF8A9099),
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
      ),
    );
  }
}

const _ink = Color(0xFF0B0B0C);

/// The pizza being tossed; once the account is ready it fades and a thin
/// check takes its place.
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
        final f = finish.value;
        final gone = Curves.easeIn.transform((f / 0.5).clamp(0, 1));
        final check = Curves.easeOutBack.transform(
          ((f - 0.4) / 0.6).clamp(0, 1),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (stopped ? 0.35 : 1) * (1 - gone),
              child: Transform.scale(
                scale: 1 - 0.2 * gone,
                child: TossedPizza(t: ride.value, size: 120, height: 62),
              ),
            ),
            if (check > 0)
              Opacity(
                opacity: check.clamp(0, 1),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * check,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _ink, width: 1.6),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: _ink,
                      size: 36,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
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
              Container(height: 2, color: const Color(0xFFE6E8EB)),
              FractionallySizedBox(
                widthFactor: v,
                child: Container(height: 2, color: _ink),
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
          foregroundColor: _ink,
          side: const BorderSide(color: Color(0xFFD5D8DD)),
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
