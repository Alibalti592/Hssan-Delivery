import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A horizontal row of fixed-width cards that slides on its own, one card
/// every [interval], right to left, and keeps going round (after the last
/// card comes the first again). Dots underneath show which card leads.
///
/// It stops while the customer's finger is on it and picks up again after
/// they let go, so a manual swipe never fights the timer. A single card, or
/// a phone set to reduce motion, just sits still.
class AutoCarousel extends StatefulWidget {
  const AutoCarousel({
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.height,
    this.interval = const Duration(seconds: 4),
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;
  final double height;
  final Duration interval;

  /// Left inset of each card and the gap between two of them.
  static const double gap = 16;

  @override
  State<AutoCarousel> createState() => _AutoCarouselState();
}

class _AutoCarouselState extends State<AutoCarousel> {
  PageController? _controller;
  double? _viewportFraction;
  Timer? _timer;
  int _page = 0;
  bool _touching = false;

  bool get _slides => widget.itemCount > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void didUpdateWidget(AutoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.interval != widget.interval) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_slides || MediaQuery.of(context).disableAnimations) return;
    _timer = Timer.periodic(widget.interval, (_) => _advance());
  }

  void _advance() {
    if (!mounted) return;
    final controller = _controller;
    // Not while touched, and not while another screen covers this one.
    if (_touching ||
        controller == null ||
        !controller.hasClients ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    controller.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  /// Sizes the pages so each one is a card plus its left gap, starting at
  /// the left edge -- the same look as a plain scrolling row.
  PageController _controllerFor(double width) {
    final fraction = ((widget.itemWidth + AutoCarousel.gap) / width).clamp(
      0.1,
      1.0,
    );
    if (_controller == null || _viewportFraction != fraction) {
      _controller?.dispose();
      _viewportFraction = fraction;
      _controller = PageController(
        viewportFraction: fraction,
        initialPage: _page,
      );
    }
    return _controller!;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) => Listener(
              onPointerDown: (_) => _touching = true,
              onPointerUp: (_) => _touchEnded(),
              onPointerCancel: (_) => _touchEnded(),
              child: PageView.builder(
                controller: _controllerFor(constraints.maxWidth),
                padEnds: false,
                // Endless when it slides, so going round never has to jump
                // back to the first card.
                itemCount: _slides ? null : widget.itemCount,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(left: AutoCarousel.gap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: widget.itemWidth,
                      child: widget.itemBuilder(
                        context,
                        index % widget.itemCount,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_slides) ...[
          const SizedBox(height: 10),
          _Dots(count: widget.itemCount, active: _page % widget.itemCount),
        ],
      ],
    );
  }

  void _touchEnded() {
    _touching = false;
    // A full interval after letting go before it moves again.
    _restartTimer();
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? navy : const Color(0xFFD5DAE1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
