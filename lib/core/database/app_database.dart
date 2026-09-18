import 'dart:ui';
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
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();

      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_meal_id ON meal_history (meal_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_cooked_at ON meal_history (cooked_at DESC)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name ON meals (name)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name_normalized ON meals (name_normalized)');

      await into(appSettings).insert(
        AppSettingsCompanion(
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
          language: Value(
            PlatformDispatcher.instance.locale.languageCode == 'en'
                ? AppLanguagePreference.en
                : AppLanguagePreference.ar,
          ),
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
      Future<void> safeAddColumn(TableInfo table, GeneratedColumn column) async {
        try {
          await m.addColumn(table, column);
        } catch (_) {
          // Column may already exist or table already modified
        }
      }

      if (from < 2) {
        await safeAddColumn(meals, meals.cloudId);
      }
      if (from < 3) {
        await safeAddColumn(appSettings, appSettings.userName);
        await safeAddColumn(appSettings, appSettings.userEmail);
      }
      if (from < 4) {
        await safeAddColumn(appSettings, appSettings.userGender);
      }
      if (from < 5) {
        await safeAddColumn(appSettings, appSettings.userAvatar);
      }
      if (from < 6) {
        await safeAddColumn(appSettings, appSettings.language);
      }
      if (from < 7) {
        try {
          await customStatement('UPDATE app_settings SET notifications_enabled = 0 WHERE id = 1');
        } catch (_) {}
      }
      if (from < 8) {
        await safeAddColumn(appSettings, appSettings.chickenCooldownDays);
        await safeAddColumn(appSettings, appSettings.beefCooldownDays);
        await safeAddColumn(appSettings, appSettings.fishCooldownDays);
        await safeAddColumn(appSettings, appSettings.meatlessCooldownDays);
        try {
          await customStatement('UPDATE app_settings SET meatless_cooldown_days = 0 WHERE id = 1');
        } catch (_) {}
      }
      if (from < 9) {
        try {
          await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_meal_id ON meal_history (meal_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_cooked_at ON meal_history (cooked_at DESC)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name ON meals (name)');
        } catch (_) {}
      }
      if (from < 10) {
        await safeAddColumn(meals, meals.nameNormalized);
        try {
          await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name_normalized ON meals (name_normalized)');
          final rows = await customSelect('SELECT id, name FROM meals WHERE name_normalized IS NULL').get();
          for (final row in rows) {
            final id = row.read<int>('id');
            final name = row.read<String>('name');
            final normalized = normalizeArabic(name);
            await customStatement('UPDATE meals SET name_normalized = ? WHERE id = ?', [normalized, id]);
          }
        } catch (_) {}
      }
      if (from < 11) {
        await safeAddColumn(meals, meals.isStarterMeal);
        try {
          await customStatement('UPDATE meals SET is_starter_meal = 1 WHERE id <= 20');
        } catch (_) {}
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _selfHealSchema();
    },
  );

  /// Inspects physical SQLite tables and automatically repairs any missing columns
  /// or unpopulated values. This ensures that updates from ANY older APK version
  /// never crash or require clearing app data.
  Future<void> _selfHealSchema() async {
    try {
      // 1. Check and heal app_settings table
      final settingsCols = await customSelect('PRAGMA table_info(app_settings)').get();
      final settingsColNames = settingsCols.map((r) => r.read<String>('name')).toSet();

      if (settingsColNames.isNotEmpty) {
        if (!settingsColNames.contains('cooldown_days')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN cooldown_days INTEGER NOT NULL DEFAULT 14');
        }
        if (!settingsColNames.contains('chicken_cooldown_days')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN chicken_cooldown_days INTEGER NOT NULL DEFAULT 7');
        }
        if (!settingsColNames.contains('beef_cooldown_days')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN beef_cooldown_days INTEGER NOT NULL DEFAULT 10');
        }
        if (!settingsColNames.contains('fish_cooldown_days')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN fish_cooldown_days INTEGER NOT NULL DEFAULT 5');
        }
        if (!settingsColNames.contains('meatless_cooldown_days')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN meatless_cooldown_days INTEGER NOT NULL DEFAULT 0');
        }
        if (!settingsColNames.contains('notification_hour')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN notification_hour INTEGER NOT NULL DEFAULT 12');
        }
        if (!settingsColNames.contains('notification_minute')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN notification_minute INTEGER NOT NULL DEFAULT 0');
        }
        if (!settingsColNames.contains('notifications_enabled')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 0');
        }
        if (!settingsColNames.contains('theme_mode')) {
          await customStatement("ALTER TABLE app_settings ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'");
        }
        if (!settingsColNames.contains('language')) {
          await customStatement("ALTER TABLE app_settings ADD COLUMN language TEXT NOT NULL DEFAULT 'ar'");
        }
        if (!settingsColNames.contains('is_first_run')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN is_first_run INTEGER NOT NULL DEFAULT 1');
        }
        if (!settingsColNames.contains('user_name')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN user_name TEXT');
        }
        if (!settingsColNames.contains('user_email')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN user_email TEXT');
        }
        if (!settingsColNames.contains('user_gender')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN user_gender TEXT');
        }
        if (!settingsColNames.contains('user_avatar')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN user_avatar TEXT');
        }

        // Clean up any NULLs in non-nullable columns that might have been left by older builds
        await customStatement('UPDATE app_settings SET cooldown_days = 14 WHERE cooldown_days IS NULL');
        // Backfill NULLs to new defaults
        await customStatement('UPDATE app_settings SET chicken_cooldown_days = 2 WHERE chicken_cooldown_days IS NULL');
        await customStatement('UPDATE app_settings SET beef_cooldown_days = 2 WHERE beef_cooldown_days IS NULL');
        await customStatement('UPDATE app_settings SET fish_cooldown_days = 4 WHERE fish_cooldown_days IS NULL');
        await customStatement('UPDATE app_settings SET meatless_cooldown_days = 0 WHERE meatless_cooldown_days IS NULL');
        // Upgrade legacy defaults to new spec defaults
        await customStatement('UPDATE app_settings SET chicken_cooldown_days = 2 WHERE chicken_cooldown_days = 7');
        await customStatement('UPDATE app_settings SET beef_cooldown_days = 2 WHERE beef_cooldown_days = 10');
        await customStatement('UPDATE app_settings SET fish_cooldown_days = 4 WHERE fish_cooldown_days = 5');
        await customStatement('UPDATE app_settings SET notification_hour = 12 WHERE notification_hour IS NULL');
        await customStatement('UPDATE app_settings SET notification_minute = 0 WHERE notification_minute IS NULL');
        await customStatement('UPDATE app_settings SET notifications_enabled = 0 WHERE notifications_enabled IS NULL');
        await customStatement("UPDATE app_settings SET theme_mode = 'system' WHERE theme_mode IS NULL");
        await customStatement("UPDATE app_settings SET language = 'ar' WHERE language IS NULL");
        await customStatement('UPDATE app_settings SET is_first_run = 1 WHERE is_first_run IS NULL');

        // Sanitize any numeric PINs/passwords or invalid emails mistakenly saved in user profile
        await customStatement("UPDATE app_settings SET user_name = NULL WHERE user_name IS NOT NULL AND user_name NOT GLOB '*[^0-9]*'");
        await customStatement("UPDATE app_settings SET user_email = NULL WHERE user_email IS NOT NULL AND user_email NOT LIKE '%@%'");

        if (!settingsColNames.contains('recommendation_source')) {
          await customStatement("ALTER TABLE app_settings ADD COLUMN recommendation_source TEXT NOT NULL DEFAULT 'vault_only'");
        }
        if (!settingsColNames.contains('auto_friday_feast_filter')) {
          await customStatement('ALTER TABLE app_settings ADD COLUMN auto_friday_feast_filter INTEGER NOT NULL DEFAULT 0');
        }
      }
    } catch (_) {}

    try {
      // 2. Check and heal meals table
      final mealsCols = await customSelect('PRAGMA table_info(meals)').get();
      final mealsColNames = mealsCols.map((r) => r.read<String>('name')).toSet();

      if (mealsColNames.isNotEmpty) {
        if (!mealsColNames.contains('cloud_id')) {
          await customStatement('ALTER TABLE meals ADD COLUMN cloud_id TEXT');
        }
        if (!mealsColNames.contains('name_normalized')) {
          await customStatement('ALTER TABLE meals ADD COLUMN name_normalized TEXT');
        }
        if (!mealsColNames.contains('photo_path')) {
          await customStatement('ALTER TABLE meals ADD COLUMN photo_path TEXT');
        }
        if (!mealsColNames.contains('is_friday_special')) {
          await customStatement('ALTER TABLE meals ADD COLUMN is_friday_special INTEGER NOT NULL DEFAULT 0');
        }
        if (!mealsColNames.contains('is_budget_friendly')) {
          await customStatement('ALTER TABLE meals ADD COLUMN is_budget_friendly INTEGER NOT NULL DEFAULT 0');
        }
        if (!mealsColNames.contains('is_favorite')) {
          await customStatement('ALTER TABLE meals ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
        }
        if (!mealsColNames.contains('custom_cooldown_days')) {
          await customStatement('ALTER TABLE meals ADD COLUMN custom_cooldown_days INTEGER');
        }
        if (!mealsColNames.contains('notes')) {
          await customStatement('ALTER TABLE meals ADD COLUMN notes TEXT');
        }
        if (!mealsColNames.contains('is_starter_meal')) {
          await customStatement('ALTER TABLE meals ADD COLUMN is_starter_meal INTEGER NOT NULL DEFAULT 0');
          await customStatement('UPDATE meals SET is_starter_meal = 1 WHERE id <= 20');
        }
      }
    } catch (_) {}

    try {
      // 3. Ensure all performance indexes exist FIRST, so the backfill
      // query below can use idx_meals_name_normalized instead of a full scan.
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_meal_id ON meal_history (meal_id)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meal_history_cooked_at ON meal_history (cooked_at DESC)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name ON meals (name)');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_meals_name_normalized ON meals (name_normalized)');
    } catch (_) {}

    try {
      // 4. Populate missing name_normalized values (now index-assisted)
      final nullRows = await customSelect('SELECT id, name FROM meals WHERE name_normalized IS NULL').get();
      for (final row in nullRows) {
        final id = row.read<int>('id');
        final name = row.read<String>('name');
        final normalized = normalizeArabic(name);
        await customStatement('UPDATE meals SET name_normalized = ? WHERE id = ?', [normalized, id]);
      }
    } catch (_) {}
  }
}
