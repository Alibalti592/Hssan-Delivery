import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/dark_header.dart';

/// The app as main.dart sets it up: light theme, dark status bar icons by
/// default.
Widget _app(Widget home) => MaterialApp(
  theme: buildTheme(),
  themeMode: ThemeMode.light,
  builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: statusBarOnLight,
    child: child!,
  ),
  home: home,
);

void main() {
  setUp(() {
    // A phone in dark mode: what made iOS draw white status bar icons.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .platformBrightnessTestValue =
        Brightness.dark;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  testWidgets('a black header reaches under the status bar, white icons', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 141); // 47 pt at 3x
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: SafeArea(
            top: false,
            child: Column(children: [DarkHeader(title: 'Colis')]),
          ),
        ),
      ),
    );

    expect(SystemChrome.latestStyle, statusBarOnDark);
    // The header itself starts at the very top, under the status bar...
    expect(tester.getTopLeft(find.byType(DarkHeader)).dy, 0);
    // ...and its title stays below it.
    final statusBar = 141 / tester.view.devicePixelRatio;
    expect(tester.getTopLeft(find.text('Colis')).dy, greaterThan(statusBar));
  });

  testWidgets('a white screen gets dark icons, even in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: SafeArea(child: Text('Bonjour, Sami !')))),
    );

    expect(SystemChrome.latestStyle, statusBarOnLight);
  });
}
