import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Locale;

import '../../localization/app_strings.dart';
import 'meals_table.dart';

enum MealEntryType {
  cooked, // طبخة جديدة
  leftover, // بواقي أكل
  takeout, // تيك أواي
  skipped, // سكيب (أكلنا بره أو مش هنتغدى)
}

class MealHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Nullable foreign key: on meal deletion, set to null to preserve history log
  IntColumn get mealId => integer().nullable().customConstraint('REFERENCES meals(id) ON DELETE SET NULL')();
  // Snapshot columns to preserve historical facts even if the meal is deleted
  TextColumn get mealName => text().withLength(min: 1, max: 120)();
  TextColumn get proteinType => textEnum<ProteinType>()();
  TextColumn get carbsType => textEnum<CarbsType>()();
  DateTimeColumn get cookedAt => dateTime()();
  TextColumn get entryType => textEnum<MealEntryType>().withDefault(const Constant('cooked'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

extension MealEntryTypeX on MealEntryType {
  /// Localised display label (see [AppStrings.entryTypeLabel]).
  String label(AppStrings strings) => strings.entryTypeLabel(name);

  String get labelArabic => label(const AppStrings(Locale('ar')));
}
