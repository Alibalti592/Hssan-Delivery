import 'package:flutter/material.dart';

import 'deliveries/delivery.dart';

const _seed = Color(0xFF00696E);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

/// Colour used for a status chip / accent, resolved against the scheme.
Color statusColor(DeliveryStatus status, ColorScheme scheme) {
  switch (status) {
    case DeliveryStatus.delivered:
      return const Color(0xFF2E7D32);
    case DeliveryStatus.failed:
    case DeliveryStatus.cancelled:
      return scheme.error;
    case DeliveryStatus.onTheWay:
    case DeliveryStatus.pickedUp:
      return const Color(0xFF1565C0);
    case DeliveryStatus.assigned:
    case DeliveryStatus.accepted:
      return const Color(0xFFB26A00);
    case DeliveryStatus.pending:
      return scheme.outline;
  }
}
