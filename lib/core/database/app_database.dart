import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/meals_table.dart';
import 'tables/meal_history_table.dart';
import 'tables/app_settings_table.dart';
import 'daos/meals_dao.dart';
import 'daos/meal_history_dao.dart';
import 'daos/app_settings_dao.dart';
import 'seed/initial_meals.dart';
import '../utils/arabic_normalizer.dart';

export 'tables/meals_table.dart';
export 'tables/meal_history_table.dart';
export 'tables/app_settings_table.dart';
export 'daos/meals_dao.dart';
export 'daos/meal_history_dao.dart';
export 'daos/app_settings_dao.dart';
export 'seed/initial_meals.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Meals, MealHistory, AppSettings],
  daos: [MealsDao, MealHistoryDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? driftDatabase(name: 'daily_meal_db'));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();

      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_meal_id ON meal_history (meal_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_cooked_at ON meal_history (cooked_at DESC)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name ON meals (name)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name_normalized ON meals (name_normalized)');

      await into(appSettings).insert(
        const AppSettingsCompanion(
          id: Value(1),
          cooldownDays: Value(14),
          chickenCooldownDays: Value(7),
          beefCooldownDays: Value(10),
          fishCooldownDays: Value(5),
          meatlessCooldownDays: Value(0),
          notificationHour: Value(12),
          notificationMinute: Value(0),
          notificationsEnabled: Value(false),
          themeMode: Value(AppThemeModePreference.system),
          language: Value(AppLanguagePreference.ar),
          isFirstRun: Value(true),
        ),
      );

      final normalizedSeed = initialEgyptianMealsSeed.map((c) {
        if (c.name.present) {
          return c.copyWith(nameNormalized: Value(normalizeArabic(c.name.value)));
        }
        return c;
      }).toList();
      await batch((b) {
        b.insertAll(meals, normalizedSeed);
      });
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(meals, meals.cloudId);
      }
      if (from < 3) {
        await m.addColumn(appSettings, appSettings.userName);
        await m.addColumn(appSettings, appSettings.userEmail);
      }
      if (from < 4) {
        await m.addColumn(appSettings, appSettings.userGender);
      }
      if (from < 5) {
        await m.addColumn(appSettings, appSettings.userAvatar);
      }
      if (from < 6) {
        await m.addColumn(appSettings, appSettings.language);
      }
      if (from < 7) {
        await customStatement(
          'UPDATE app_settings SET notifications_enabled = 0 WHERE id = 1',
        );
      }
      if (from < 8) {
        await customStatement(
          'UPDATE app_settings SET meatless_cooldown_days = 0 WHERE id = 1',
        );
      }
      if (from < 9) {
        await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_meal_id ON meal_history (meal_id)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_cooked_at ON meal_history (cooked_at DESC)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name ON meals (name)');
      }
      if (from < 10) {
        await m.addColumn(meals, meals.nameNormalized);
        await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name_normalized ON meals (name_normalized)');
        final rows = await customSelect('SELECT id, name FROM meals').get();
        final companions = <MealsCompanion>[];
        for (final row in rows) {
          final id = row.read<int>('id');
          final name = row.read<String>('name');
          final normalized = normalizeArabic(name);
          companions.add(MealsCompanion(id: Value(id), nameNormalized: Value(normalized)));
        }
        await batch((b) {
          for (final c in companions) {
            b.replace(meals, c);
          }
        });
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_meal_id ON meal_history (meal_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_cooked_at ON meal_history (cooked_at DESC)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name_normalized ON meals (name_normalized)');
    },
  );
}
