import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Locale;

import '../../localization/app_strings.dart';

enum ProteinType {
  chicken, // فراخ / دواجن
  beef, // لحمة / مفروم
  fish, // أسماك / مأكولات بحرية
  legume, // بقوليات (كشري، عدس، فول)
  dairy, // بيض / أجبان
  none, // بدون بروتين
}

enum CarbsType {
  rice, // أرز
  pasta, // مكرونة
  bread, // عيش
  potato, // بطاطس
  grains, // فريك / برغل
  none, // بدون نشويات
}

enum MealCategory {
  egyptianTraditional, // أكلات شعبية وطبيخ
  ovenBaked, // صواني وطواجن فرن
  fastFood, // سندوتشات وسريع
  seafood, // أسماك وبحريات
  soupStew, // شوربات ويخنات
  vegetarian, // قرديحي / نباتي
}

class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get nameNormalized => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get proteinType => textEnum<ProteinType>()();
  TextColumn get carbsType => textEnum<CarbsType>()();
  TextColumn get category => textEnum<MealCategory>()();
  IntColumn get prepTime => integer()(); // in minutes
  BoolColumn get isFridaySpecial => boolean().withDefault(const Constant(false))();
  BoolColumn get isBudgetFriendly => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarterMeal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get cloudId => text().nullable()();
  IntColumn get customCooldownDays => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get shortName => text().nullable()();
}

extension ProteinTypeX on ProteinType {
  /// Localised display label. Display copy lives in [AppStrings] so switching
  /// the app language updates every chip/badge without touching the data layer.
  String label(AppStrings strings) => strings.proteinLabel(name);

  /// Arabic label kept for callers that do not have a locale at hand
  /// (seed data, debug logs, legacy tests).
  String get labelArabic => label(const AppStrings(Locale('ar')));

  /// Emoji used by the vault / history badges (matches the mockups).
  String get emoji {
    switch (this) {
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
}

extension CarbsTypeX on CarbsType {
  /// Localised display label (see [AppStrings.carbsLabel]).
  String label(AppStrings strings) => strings.carbsLabel(name);

  String get labelArabic => label(const AppStrings(Locale('ar')));
}

extension MealCategoryX on MealCategory {
  /// Localised display label (see [AppStrings.categoryLabel]).
  String label(AppStrings strings) => strings.categoryLabel(name);

  String get labelArabic => label(const AppStrings(Locale('ar')));
}
