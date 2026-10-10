import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The app's status bar default: dark icons, for our white screens
/// (DarkHeader, splash and login set white ones on black).
///
/// Flutter only tells iOS when the style changes, so a request iOS didn't
/// apply (at launch, or while the app was in the background) is never sent
/// again — the login screen, the first one after launch, could keep the
/// wrong icons. The style in effect is therefore re-sent once the first
/// frame is up and whenever the app comes back to the foreground.
class StatusBarDefault extends StatefulWidget {
  const StatusBarDefault({required this.child, super.key});

  final Widget child;

  @override
  State<StatusBarDefault> createState() => _StatusBarDefaultState();
}

class _StatusBarDefaultState extends State<StatusBarDefault>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resend();
  }

  /// Forgets the style last sent (what the binding does when the app is
  /// detached), so the next frame sends the current one again.
  void _resend() {
    SystemChrome.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    WidgetsBinding.instance.scheduleForcedFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: statusBarOnLight,
    child: widget.child,
  );
}
