import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/promotions/auto_carousel.dart';

Widget _carousel(int count, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: AutoCarousel(
        itemCount: count,
        itemWidth: 180,
        height: 100,
        itemBuilder: (context, index) => Text('card $index'),
      ),
    ),
  ),
);

/// Left edge of the card on screen -- the leading card sits at the gap.
double _left(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text).first).dx;

void main() {
  testWidgets('slides one card to the left every interval, and goes round', (
    tester,
  ) async {
    await tester.pumpWidget(_carousel(3));
    expect(_left(tester, 'card 0'), AutoCarousel.gap);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 1'), AutoCarousel.gap);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 2'), AutoCarousel.gap);

    // After the last card comes the first again, still sliding left.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 0'), AutoCarousel.gap);
  });

  testWidgets('holds still while touched', (tester) async {
    await tester.pumpWidget(_carousel(3));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('card 0').first),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 0'), AutoCarousel.gap);

    await gesture.up();
    await tester.pumpAndSettle();
    // A full interval after letting go before it moves again.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 0'), AutoCarousel.gap);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 1'), AutoCarousel.gap);
  });

  testWidgets('a single card, or reduced motion, never moves', (tester) async {
    await tester.pumpWidget(_carousel(1));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 0'), AutoCarousel.gap);

    await tester.pumpWidget(_carousel(3, reduceMotion: true));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(_left(tester, 'card 0'), AutoCarousel.gap);
  });
}
