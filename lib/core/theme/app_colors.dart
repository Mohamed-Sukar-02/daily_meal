import 'package:flutter/material.dart';

import '../database/tables/meals_table.dart';

/// Centralized color constants extracted from reference UI designs.
class AppColors {
  AppColors._();

  // --- Light Theme Colors ---
  static const Color lightBackground = Color(0xFFF0F4F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1B9B7D);
  static const Color lightPrimaryDark = Color(0xFF16805E);
  static const Color lightAccentCoral = Color(0xFFF97066);
  static const Color lightTextPrimary = Color(0xFF1A2332);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightBorder = Color(0xFFE5E7EB);

  // --- Dark Theme Colors ---
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkPrimary = Color(0xFF1B9B7D);
  static const Color darkTextPrimary = Color(0xFFE6EDF3);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkBorder = Color(0xFF30363D);

  // --- Chip Colors (Light Mode Base) ---
  static const Color chipPinkBg = Color(0xFFFDEAEA);
  static const Color chipPinkText = Color(0xFFE85D5D);
  
  static const Color chipYellowBg = Color(0xFFFFF8E1);
  static const Color chipYellowText = Color(0xFFD4930D);
  
  static const Color chipPurpleBg = Color(0xFFF3E8FF);
  static const Color chipPurpleText = Color(0xFF7C3AED);
  
  static const Color chipGreenBg = Color(0xFFE8F5E9);
  static const Color chipGreenText = Color(0xFF2E7D32);

  // --- Helpers for dynamic colors ---
  static Color getProteinBgColor(ProteinType type, bool isDark) {
    if (isDark) {
      switch (type) {
        case ProteinType.beef:
        case ProteinType.chicken:
          return const Color(0xFF3B1A1A);
        case ProteinType.fish:
          return const Color(0xFF1A2B3B);
        default:
          return const Color(0xFF1A3B22);
      }
    } else {
      switch (type) {
        case ProteinType.beef:
        case ProteinType.chicken:
          return chipPinkBg;
        case ProteinType.fish:
          return const Color(0xFFE3F2FD);
        default:
          return chipGreenBg;
      }
    }
  }

  static Color getProteinTextColor(ProteinType type, bool isDark) {
    if (isDark) {
      switch (type) {
        case ProteinType.beef:
        case ProteinType.chicken:
          return const Color(0xFFEF9A9A);
        case ProteinType.fish:
          return const Color(0xFF90CAF9);
        default:
          return const Color(0xFFA5D6A7);
      }
    } else {
      switch (type) {
        case ProteinType.beef:
        case ProteinType.chicken:
          return chipPinkText;
        case ProteinType.fish:
          return const Color(0xFF1565C0);
        default:
          return chipGreenText;
      }
    }
  }

  static String getProteinEmoji(ProteinType type) {
    switch (type) {
      case ProteinType.chicken:
        return '🐔';
      case ProteinType.beef:
        return '🥩';
      case ProteinType.fish:
        return '🐟';
      case ProteinType.legume:
        return '🫘';
      case ProteinType.dairy:
        return '🧀';
      case ProteinType.none:
        return '🥗';
    }
  }

  static IconData getCategoryIcon(MealCategory category) {
    switch (category) {
      case MealCategory.egyptianTraditional:
        return Icons.soup_kitchen;
      case MealCategory.ovenBaked:
        return Icons.microwave;
      case MealCategory.fastFood:
        return Icons.fastfood;
      case MealCategory.seafood:
        return Icons.set_meal;
      case MealCategory.soupStew:
        return Icons.ramen_dining;
      case MealCategory.vegetarian:
        return Icons.eco;
    }
  }
}
