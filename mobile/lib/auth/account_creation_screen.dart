import '../theme.dart';
import '../widgets/brand_logo.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'pizza_painter.dart';

/// Shown while a new client account is created, in the app's own look:
/// the app icon, a pizza tossed and flipped over its plate, one sentence,
/// the current step and a three-part progress bar; then a short welcome. Pops with the
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
    final textTheme = Theme.of(context).textTheme;
    final ready = _phase == _Phase.ready;
    final failed = _phase == _Phase.failed;

    final title = ready
        ? (_firstName.isEmpty ? 'Bienvenue !' : 'Bienvenue, $_firstName !')
        : failed
        ? "Le compte n'a pas pu être créé"
        : 'Votre compte est en cours de création';
    final detail = ready
        ? 'Votre compte est prêt. Bonne commande !'
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
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          const _AppMark(),
                          const Spacer(flex: 2),
                          SizedBox(
                            height: 250,
                            child: _Scene(
                              ride: _ride,
                              finish: _finish,
                              stopped: failed,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              title,
                              key: ValueKey(title),
                              textAlign: TextAlign.center,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: navy,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (failed)
                            AuthErrorBanner(_error!)
                          else
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                detail,
                                key: ValueKey(detail),
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: mutedText,
                                ),
                              ),
                            ),
                          const SizedBox(height: 26),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: failed || ready ? 0 : 1,
                            child: _StepBar(
                              total: _steps.length,
                              done: _doneSteps,
                            ),
                          ),
                          const Spacer(flex: 3),
                          if (ready)
                            FilledButton(
                              onPressed: _continue,
                              child: const Text("C'EST PARTI"),
                            )
                          else if (failed)
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(_error),
                              child: const Text('MODIFIER MES INFORMATIONS'),
                            )
                          else
                            const SizedBox(height: 50),
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

/// The app icon: the silver script "DH" on its black tile.
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const BrandMonogram(size: 19),
    );
  }
}

/// The pizza tossed over its plate (the app's soft blue-grey, as behind
/// its icons); once the account is ready it fades, the plate turns green
/// and the app's check takes its place, as after an order.
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
          alignment: Alignment.bottomCenter,
          children: [
            // The plate: the app's blue-grey, turning its soft green when
            // the account is ready.
            Positioned(
              bottom: 0,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Color.lerp(fieldFill, successBg, check.clamp(0, 1)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              child: Opacity(
                opacity: (stopped ? 0.4 : 1) * (1 - gone),
                child: Transform.scale(
                  scale: 1 - 0.2 * gone,
                  child: TossedPizza(t: ride.value, size: 120, height: 80),
                ),
              ),
            ),
            if (check > 0)
              Positioned(
                bottom: 64,
                child: Opacity(
                  opacity: check.clamp(0, 1),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * check,
                    child: const Icon(
                      Icons.check_rounded,
                      color: successText,
                      size: 72,
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

/// Three segments, one per step, like the order progress on the home
/// screen: done in black, the current one half-lit.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 4,
                decoration: BoxDecoration(
                  color: i < done
                      ? navy
                      : i == done
                      ? navy.withValues(alpha: 0.35)
                      : fieldFill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
