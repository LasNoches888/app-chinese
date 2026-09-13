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

  /// Light-mode surfaces, from style #1 ("Светлый и дружелюбный"): plain
  /// white cards on the pale blue canvas, with a ladder of barely-blue
  /// tints for the tinted tiles and inset rows above them.
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceLightHigh = Color(0xFFE9F1FB);
  static const outlineLight = Color(0xFFD9E5F3);
  static const inkLight = Color(0xFF0F1A3A);
  static const inkLightSoft = Color(0xFF5A6B88);

  /// Dark mode is style #2 ("Тёмная / ночной режим"), which is a deep
  /// **navy**, not the neutral near-black this used to be — the whole
  /// point of that panel is that night mode stays the same blue brand
  /// rather than draining to grey. Sampled from the mockup: canvas
  /// #061B3C, sidebar a shade under it, cards and raised tiles two steps
  /// above.
  static const backgroundDark = Color(0xFF061B3C);
  static const surfaceDark = Color(0xFF0E2549);
  static const surfaceDarkHigh = Color(0xFF16305C);
  static const sidebarDark = Color(0xFF051837);
  static const outlineDark = Color(0xFF1F3C6B);
  static const inkDark = Color(0xFFE8EEF9);
  static const inkDarkSoft = Color(0xFF9FB2D0);

  /// The active sidebar/nav pill in both panels: a wash of the primary
  /// blue, with the blue itself as the label colour.
  static const pillLight = Color(0xFFE8F3FE);
  static const pillDark = Color(0xFF14315F);
  static const onPillDark = Color(0xFF9DC6FF);
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
    // Blue is the mockup's actual primary interactive color (the main
    // button, the active nav icon, links) — purple is only a secondary
    // accent there. Seeding on blue and then pinning primary/secondary/
    // tertiary to the exact sampled hexes (rather than trusting Material's
    // tonal derivation to land on them) is what makes buttons/nav render
    // that same blue instead of a purple-tinted derivative of it.
    //
    // The surface ladder is pinned too, for the same reason: Material's
    // tonal derivation from a blue seed lands on a desaturated grey-violet
    // in dark mode, which is exactly the drained look style #2 is not.
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.blue,
          onPrimary: Colors.white,
          secondary: AppColors.green,
          onSecondary: Colors.white,
          tertiary: AppColors.orange,
          onTertiary: Colors.white,
          primaryContainer: isDark ? AppColors.pillDark : AppColors.pillLight,
          onPrimaryContainer: isDark ? AppColors.onPillDark : AppColors.blue,
          surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          onSurface: isDark ? AppColors.inkDark : AppColors.inkLight,
          onSurfaceVariant: isDark
              ? AppColors.inkDarkSoft
              : AppColors.inkLightSoft,
          // Lowest is the sidebar/nav rail; the rest is the card ladder.
          surfaceContainerLowest: isDark
              ? AppColors.sidebarDark
              : AppColors.surfaceLight,
          surfaceContainerLow: isDark
              ? AppColors.surfaceDark
              : const Color(0xFFF7FAFE),
          surfaceContainer: isDark
              ? AppColors.surfaceDark
              : const Color(0xFFF2F7FD),
          surfaceContainerHigh: isDark
              ? AppColors.surfaceDarkHigh
              : const Color(0xFFEDF4FC),
          surfaceContainerHighest: isDark
              ? AppColors.surfaceDarkHigh
              : AppColors.surfaceLightHigh,
          outlineVariant: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        );

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
      scaffoldBackgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      // Both panels show the header sitting flat on the canvas rather than
      // on a card of its own — without this, M3 tints the bar with its
      // elevation overlay and it reads as a separate slab.
      canvasColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
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
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.sidebarDark
            : AppColors.surfaceLight,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
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
