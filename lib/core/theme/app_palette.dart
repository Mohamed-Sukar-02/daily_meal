import 'package:flutter/material.dart';

/// Design tokens extracted from the approved UI mockups
/// (`home page - light.png` / `home page - dark.png`).
///
/// This is the single source of truth for colour in the app. The legacy
/// `app_colors.dart` index (green/coral Material seed) was removed together
/// with the terracotta/saffron seed theme – every screen now reads its colours
/// from here so light & dark stay pixel-consistent with the mockups.
class AppPalette {
  AppPalette._();

  // ---------------------------------------------------------------------------
  // Brand accents (shared by both modes)
  // ---------------------------------------------------------------------------
  static const Color brandGreen = Color(0xFF17C97B);
  static const Color brandGreenDeep = Color(0xFF0FB96C);
  static const Color brandCoral = Color(0xFFF0705A);
  static const Color heartCoral = Color(0xFFF2555A);
  static const Color sparkOrange = Color(0xFFF5A623);

  // ---------------------------------------------------------------------------
  // Light mode
  // ---------------------------------------------------------------------------
  static const Color lightBg = Color(0xFFF4F6FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF16283B);
  static const Color lightTextSecondary = Color(0xFF7B8794);
  static const Color lightTabContainer = Color(0xFFE9EDF3);
  static const Color lightHairline = Color(0xFFE4E9F0);
  static const Color lightOutline = Color(0xFFD9DFE8);
  static const Color lightNavBg = Color(0xFFFBFCFE);
  static const Color lightNavIdle = Color(0xFF6E7885);
  static const Color lightAvatarBg = Color(0xFFDDE4EE);
  static const Color lightAvatarFg = Color(0xFF5A6B81);

  // ---------------------------------------------------------------------------
  // Dark mode
  // ---------------------------------------------------------------------------
  static const Color darkBg = Color(0xFF0B0E14);
  static const Color darkCard = Color(0xFF151B23);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8A93A6);
  static const Color darkTabContainer = Color(0xFF1A212B);
  static const Color darkHairline = Color(0xFF1E2530);
  static const Color darkOutline = Color(0xFF2A3140);
  static const Color darkNavBg = Color(0xFF10151C);
  static const Color darkNavIdle = Color(0xFF7C8698);
  static const Color darkAvatarBg = Color(0xFF262D3A);
  static const Color darkAvatarFg = Color(0xFFC7CEDA);

  // ---------------------------------------------------------------------------
  // Mode-aware getters
  // ---------------------------------------------------------------------------
  static Color background(Brightness b) =>
      b == Brightness.dark ? darkBg : lightBg;

  static Color card(Brightness b) => b == Brightness.dark ? darkCard : lightCard;

  static Color textPrimary(Brightness b) =>
      b == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(Brightness b) =>
      b == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color tabContainer(Brightness b) =>
      b == Brightness.dark ? darkTabContainer : lightTabContainer;

  static Color hairline(Brightness b) =>
      b == Brightness.dark ? darkHairline : lightHairline;

  static Color outline(Brightness b) =>
      b == Brightness.dark ? darkOutline : lightOutline;

  static Color navBackground(Brightness b) =>
      b == Brightness.dark ? darkNavBg : lightNavBg;

  static Color navIdle(Brightness b) =>
      b == Brightness.dark ? darkNavIdle : lightNavIdle;

  static Color avatarBackground(Brightness b) =>
      b == Brightness.dark ? darkAvatarBg : lightAvatarBg;

  static Color avatarForeground(Brightness b) =>
      b == Brightness.dark ? darkAvatarFg : lightAvatarFg;

  /// The primary call-to-action ("Cook This") is green in dark mode and
  /// coral in light mode – exactly as in the mockups.
  static Gradient ctaGradient(Brightness b) => b == Brightness.dark
      ? const LinearGradient(
          colors: [Color(0xFF1FD487), brandGreenDeep],
        )
      : const LinearGradient(
          colors: [Color(0xFFF58A63), brandCoral],
        );

  // ---------------------------------------------------------------------------
  // Meta chips (protein = rose, time = gold, category = violet)
  // ---------------------------------------------------------------------------
  static ChipStyle chipRose(Brightness b) => b == Brightness.dark
      ? const ChipStyle(background: Color(0xFF46242E), foreground: Color(0xFFF27D95))
      : const ChipStyle(background: Color(0xFFFBE3E5), foreground: Color(0xFFD25565));

  static ChipStyle chipGold(Brightness b) => b == Brightness.dark
      ? const ChipStyle(background: Color(0xFF4A3B14), foreground: Color(0xFFE9B33C))
      : const ChipStyle(background: Color(0xFFFBF3D2), foreground: Color(0xFFA07D1C));

  static ChipStyle chipViolet(Brightness b) => b == Brightness.dark
      ? const ChipStyle(background: Color(0xFF3A2A57), foreground: Color(0xFFA78BFA))
      : const ChipStyle(background: Color(0xFFE7E1F9), foreground: Color(0xFF6C5CE7));

  static ChipStyle chipGreen(Brightness b) => b == Brightness.dark
      ? const ChipStyle(background: Color(0xFF123B2A), foreground: Color(0xFF4ADE80))
      : const ChipStyle(background: Color(0xFFDCF2E7), foreground: Color(0xFF0E6B4A));

  // ---------------------------------------------------------------------------
  // Bottom action-bar pills
  // ---------------------------------------------------------------------------
  static PillStyle leftoverPill(Brightness b) => b == Brightness.dark
      ? const PillStyle(
          background: Color(0xFF1B242C),
          icon: brandGreen,
          text: Color(0xFFE8EDF4),
        )
      : const PillStyle(
          background: Color(0xFFDCF2E7),
          icon: Color(0xFF12A86B),
          text: Color(0xFF0E6B4A),
        );

  static PillStyle deliveryPill(Brightness b) => b == Brightness.dark
      ? const PillStyle(
          background: Color(0xFF262C45),
          icon: Color(0xFF8B93F8),
          text: Color(0xFF8B93F8),
        )
      : const PillStyle(
          background: Color(0xFFDEE8FB),
          icon: Color(0xFF3E63DD),
          text: Color(0xFF3E63DD),
        );

  // ---------------------------------------------------------------------------
  // Spin-the-wheel rainbow
  // ---------------------------------------------------------------------------
  static const List<Color> wheelRainbow = [
    Color(0xFFF2555A),
    Color(0xFFF59E0B),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];
}

/// Background + foreground pair used by the small meta chips.
class ChipStyle {
  final Color background;
  final Color foreground;

  const ChipStyle({required this.background, required this.foreground});
}

/// Background + icon/text colours used by the action-bar pills.
class PillStyle {
  final Color background;
  final Color icon;
  final Color text;

  const PillStyle({
    required this.background,
    required this.icon,
    required this.text,
  });
}
