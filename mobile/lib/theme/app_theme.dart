import 'package:flutter/material.dart';

/// Centralized brand palette. Every screen that used to hardcode one of
/// these as a local `const Color(0xFF...)` imports this instead.
///
/// Values are sampled pixel-for-pixel from the "Палитра" swatch panel in
/// the user's style mockup (not eyeballed/approximated), so this *is* that
/// palette rather than something merely close to it. `greenDark` and
/// `amber` have no swatch of their own in the mockup — they're derived
/// from `green`/`orange` the same way the app's previous palette related
/// its own dark-green and amber shades to its base green/orange.
class AppColors {
  AppColors._();

  static const blue = Color(0xFF4B93FD);
  static const green = Color(0xFF53CD82);
  static const orange = Color(0xFFFDA14D);
  static const purple = Color(0xFF927CEE);
  static const greenDark = Color(0xFF42A468);
  static const amber = Color(0xFFFFBE5A);

  /// The mockup's two neutral swatches — not yet wired into any screen
  /// (Material 3's seed-derived outline/surface tones already cover most
  /// of that role), kept here so they're available without re-sampling.
  static const grey = Color(0xFFC1D3E7);
  static const greyDark = Color(0xFF8094B1);

  static const backgroundLight = Color(0xFFEDF5FB);
  static const backgroundDark = Color(0xFF14141F);
}

/// Builds the app's light/dark [ThemeData] from [AppColors] — the one place
/// font, type scale, and button/card shapes are defined. Replaces the old
/// inline `colorSchemeSeed`-only theme in `main.dart`, which set no text
/// theme, no button theme, and no card theme at all.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  // The mockup's primary button reads as close to a full pill (radius on
  // the order of half its height) rather than a lightly-rounded rectangle.
  static const _buttonRadius = 24.0;
  static const _cardRadius = 18.0;

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.purple,
          brightness: brightness,
        ).copyWith(secondary: AppColors.green, tertiary: AppColors.orange);

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Inter',
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonRadius),
    );
    const buttonPadding = EdgeInsets.symmetric(
      vertical: 14,
      horizontal: 20,
    );
    const buttonTextStyle = TextStyle(fontWeight: FontWeight.w600);

    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.light
          ? AppColors.backgroundLight
          : AppColors.backgroundDark,
      // Mirrors the mockup's type scale: Bold 24 headings, Semibold 16
      // subheadings, Regular 14 body, Medium 14 labels/buttons.
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          height: 32 / 24,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          height: 24 / 16,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 20 / 14,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          height: 20 / 14,
        ),
      ),
      // Material's zoom transition animates both the incoming and outgoing
      // route, so pushing a new screen fades/scales in instead of snapping.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: buttonTextStyle,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
