import 'package:flutter/material.dart';

/// Centralized brand palette. Every screen that used to hardcode one of
/// these as a local `const Color(0xFF...)` imports this instead — the
/// values themselves are unchanged from what was already scattered across
/// the app, this just gives them one home so "the brand purple" means one
/// thing instead of N copy-pasted literals that can drift apart.
class AppColors {
  AppColors._();

  static const purple = Color(0xFF6C5CE7);
  static const orange = Color(0xFFFF7A59);
  static const green = Color(0xFF23C58F);
  static const greenDark = Color(0xFF17A673);
  static const blue = Color(0xFF4E7CFF);
  static const amber = Color(0xFFFFB03A);

  static const backgroundLight = Color(0xFFF5F6FA);
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

  static const _buttonRadius = 14.0;
  static const _cardRadius = 16.0;

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
