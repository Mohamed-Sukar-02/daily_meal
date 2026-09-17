import 'package:daily_meal/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('Upgrading from schema v6 to v10 succeeds seamlessly without data loss', () async {
    final rawSqlite = sqlite3.openInMemory();
    rawSqlite.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        photo_path TEXT,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        category TEXT NOT NULL,
        prep_time INTEGER NOT NULL,
        is_friday_special INTEGER NOT NULL DEFAULT 0,
        is_budget_friendly INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        cloud_id TEXT
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE meal_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER,
        meal_name TEXT NOT NULL,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        cooked_at INTEGER NOT NULL,
        entry_type TEXT NOT NULL DEFAULT 'cooked',
        notes TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE app_settings (
        id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
        cooldown_days INTEGER NOT NULL DEFAULT 14,
        prevent_repeat_protein INTEGER NOT NULL DEFAULT 1,
        prevent_repeat_carbs INTEGER NOT NULL DEFAULT 1,
        notification_hour INTEGER NOT NULL DEFAULT 12,
        notification_minute INTEGER NOT NULL DEFAULT 0,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        theme_mode TEXT NOT NULL DEFAULT 'system',
        is_first_run INTEGER NOT NULL DEFAULT 1,
        user_name TEXT,
        user_email TEXT,
        user_gender TEXT,
        user_avatar TEXT,
        language TEXT NOT NULL DEFAULT 'ar'
      );
    ''');
    rawSqlite.execute("INSERT INTO meals (id, name, protein_type, carbs_type, category, prep_time, created_at, updated_at) VALUES (1, 'كشري مصري', 'legume', 'rice', 'egyptianTraditional', 45, '2023-11-15T00:00:00.000Z', '2023-11-15T00:00:00.000Z');");
    rawSqlite.execute("INSERT INTO app_settings (id, user_name, cooldown_days) VALUES (1, 'Mohamed', 21);");
    rawSqlite.execute('PRAGMA user_version = 6;');

    final appDb = AppDatabase(NativeDatabase.opened(rawSqlite));

    try {
      final settings = await appDb.appSettingsDao.getSettings();
      expect(settings.userName, 'Mohamed');
      expect(settings.cooldownDays, 21);
      expect(settings.chickenCooldownDays, 7);
      expect(settings.meatlessCooldownDays, 0);

      final mealsList = await appDb.mealsDao.getAllMeals();
      expect(mealsList.length, 1);
      expect(mealsList.first.name, 'كشري مصري');
      expect(mealsList.first.nameNormalized, 'كشري مصري');
      expect(mealsList.first.proteinType, ProteinType.legume);
      expect(mealsList.first.prepTime, 45);
    } finally {
      await appDb.close();
    }
  });

  test('Upgrading from schema v8 to v10 correctly backfills name_normalized without corrupting fields', () async {
    final rawSqlite = sqlite3.openInMemory();
    rawSqlite.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        photo_path TEXT,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        category TEXT NOT NULL,
        prep_time INTEGER NOT NULL,
        is_friday_special INTEGER NOT NULL DEFAULT 0,
        is_budget_friendly INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        cloud_id TEXT
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE app_settings (
        id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
        cooldown_days INTEGER NOT NULL DEFAULT 14,
        chicken_cooldown_days INTEGER NOT NULL DEFAULT 7,
        beef_cooldown_days INTEGER NOT NULL DEFAULT 10,
        fish_cooldown_days INTEGER NOT NULL DEFAULT 5,
        meatless_cooldown_days INTEGER NOT NULL DEFAULT 0,
        notification_hour INTEGER NOT NULL DEFAULT 12,
        notification_minute INTEGER NOT NULL DEFAULT 0,
        notifications_enabled INTEGER NOT NULL DEFAULT 0,
        theme_mode TEXT NOT NULL DEFAULT 'system',
        language TEXT NOT NULL DEFAULT 'ar',
        is_first_run INTEGER NOT NULL DEFAULT 0,
        user_name TEXT,
        user_email TEXT,
        user_gender TEXT,
        user_avatar TEXT
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE meal_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER,
        meal_name TEXT NOT NULL,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        cooked_at INTEGER NOT NULL,
        entry_type TEXT NOT NULL DEFAULT 'cooked',
        notes TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    rawSqlite.execute("INSERT INTO meals (id, name, protein_type, carbs_type, category, prep_time, created_at, updated_at) VALUES (1, 'ملوخية بالأرانب', 'chicken', 'rice', 'egyptianTraditional', 40, '2023-11-15T00:00:00.000Z', '2023-11-15T00:00:00.000Z');");
    rawSqlite.execute("INSERT INTO app_settings (id, user_name) VALUES (1, 'Sara');");
    rawSqlite.execute('PRAGMA user_version = 8;');

    final appDb = AppDatabase(NativeDatabase.opened(rawSqlite));

    try {
      final mealsList = await appDb.mealsDao.getAllMeals();
      expect(mealsList.length, 1);
      expect(mealsList.first.name, 'ملوخية بالأرانب');
      expect(mealsList.first.nameNormalized, 'ملوخيه بالارانب'); // normalized أ -> ا and ة -> ه
      expect(mealsList.first.prepTime, 40);
    } finally {
      await appDb.close();
    }
  });

  test('Self-healing automatically detects missing columns on disk even if user_version is already 10', () async {
    final rawSqlite = sqlite3.openInMemory();
    // Database already tagged version 10 but created missing columns (corrupted or intermediate build)
    rawSqlite.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        category TEXT NOT NULL,
        prep_time INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE app_settings (
        id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
        cooldown_days INTEGER NOT NULL DEFAULT 14
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE meal_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_name TEXT NOT NULL,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        cooked_at TEXT NOT NULL
      );
    ''');
    rawSqlite.execute("INSERT INTO meals (id, name, protein_type, carbs_type, category, prep_time, created_at, updated_at) VALUES (1, 'فول مدمس', 'legume', 'bread', 'egyptianTraditional', 15, '2023-11-15T00:00:00.000Z', '2023-11-15T00:00:00.000Z');");
    rawSqlite.execute("INSERT INTO app_settings (id, cooldown_days) VALUES (1, 14);");
    rawSqlite.execute('PRAGMA user_version = 10;'); // Version matches, so onUpgrade won't run!

    final appDb = AppDatabase(NativeDatabase.opened(rawSqlite));

    try {
      // beforeOpen self-heals the table columns!
      final settings = await appDb.appSettingsDao.getSettings();
      expect(settings.chickenCooldownDays, 7);
      expect(settings.fishCooldownDays, 5);

      final mealsList = await appDb.mealsDao.getAllMeals();
      expect(mealsList.first.name, 'فول مدمس');
      expect(mealsList.first.nameNormalized, 'فول مدمس');
    } finally {
      await appDb.close();
    }
  });

  test('Self-healing automatically sanitizes numeric passwords mistakenly entered into name or email', () async {
    final rawSqlite = sqlite3.openInMemory();
    rawSqlite.execute('''
      CREATE TABLE app_settings (
        id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
        user_name TEXT,
        user_email TEXT,
        cooldown_days INTEGER NOT NULL DEFAULT 14
      );
    ''');
    rawSqlite.execute("INSERT INTO app_settings (id, user_name, user_email, cooldown_days) VALUES (1, '123456', '987654', 14);");
    rawSqlite.execute('PRAGMA user_version = 10;');

    final appDb = AppDatabase(NativeDatabase.opened(rawSqlite));

    try {
      final settings = await appDb.appSettingsDao.getSettings();
      expect(settings.userName, isNull);
      expect(settings.userEmail, isNull);
    } finally {
      await appDb.close();
    }
  });

  test('User custom meals, cooking history, and profile data persist intact across updates without data loss', () async {
    final rawSqlite = sqlite3.openInMemory();
    rawSqlite.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        category TEXT NOT NULL,
        prep_time INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE meal_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER,
        meal_name TEXT NOT NULL,
        protein_type TEXT NOT NULL,
        carbs_type TEXT NOT NULL,
        cooked_at INTEGER NOT NULL,
        entry_type TEXT NOT NULL DEFAULT 'cooked',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT '2026-09-10T14:00:00.000Z'
      );
    ''');
    rawSqlite.execute('''
      CREATE TABLE app_settings (
        id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
        user_name TEXT,
        user_email TEXT,
        user_gender TEXT,
        user_avatar TEXT,
        is_first_run INTEGER NOT NULL DEFAULT 0,
        cooldown_days INTEGER NOT NULL DEFAULT 14
      );
    ''');
    // User added a custom meal and set profile in older version
    rawSqlite.execute("INSERT INTO meals (id, name, protein_type, carbs_type, category, prep_time, created_at, updated_at) VALUES (100, 'شاورما فراخ خاصة بالبيت', 'chicken', 'bread', 'fastFood', 25, '2026-09-01T12:00:00.000Z', '2026-09-01T12:00:00.000Z');");
    rawSqlite.execute("INSERT INTO meal_history (id, meal_id, meal_name, protein_type, carbs_type, cooked_at) VALUES (1, 100, 'شاورما فراخ خاصة بالبيت', 'chicken', 'bread', '2026-09-10T14:00:00.000Z');");
    rawSqlite.execute("INSERT INTO app_settings (id, user_name, user_email, user_gender, user_avatar, is_first_run, cooldown_days) VALUES (1, 'محمد سكر', 'user@example.com', 'male', 'assets/avatars/MO1.png', 0, 14);");
    rawSqlite.execute('PRAGMA user_version = 7;');

    // Now app updates to latest version (v10 with self-healing)!
    final appDb = AppDatabase(NativeDatabase.opened(rawSqlite));

    try {
      final settings = await appDb.appSettingsDao.getSettings();
      expect(settings.userName, equals('محمد سكر'));
      expect(settings.userEmail, equals('user@example.com'));
      expect(settings.userGender, equals('male'));
      expect(settings.userAvatar, equals('assets/avatars/MO1.png'));
      expect(settings.isFirstRun, isFalse);

      final customMeal = await appDb.mealsDao.getMealById(100);
      expect(customMeal, isNotNull);
      expect(customMeal!.name, equals('شاورما فراخ خاصة بالبيت'));
      expect(customMeal.proteinType, equals(ProteinType.chicken));
      expect(customMeal.nameNormalized, equals('شاورما فراخ خاصه بالبيت'));

      final history = await appDb.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));
      expect(history.first.mealName, equals('شاورما فراخ خاصة بالبيت'));
    } finally {
      await appDb.close();
    }
  });
}
