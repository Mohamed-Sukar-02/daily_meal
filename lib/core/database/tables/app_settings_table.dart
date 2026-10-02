import 'package:drift/drift.dart';

enum AppThemeModePreference {
  system,
  light,
  dark,
}

enum AppLanguagePreference {
  ar,
  en,
}

enum RecommendationSource {
  vault_only,
  vault_plus_discovery,
}

@DataClassName('AppSettingsData')
class AppSettings extends Table {
  // Singleton pattern with fixed primary key id = 1
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get cooldownDays => integer().withDefault(const Constant(14))();
  IntColumn get chickenCooldownDays => integer().withDefault(const Constant(2))();
  IntColumn get beefCooldownDays => integer().withDefault(const Constant(2))();
  IntColumn get fishCooldownDays => integer().withDefault(const Constant(4))();
  IntColumn get meatlessCooldownDays => integer().withDefault(const Constant(0))();
  IntColumn get notificationHour => integer().withDefault(const Constant(12))();
  IntColumn get notificationMinute => integer().withDefault(const Constant(0))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get themeMode => textEnum<AppThemeModePreference>().withDefault(const Constant('system'))();
  TextColumn get language => textEnum<AppLanguagePreference>().withDefault(const Constant('ar'))();
  BoolColumn get isFirstRun => boolean().withDefault(const Constant(true))();
  TextColumn get recommendationSource => textEnum<RecommendationSource>().withDefault(const Constant('vault_only'))();
  BoolColumn get autoFridayFeastFilter => boolean().withDefault(const Constant(false))();
  TextColumn get userName => text().nullable()();
  TextColumn get userEmail => text().nullable()();
  TextColumn get userGender => text().nullable()(); // 'male' or 'female'
  TextColumn get userAvatar => text().nullable()(); // asset path

  @override
  Set<Column> get primaryKey => {id};
}
