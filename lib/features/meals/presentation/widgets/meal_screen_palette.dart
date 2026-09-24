import 'package:flutter/material.dart';

/// Colours locked to the Meal Screen mockups
/// (`meal_screen - light.png` / `meal_screen - dark.png`).
///
/// Kept separate from [AppPalette] so the rest of the app is untouched while
/// this screen stays pixel-faithful to the reference.
class MealScreenPalette {
  MealScreenPalette._();

  // ── Light ──────────────────────────────────────────────────────────────
  static const Color lightHeader = Color(0xFF1B5E3B);
  static const Color lightHeaderDeep = Color(0xFF0F3D28);
  static const Color lightInfoCard = Color(0xFF1A5C40);
  static const Color lightInfoCardDeep = Color(0xFF144A34);
  static const Color lightBody = Color(0xFFF6F1E8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE8E2D6);
  static const Color lightText = Color(0xFF1A2E28);
  static const Color lightMuted = Color(0xFF7A8B82);
  static const Color lightAccent = Color(0xFF1B8A5A);
  static const Color lightTag = Color(0xFF2D9B6C);
  static const Color lightTabIdle = Color(0xFF5C6B64);
  static const Color lightBottomBar = Color(0xFF1B5E3B);

  // ── Dark ───────────────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0B1210);
  static const Color darkHeader = Color(0xFF070D0B);
  static const Color darkInfoCard = Color(0xFF0F3D2E);
  static const Color darkInfoCardDeep = Color(0xFF0A2E22);
  static const Color darkCard = Color(0xFF121C18);
  static const Color darkCardBorder = Color(0xFF1A2A24);
  static const Color darkText = Color(0xFFF2F5F3);
  static const Color darkMuted = Color(0xFF8A9A92);
  static const Color darkAccent = Color(0xFF2E9B6A);
  static const Color darkTag = Color(0xFF3CB371);
  static const Color darkGold = Color(0xFFE0B84C);
  static const Color darkTabBar = Color(0xFF0C1F18);
  static const Color darkBottomBar = Color(0xFF143D30);

  static bool isDark(Brightness b) => b == Brightness.dark;

  static Color background(Brightness b) => isDark(b) ? darkBg : lightBody;
  static Color header(Brightness b) => isDark(b) ? darkHeader : lightHeader;
  static Color infoCard(Brightness b) =>
      isDark(b) ? darkInfoCard : lightInfoCard;
  static Color infoCardDeep(Brightness b) =>
      isDark(b) ? darkInfoCardDeep : lightInfoCardDeep;
  static Color card(Brightness b) => isDark(b) ? darkCard : lightCard;
  static Color cardBorder(Brightness b) =>
      isDark(b) ? darkCardBorder : lightCardBorder;
  static Color text(Brightness b) => isDark(b) ? darkText : lightText;
  static Color muted(Brightness b) => isDark(b) ? darkMuted : lightMuted;
  static Color accent(Brightness b) => isDark(b) ? darkAccent : lightAccent;
  static Color tag(Brightness b) => isDark(b) ? darkTag : lightTag;
  static Color tabBar(Brightness b) => isDark(b) ? darkTabBar : lightBody;
  static Color tabIdle(Brightness b) =>
      isDark(b) ? darkMuted : lightTabIdle;
  static Color bottomBar(Brightness b) =>
      isDark(b) ? darkBottomBar : lightBottomBar;
  static Color shortName(Brightness b) =>
      isDark(b) ? darkGold : Colors.white;
  static Color cloud(Brightness b) =>
      isDark(b) ? darkGold : Colors.white;
  static Color fullName(Brightness b) =>
      isDark(b) ? Colors.white.withValues(alpha: 0.92) : Colors.white;
  static Color infoOnGreen(Brightness b) =>
      Colors.white.withValues(alpha: isDark(b) ? 0.95 : 1.0);
  static Color infoOnGreenMuted(Brightness b) =>
      Colors.white.withValues(alpha: isDark(b) ? 0.70 : 0.82);

  // ── Header pill & banner↔tabs interlock (locked to mockups) ───────────
  /// Fill of the short-name header bar at the top of the screen.
  static Color headerBar(Brightness b) =>
      isDark(b) ? const Color(0xFF10251E) : lightHeader;
  static Color headerBarDeep(Brightness b) =>
      isDark(b) ? const Color(0xFF0A1B15) : lightHeaderDeep;
  /// Soft champagne border of the header bar.
  static Color headerBarBorder(Brightness b) =>
      (isDark(b) ? darkGold : Colors.white).withValues(alpha: isDark(b) ? 0.30 : 0.35);
  /// Cream display text inside the header bar.
  static Color headerBarText(Brightness b) =>
      isDark(b) ? const Color(0xFFF0DFAE) : Colors.white;

  /// White-ish outline shared by the info banner and the dish-tab strip —
  /// the mockup's attractive white edges ("حواف بيضاء").
  static Color interlockStroke(Brightness b) => isDark(b)
      ? Colors.white.withValues(alpha: 0.62)
      : lightHeaderDeep.withValues(alpha: 0.45);
}
