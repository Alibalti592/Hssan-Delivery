import 'package:flutter/material.dart';

import '../theme.dart';

/// A calm full-screen message (nothing found, nothing yet, couldn't load)
/// that always offers a way forward when there is one.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.detail,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.primaryAction = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// A filled button (the next step) rather than an outlined one (a retry).
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: fieldFill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: navy),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: mutedText),
              ),
            ],
            if (label != null && onAction != null) ...[
              const SizedBox(height: 20),
              primaryAction
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.arrow_forward),
                      label: Text(label),
                    )
                  : OutlinedButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.refresh),
                      label: Text(label),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
