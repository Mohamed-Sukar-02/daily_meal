import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Material 3 theme for 'أكلة النهاردة', driven 100% by [AppPalette]
/// (tokens sampled from the approved light/dark mockups).
///
/// The colour schemes are declared explicitly (no `ColorScheme.fromSeed`) so
/// every Material widget – sliders, switches, dialogs, snack-bars – renders
/// with the mockup colours instead of a generated tonal palette.
class AppTheme {
  AppTheme._();

  /// Deep-gray dark ramp matching the mockup backgrounds
  /// (`#0B0E14` page on `#151B23` cards). Ordered by rising luminance.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.brandGreen,
    onPrimary: Color(0xFF04140C),
    primaryContainer: Color(0xFF0E3B2A),
    onPrimaryContainer: Color(0xFFB8F5D8),
    secondary: Color(0xFF8B93F8),
    onSecondary: Color(0xFF14183F),
    secondaryContainer: Color(0xFF262C45),
    onSecondaryContainer: Color(0xFFD6DBFF),
    tertiary: Color(0xFFE9B33C),
    onTertiary: Color(0xFF3A2A08),
    tertiaryContainer: Color(0xFF4A3B14),
    onTertiaryContainer: Color(0xFFFBE7B5),
    error: Color(0xFFF2555A),
    onError: Color(0xFF3B0708),
    errorContainer: Color(0xFF46242E),
    onErrorContainer: Color(0xFFFFD9DE),
    surface: Color(0xFF10151C),
    onSurface: Color(0xFFFFFFFF),
    surfaceDim: Color(0xFF0B0E14),
    surfaceBright: Color(0xFF2A3340),
    surfaceContainerLowest: Color(0xFF080B10),
    surfaceContainerLow: Color(0xFF151B23),
    surfaceContainer: Color(0xFF1B222C),
    surfaceContainerHigh: Color(0xFF212936),
    surfaceContainerHighest: Color(0xFF2A3340),
    onSurfaceVariant: Color(0xFFAEB6C4),
    outline: Color(0xFF2A3140),
    outlineVariant: Color(0xFF1E2530),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE8EDF4),
    onInverseSurface: Color(0xFF10151C),
    inversePrimary: Color(0xFF0FB96C),
  );

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.brandGreen,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCF2E7),
    onPrimaryContainer: Color(0xFF0E6B4A),
    secondary: AppPalette.brandCoral,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFBE3E5),
    onSecondaryContainer: Color(0xFF8A3324),
    tertiary: Color(0xFF6C5CE7),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE7E1F9),
    onTertiaryContainer: Color(0xFF4436A8),
    error: Color(0xFFD25565),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBE3E5),
    onErrorContainer: Color(0xFF8A2733),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF16283B),
    surfaceDim: Color(0xFFE4E9F0),
    surfaceBright: Color(0xFFFBFCFE),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF4F6FA),
    surfaceContainer: Color(0xFFEDF1F6),
    surfaceContainerHigh: Color(0xFFE9EDF3),
    surfaceContainerHighest: Color(0xFFDDE4EE),
    onSurfaceVariant: Color(0xFF7B8794),
    outline: Color(0xFFD9DFE8),
    outlineVariant: Color(0xFFE4E9F0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF16283B),
    onInverseSurface: Color(0xFFF4F6FA),
    inversePrimary: Color(0xFF17C97B),
  );

  static ThemeData get lightTheme => _build(_lightColorScheme);

  static ThemeData get darkTheme => _build(darkColorScheme);

  static ThemeData _build(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final baseTextTheme = ThemeData(
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: GoogleFonts.cairoTextTheme(baseTextTheme),
      scaffoldBackgroundColor: AppPalette.background(colorScheme.brightness),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: AppPalette.background(colorScheme.brightness),
        foregroundColor: AppPalette.textPrimary(colorScheme.brightness),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.card(colorScheme.brightness),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.tabContainer(colorScheme.brightness),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppPalette.brandGreen,
        inactiveTrackColor: AppPalette.outline(colorScheme.brightness),
        thumbColor: AppPalette.brandGreen,
        overlayColor: AppPalette.brandGreen.withValues(alpha: 0.15),
        trackHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : AppPalette.navIdle(colorScheme.brightness)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppPalette.brandGreen
                : AppPalette.outline(colorScheme.brightness)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.card(colorScheme.brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.cairo(
          color: isDark ? colorScheme.onSurface : colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppPalette.hairline(colorScheme.brightness),
        thickness: 1,
      ),
    );
  }
}
