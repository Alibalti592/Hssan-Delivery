import 'package:flutter/material.dart';

import '../theme.dart';

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Shown once, the first time the app is opened before signing in. Only
/// describes features that actually exist today (restaurant browsing and
/// order-status tracking) — the platform's other planned services
/// (supermarché, colis, transfert — see the README roadmap) aren't built
/// yet, so they aren't advertised here.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  static const _slides = [
    _Slide(
      icon: Icons.storefront_outlined,
      title: 'Tous vos restaurants préférés',
      subtitle:
          'Parcourez les restaurants disponibles, composez votre panier et '
          'commandez en quelques instants.',
    ),
    _Slide(
      icon: Icons.receipt_long_outlined,
      title: 'Suivez votre commande',
      subtitle:
          'De la confirmation à la livraison, suivez chaque étape de votre '
          'commande directement dans l\'application.',
    ),
  ];

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == OnboardingScreen._slides.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: OnboardingScreen._slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = OnboardingScreen._slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: fieldFill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(slide.icon, size: 56, color: navy),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: mutedText, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < OnboardingScreen._slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? navy : const Color(0xFFD7DCE3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: FilledButton(
                onPressed: _next,
                child: Text(_isLast ? 'COMMENCER' : 'SUIVANT'),
              ),
            ),
            if (!_isLast)
              TextButton(onPressed: widget.onDone, child: const Text('Passer'))
            else
              const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
