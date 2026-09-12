import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-bleed dark header block used at the top of primary-action screens
/// (auth, cart, checkout, profile, courier dashboard) — the visual signature
/// of the Delivery Hassen design.
class DarkHeader extends StatelessWidget {
  const DarkHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.centered = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: navy,
      padding: EdgeInsets.fromLTRB(24, onBack != null ? 14 : 28, 24, 24),
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
            ),
          Row(
            mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (!centered)
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (trailing != null) trailing!,
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
      ),
    );
  }
}
