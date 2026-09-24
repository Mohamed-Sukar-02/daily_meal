import 'package:flutter/material.dart';

/// Colours locked to the Meal Screen mockups
/// (`meal_screen - dark.png` = structure, `meal_screen - light.png` = which
/// surface gets which tone).
///
/// This green + cream system deliberately overrides the app-wide cool
/// slate/mint [AppPalette]; the rest of the app keeps its own tokens so this
/// screen can stay pixel-faithful to the reference.
///
/// Every value below is sampled from the reference PNGs, not eyeballed.
class MealScreenPalette {
  MealScreenPalette._();

  static bool isDark(Brightness b) => b == Brightness.dark;

  // ── Dark (reference A) ─────────────────────────────────────────────────
  static const Color darkPage = Color(0xFF020B0A);
  static const Color darkCard = Color(0xFF061210);
  static const Color darkAppBar = Color(0xFF05150E);
  static const Color darkBottomPill = Color(0xFF07251B);
  static const Color darkAccent = Color(0xFF8EEFA3);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFCCCCCC);
  static const Color darkHairline = Color(0xFF12332A);
  static const Color darkTabBarTop = Color(0xFF0D3024);
  static const Color darkTabBarBottom = Color(0xFF082219);

  // ── Light (reference B colour distribution) ────────────────────────────
  static const Color lightPage = Color(0xFFF0E7D7); // warm cream
  static const Color lightSheet = Color(0xFFFDF9F3);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightChrome = Color(0xFF336B4C); // forest green
  static const Color lightFooter = Color(0xFFFAF4E7);
  static const Color lightText = Color(0xFF14301F);
  static const Color lightTextSecondary = Color(0xFF6E7F72);
  static const Color lightHairline = Color(0xFFDCE7D8);
  static const Color lightTabStroke = Color(0xFFCFDCCB);

  // ── Shared accents ─────────────────────────────────────────────────────
  static const Color gold = Color(0xFFECB131);

  static Color background(Brightness b) => isDark(b) ? darkPage : lightPage;

  /// The surface the content below the hero sits on. Dark has no separate
  /// sheet, so the grid lands straight on the page colour.
  static Color sheet(Brightness b) => isDark(b) ? darkPage : lightSheet;

  static Color card(Brightness b) => isDark(b) ? darkCard : lightCard;
  static Color cardBorder(Brightness b) =>
      isDark(b) ? darkHairline : lightHairline;
  static Color text(Brightness b) => isDark(b) ? darkText : lightText;
  static Color muted(Brightness b) =>
      isDark(b) ? darkTextSecondary : lightTextSecondary;
  static Color accent(Brightness b) => isDark(b) ? darkAccent : lightChrome;
  static Color tag(Brightness b) => isDark(b) ? darkAccent : lightChrome;
  static Color appBar(Brightness b) => isDark(b) ? darkAppBar : lightChrome;
  static Color bottomPill(Brightness b) =>
      isDark(b) ? darkBottomPill : lightChrome;

  /// Strip the pinned bottom pill rests on.
  static Color footer(Brightness b) => isDark(b) ? darkAppBar : lightFooter;

  static Color heart(Brightness b) =>
      isDark(b) ? const Color(0xFFF26D6D) : const Color(0xFFD6524F);

  /// Sync mark: gold while the meal is only local, accent once published.
  static Color syncIdle(Brightness b) => gold;
  static Color syncDone(Brightness b) => accent(b);

  // ── Info card shell ────────────────────────────────────────────────────
  static Color cardTop(Brightness b) => isDark(b)
      ? const Color(0xFF0C2A20).withValues(alpha: 0.90)
      : const Color(0xFF3A7755);
  static Color cardBottom(Brightness b) => isDark(b)
      ? const Color(0xFF061812).withValues(alpha: 0.95)
      : const Color(0xFF2F6446);
  static Color cardStroke(Brightness b) => isDark(b)
      ? darkAccent.withValues(alpha: 0.22)
      : lightChrome.withValues(alpha: 0.45);
  static Color cardDivider(Brightness b) =>
      Colors.white.withValues(alpha: isDark(b) ? 0.55 : 0.50);
  static Color cardText(Brightness b) => Colors.white;
  static Color cardSub(Brightness b) =>
      Colors.white.withValues(alpha: isDark(b) ? 0.82 : 0.80);

  // ── Dish tab strip ─────────────────────────────────────────────────────
  static Color tabBarTop(Brightness b) => isDark(b) ? darkTabBarTop : lightCard;
  static Color tabBarBottom(Brightness b) =>
      isDark(b) ? darkTabBarBottom : lightCard;
  static Color tabStroke(Brightness b) => isDark(b)
      ? const Color(0xFFA5FFC0).withValues(alpha: 0.30)
      : lightTabStroke;
  static Color tabActiveText(Brightness b) => accent(b);
  static Color tabInactiveText(Brightness b) => muted(b);

  // ── Hero name scrim ────────────────────────────────────────────────────
  /// Tint colour of the soft bloom behind the full meal name.
  static Color scrim(Brightness b) => isDark(b) ? darkPage : lightSheet;

  /// Opacity of the bloom directly under the glyphs.
  static double scrimPeak(Brightness b) => isDark(b) ? 0.72 : 0.78;

  static Color fullName(Brightness b) => text(b);
}
