import 'package:flutter/material.dart';

import 'deliveries/delivery.dart';

/// Brand black from the Delivery Hassen logo (silver monogram on black).
/// Used as the seed and as a literal accent (splash/login/dark-header
/// background, primary buttons, active icons). Kept as `navy` rather than
/// renamed — it's referenced across a dozen screens as "the brand color".
const navy = Color(0xFF000000);

/// Status palette shared by delivery and order status chips.
const successText = Color(0xFF276749);
const successBg = Color(0xFFE8F3EC);
const dangerText = Color(0xFF9B2C2C);
const dangerBg = Color(0xFFF7EAEA);
const warnText = Color(0xFF9C4221);
const warnBg = Color(0xFFFDF1E4);

/// Muted text / field-fill tokens used across cards and form fields.
const mutedText = Color(0xFF8B93A0);
const fieldFill = Color(0xFFEAF0F7);
const cardBorder = Color(0xFFEDF0F4);

ThemeData buildTheme(Brightness brightness) {
  // ColorScheme.fromSeed(seedColor: Colors.black) doesn't stay neutral —
  // Material 3's tonal palette algorithm falls back to a low-chroma pink/
  // mauve hue for a seed with no real chroma of its own, which then leaks
  // into anything using colorScheme.primary/surfaceContainerHighest/outline
  // (filled buttons, image placeholders). Override those roles with true
  // black/white/gray so the "black and white" brand actually stays neutral.
  final seeded = ColorScheme.fromSeed(seedColor: navy, brightness: brightness);
  final scheme = brightness == Brightness.light
      ? seeded.copyWith(
          primary: navy,
          onPrimary: Colors.white,
          secondary: const Color(0xFF4A4A4A),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFEDEDED),
          onSecondaryContainer: navy,
          surface: Colors.white,
          onSurface: navy,
          surfaceContainerHighest: const Color(0xFFEDEDED),
          outline: const Color(0xFFBDBDBD),
        )
      : seeded.copyWith(
          primary: Colors.white,
          onPrimary: navy,
          secondary: const Color(0xFFBDBDBD),
          onSecondary: navy,
          secondaryContainer: const Color(0xFF2A2A2A),
          onSecondaryContainer: Colors.white,
          surface: const Color(0xFF121212),
          onSurface: Colors.white,
          surfaceContainerHighest: const Color(0xFF2A2A2A),
          outline: const Color(0xFF5A5A5A),
        );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: brightness == Brightness.light
        ? Colors.white
        : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: navy, width: 1.2),
        foregroundColor: navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: cardBorder),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: fieldFill,
      labelStyle: const TextStyle(
        color: Color(0xFF6B7787),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : mutedText,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : mutedText,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: navy, width: 1.4),
      ),
      labelStyle: const TextStyle(color: mutedText),
    ),
  );
}

/// Colour used for a status chip / accent, resolved against the scheme.
Color statusColor(DeliveryStatus status, ColorScheme scheme) {
  switch (status) {
    case DeliveryStatus.delivered:
      return successText;
    case DeliveryStatus.failed:
    case DeliveryStatus.cancelled:
      return dangerText;
    case DeliveryStatus.onTheWay:
    case DeliveryStatus.pickedUp:
    case DeliveryStatus.accepted:
      return warnText;
    case DeliveryStatus.assigned:
      return warnText;
    case DeliveryStatus.pending:
      return scheme.outline;
  }
}

/// Background tint paired with [statusColor], matching the badge palette.
Color statusBgColor(DeliveryStatus status) {
  switch (status) {
    case DeliveryStatus.delivered:
      return successBg;
    case DeliveryStatus.failed:
    case DeliveryStatus.cancelled:
      return dangerBg;
    case DeliveryStatus.onTheWay:
    case DeliveryStatus.pickedUp:
    case DeliveryStatus.accepted:
    case DeliveryStatus.assigned:
      return warnBg;
    case DeliveryStatus.pending:
      return const Color(0xFFEDF0F4);
  }
}
