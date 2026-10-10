import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Full-bleed dark header block used at the top of primary-action screens
/// (auth, cart, checkout, profile, courier dashboard) — the visual signature
/// of the Delivery Hassen design.
///
/// It reaches up under the status bar (screens hosting it leave the top
/// unpadded: SafeArea(top: false)), so the black runs to the top edge with
/// white status bar icons on it.
class DarkHeader extends StatelessWidget {
  const DarkHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.backEnabled = true,
    this.trailing,
    this.centered = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  /// False greys the back arrow out (e.g. while a form is sending) without
  /// removing it, so the title doesn't jump.
  final bool backEnabled;
  final Widget? trailing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.paddingOf(context).top;
    final titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );

    final titleBlock = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (!centered)
              Expanded(child: Text(title, style: titleStyle))
            else
              Text(title, style: titleStyle),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarOnDark,
      child: Container(
        width: double.infinity,
        color: navy,
        padding: EdgeInsets.fromLTRB(
          onBack != null ? 12 : 24,
          statusBar + 28,
          24,
          24,
        ),
        // The back arrow sits on the title's line, the subtitle under the
        // title.
        child: onBack == null
            ? titleBlock
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Centered on the title line (24 px), not on title and
                  // subtitle together: the 48 px button is pulled up 10 px.
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: IconButton(
                      onPressed: backEnabled ? onBack : null,
                      tooltip: 'Retour',
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      icon: const Icon(Icons.arrow_back, size: 22),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: titleBlock),
                ],
              ),
      ),
    );
  }
}
