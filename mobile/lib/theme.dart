import 'package:flutter/material.dart';

import 'deliveries/delivery.dart';

/// Brand navy from the Delivery Hassen design. Used as the seed and as a
/// literal accent (splash/login background, primary buttons, active icons).
const navy = Color(0xFF10213A);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: navy, brightness: brightness);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF2F4F7)
        : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Colour used for a status chip / accent, resolved against the scheme.
Color statusColor(DeliveryStatus status, ColorScheme scheme) {
  switch (status) {
    case DeliveryStatus.delivered:
      return const Color(0xFF2E7D52);
    case DeliveryStatus.failed:
    case DeliveryStatus.cancelled:
      return scheme.error;
    case DeliveryStatus.onTheWay:
    case DeliveryStatus.pickedUp:
    case DeliveryStatus.accepted:
      return navy;
    case DeliveryStatus.assigned:
      return const Color(0xFFC98A2C);
    case DeliveryStatus.pending:
      return scheme.outline;
  }
}
