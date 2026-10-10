import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/dark_header.dart';
import 'package:mobile/widgets/status_bar.dart';

/// The app as main.dart sets it up: light theme, dark status bar icons by
/// default.
Widget _app(Widget home) => MaterialApp(
  theme: buildTheme(),
  themeMode: ThemeMode.light,
  builder: (context, child) => StatusBarDefault(child: child!),
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
    await tester.pump(); // the launch re-send

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

    await tester.pump(); // the launch re-send

    expect(SystemChrome.latestStyle, statusBarOnLight);
  });

  testWidgets('the style is sent to iOS again when the app comes back', (
    tester,
  ) async {
    final sent = <Brightness?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
          final brightness = (call.arguments as Map)['statusBarBrightness'];
          sent.add(
            brightness == 'Brightness.dark'
                ? Brightness.dark
                : Brightness.light,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    // The login screen: black, white icons (statusBarBrightness dark).
    await tester.pumpWidget(
      _app(
        const AnnotatedRegion<SystemUiOverlayStyle>(
          value: statusBarOnDark,
          child: ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pump();
    sent.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(sent, [Brightness.dark]);
  });
}
