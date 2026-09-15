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

@DataClassName('AppSettingsData')
class AppSettings extends Table {
  // Singleton pattern with fixed primary key id = 1
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get cooldownDays => integer().withDefault(const Constant(14))();
  IntColumn get chickenCooldownDays => integer().withDefault(const Constant(7))();
  IntColumn get beefCooldownDays => integer().withDefault(const Constant(10))();
  IntColumn get fishCooldownDays => integer().withDefault(const Constant(5))();
  IntColumn get meatlessCooldownDays => integer().withDefault(const Constant(0))();
  BoolColumn get preventRepeatProtein => boolean().withDefault(const Constant(true))();
  BoolColumn get preventRepeatCarbs => boolean().withDefault(const Constant(true))();
  IntColumn get notificationHour => integer().withDefault(const Constant(12))();
  IntColumn get notificationMinute => integer().withDefault(const Constant(0))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get themeMode => textEnum<AppThemeModePreference>().withDefault(const Constant('system'))();
  TextColumn get language => textEnum<AppLanguagePreference>().withDefault(const Constant('ar'))();
  BoolColumn get isFirstRun => boolean().withDefault(const Constant(true))();
  TextColumn get userName => text().nullable()();
  TextColumn get userEmail => text().nullable()();
  TextColumn get userGender => text().nullable()(); // 'male' or 'female'
  TextColumn get userAvatar => text().nullable()(); // asset path

  @override
  Set<Column> get primaryKey => {id};
}
