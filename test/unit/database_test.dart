// test/unit/database_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory isolated SQLite instance for every test
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Group 1: Database Initialization & Seeding (onCreate)', () {
    test('seeds exactly 20 starter Egyptian meals on first creation', () async {
      final meals = await db.mealsDao.getAllMeals();
      expect(meals.length, equals(20));

      // 1. Verify Koshary
      final koshary = meals.firstWhere((m) => m.id == 1);
      expect(koshary.name, contains('كشري مصري'));
      expect(koshary.proteinType, equals(ProteinType.legume));
      expect(koshary.carbsType, equals(CarbsType.rice));
      expect(koshary.category, equals(MealCategory.egyptianTraditional));
      expect(koshary.prepTime, equals(50));
      expect(koshary.prepTimeMinutes, equals(50));
      expect(koshary.isBudgetFriendly, isTrue);
      expect(koshary.isFavorite, isTrue);

      // 2. Verify Molokhia
      final molokhia = meals.firstWhere((m) => m.id == 2);
      expect(molokhia.name, contains('ملوخية خضراء'));
      expect(molokhia.proteinType, equals(ProteinType.chicken));
      expect(molokhia.carbsType, equals(CarbsType.rice));

      // 3. Verify Fish
      final fish = meals.firstWhere((m) => m.id == 4);
      expect(fish.name, contains('سمك بلطي'));
      expect(fish.proteinType, equals(ProteinType.fish));
      expect(fish.isFridaySpecial, isTrue);

      // 4. Verify Friday specials count (at least 5)
      final fridaySpecials = meals.where((m) => m.isFridaySpecial).toList();
      expect(fridaySpecials.length, greaterThanOrEqualTo(5));

      // 5. Verify budget friendly dishes count
      final budgetFriendly = meals.where((m) => m.isBudgetFriendly).toList();
      expect(budgetFriendly.length, greaterThanOrEqualTo(10));
    });

    test('seeds singleton AppSettings with default parameters', () async {
      final settings = await db.appSettingsDao.getSettings();
      expect(settings.id, equals(1));
      expect(settings.cooldownDays, equals(14));
      expect(settings.preventRepeatProtein, isTrue);
      expect(settings.preventRepeatCarbs, isTrue);
      expect(settings.notificationHour, equals(12));
      expect(settings.notificationMinute, equals(0));
      expect(settings.notificationsEnabled, isFalse);
      expect(settings.notificationEnabled, isFalse);
      expect(settings.themeMode, equals(AppThemeModePreference.system));
      expect(settings.isFirstRun, isTrue);
    });
  });

  group('Group 2: Meals Table & MealsDao CRUD Operations', () {
    test('insertMeal creates a new meal and returns valid auto-increment ID', () async {
      final id = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('شاورما دجاج سوري بالثومية'),
          proteinType: Value(ProteinType.chicken),
          carbsType: Value(CarbsType.bread),
          category: Value(MealCategory.fastFood),
          prepTime: Value(30),
          isFridaySpecial: Value(false),
          isBudgetFriendly: Value(true),
          isFavorite: Value(false),
        ),
      );
      expect(id, equals(21));

      final meal = await db.mealsDao.getMealById(21);
      expect(meal, isNotNull);
      expect(meal!.name, equals('شاورما دجاج سوري بالثومية'));
      expect(meal.proteinType, equals(ProteinType.chicken));
      expect(meal.carbsType, equals(CarbsType.bread));
      expect(meal.category, equals(MealCategory.fastFood));
      expect(meal.prepTime, equals(30));
      expect(meal.isFridaySpecial, isFalse);
    });

    test('updateMeal updates existing meal properties', () async {
      final meal = await db.mealsDao.getMealById(1);
      expect(meal, isNotNull);

      final updated = meal!.copyWith(
        name: 'كشري مصري مخصوص مع دقة مضاعفة',
        prepTime: 55,
        isFavorite: true,
      );
      final success = await db.mealsDao.updateMeal(updated);
      expect(success, isTrue);

      final reFetched = await db.mealsDao.getMealById(1);
      expect(reFetched!.name, equals('كشري مصري مخصوص مع دقة مضاعفة'));
      expect(reFetched.prepTime, equals(55));
      expect(reFetched.prepTimeMinutes, equals(55));
      expect(reFetched.isFavorite, isTrue);
    });

    test('toggleFavorite updates favorite flag', () async {
      final meal7 = await db.mealsDao.getMealById(7);
      expect(meal7!.isFavorite, isFalse);

      await db.mealsDao.toggleFavorite(7);
      var reFetched = await db.mealsDao.getMealById(7);
      expect(reFetched!.isFavorite, isTrue);

      await db.mealsDao.toggleFavorite(7, true);
      reFetched = await db.mealsDao.getMealById(7);
      expect(reFetched!.isFavorite, isFalse);
    });

    test('watchAllMeals emits stream updates on insertion', () async {
      final stream = db.mealsDao.watchAllMeals();

      final expectation = expectLater(
        stream.map((list) => list.length),
        emitsInOrder([20, 21]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('كفتة مشوية على الفحم'),
          proteinType: Value(ProteinType.beef),
          carbsType: Value(CarbsType.bread),
          category: Value(MealCategory.ovenBaked),
          prepTime: Value(45),
        ),
      );

      await expectation;
    });

    test('deleteMeal removes meal from database', () async {
      final deletedCount = await db.mealsDao.deleteMeal(20);
      expect(deletedCount, equals(1));

      final meal = await db.mealsDao.getMealById(20);
      expect(meal, isNull);

      final allMeals = await db.mealsDao.getAllMeals();
      expect(allMeals.length, equals(19));
    });

    test('searchMeals finds meals matching query string', () async {
      final results = await db.mealsDao.searchMeals('حواوشي');
      expect(results.length, equals(1));
      expect(results.first.name, contains('حواوشي'));

      final emptySearch = await db.mealsDao.searchMeals('   ');
      expect(emptySearch.length, equals(20));
    });

    test('filterByTag filters meals by category, protein, and tags', () async {
      final seafood = await db.mealsDao.filterByTag(
        category: MealCategory.seafood,
      );
      expect(seafood.length, greaterThanOrEqualTo(3));
      for (final m in seafood) {
        expect(m.category, equals(MealCategory.seafood));
      }

      final fridayBudget = await db.mealsDao.filterByTag(
        isFridaySpecial: true,
        isBudgetFriendly: true,
      );
      expect(fridayBudget, isNotEmpty);
      for (final m in fridayBudget) {
        expect(m.isFridaySpecial, isTrue);
        expect(m.isBudgetFriendly, isTrue);
      }
    });

    test('insertMeal throws ArgumentError on empty name or non-positive prepTime', () async {
      expect(
        () => db.mealsDao.insertMeal(
          const MealsCompanion(
            name: Value('   '),
            proteinType: Value(ProteinType.beef),
            carbsType: Value(CarbsType.rice),
            category: Value(MealCategory.egyptianTraditional),
            prepTime: Value(30),
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => db.mealsDao.insertMeal(
          const MealsCompanion(
            name: Value('أكلة تجريبية'),
            proteinType: Value(ProteinType.beef),
            carbsType: Value(CarbsType.rice),
            category: Value(MealCategory.egyptianTraditional),
            prepTime: Value(0),
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => db.mealsDao.insertMeal(
          const MealsCompanion(
            name: Value('أكلة تجريبية سالبة'),
            proteinType: Value(ProteinType.beef),
            carbsType: Value(CarbsType.rice),
            category: Value(MealCategory.egyptianTraditional),
            prepTime: Value(-10),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Group 3: MealHistory Table & MealHistoryDao Logging', () {
    test('logs cooked meal and leftover meal with distinct entry types', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final now = DateTime.now();

      final cookedId = await db.mealHistoryDao.logMealFromMeal(
        meal,
        cookedAt: now,
        entryType: MealEntryType.cooked,
        notes: 'طبخة طازة',
      );
      expect(cookedId, greaterThan(0));

      final leftoverId = await db.mealHistoryDao.logMealFromMeal(
        meal,
        cookedAt: now.add(const Duration(days: 1)),
        entryType: MealEntryType.leftover,
        notes: 'بواقي من أمس',
      );
      expect(leftoverId, greaterThan(cookedId));

      final history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(2));

      // Descending order by cookedAt: leftover is first (now + 1 day), cooked is second
      expect(history[0].entryType, equals(MealEntryType.leftover));
      expect(history[0].notes, equals('بواقي من أمس'));
      expect(history[1].entryType, equals(MealEntryType.cooked));
      expect(history[1].notes, equals('طبخة طازة'));
    });

    test('getRecentHistory returns entries ordered chronologically descending', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final t1 = DateTime(2026, 9, 1);
      final t2 = DateTime(2026, 9, 3);
      final t3 = DateTime(2026, 9, 5);

      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: t1);
      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: t3);
      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: t2);

      final recent = await db.mealHistoryDao.getRecentHistory(limit: 10);
      expect(recent.length, equals(3));
      expect(recent[0].cookedAt, equals(t3));
      expect(recent[1].cookedAt, equals(t2));
      expect(recent[2].cookedAt, equals(t1));

      // Test getLatestCookedMeal
      final latest = await db.mealHistoryDao.getLatestCookedMeal();
      expect(latest, isNotNull);
      expect(latest!.cookedAt, equals(t3));
    });

    test('getHistoryWithinDays filters records within date cutoff', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final now = DateTime.now();

      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: now.subtract(const Duration(days: 2)));
      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: now.subtract(const Duration(days: 5)));
      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: now.subtract(const Duration(days: 20)));

      final within14Days = await db.mealHistoryDao.getHistoryWithinDays(14);
      expect(within14Days.length, equals(2));

      final within30Days = await db.mealHistoryDao.getHistoryWithinDays(30);
      expect(within30Days.length, equals(3));
    });

    test('deleteHistoryEntry deletes entry for undo support', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final id = await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: DateTime.now());

      var history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));

      final deleted = await db.mealHistoryDao.deleteHistoryEntry(id);
      expect(deleted, equals(1));

      history = await db.mealHistoryDao.getAllHistory();
      expect(history, isEmpty);
    });
  });

  group('Group 4: Foreign Key Cascades & Snapshot Preservation', () {
    test('preserves history snapshot and sets mealId to null when meal is deleted', () async {
      final meal = (await db.mealsDao.getMealById(2))!;
      expect(meal.name, contains('ملوخية'));

      await db.mealHistoryDao.logMealFromMeal(
        meal,
        cookedAt: DateTime(2026, 9, 2),
        entryType: MealEntryType.cooked,
        notes: 'عزومة عائلية كبيرة',
      );

      var history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));
      expect(history.first.mealId, equals(2));
      expect(history.first.mealName, equals(meal.name));
      expect(history.first.proteinType, equals(ProteinType.chicken));
      expect(history.first.carbsType, equals(CarbsType.rice));

      // Delete the parent meal
      await db.mealsDao.deleteMeal(2);
      expect(await db.mealsDao.getMealById(2), isNull);

      // Verify history row is preserved with null mealId (KeyAction.setNull) and intact snapshot fields
      history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));
      expect(history.first.mealId, isNull, reason: 'mealId must be nullified (SetNull)');
      expect(history.first.mealName, contains('ملوخية'));
      expect(history.first.proteinType, equals(ProteinType.chicken));
      expect(history.first.carbsType, equals(CarbsType.rice));
      expect(history.first.notes, equals('عزومة عائلية كبيرة'));
    });
  });

  group('Group 5: AppSettings Table & AppSettingsDao Mutations', () {
    test('updates cooldown days and clamps between 1 and 60 days', () async {
      await db.appSettingsDao.updateCooldownDays(21);
      var settings = await db.appSettingsDao.getSettings();
      expect(settings.cooldownDays, equals(21));

      // Test lower boundary clamp
      await db.appSettingsDao.updateCooldownDays(0);
      settings = await db.appSettingsDao.getSettings();
      expect(settings.cooldownDays, equals(1));

      // Test upper boundary clamp
      await db.appSettingsDao.updateCooldownDays(99);
      settings = await db.appSettingsDao.getSettings();
      expect(settings.cooldownDays, equals(60));
    });

    test('updates theme mode preference', () async {
      await db.appSettingsDao.updateThemeMode(AppThemeModePreference.dark);
      final settings = await db.appSettingsDao.getSettings();
      expect(settings.themeMode, equals(AppThemeModePreference.dark));
    });

    test('updates notification time and toggle', () async {
      await db.appSettingsDao.updateNotificationTime(13, 45);
      await db.appSettingsDao.toggleNotifications(false);

      var settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationHour, equals(13));
      expect(settings.notificationMinute, equals(45));
      expect(settings.notificationsEnabled, isFalse);
      expect(settings.notificationEnabled, isFalse);

      await db.appSettingsDao.updateNotificationsEnabled(true);
      settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationsEnabled, isTrue);
    });

    test('updates dietary diversity rules', () async {
      await db.appSettingsDao.updateDietaryRules(preventProtein: false, preventCarbs: false);
      var settings = await db.appSettingsDao.getSettings();
      expect(settings.preventRepeatProtein, isFalse);
      expect(settings.preventRepeatCarbs, isFalse);

      await db.appSettingsDao.togglePreventRepeatProtein(true);
      await db.appSettingsDao.togglePreventRepeatCarbs(true);
      settings = await db.appSettingsDao.getSettings();
      expect(settings.preventRepeatProtein, isTrue);
      expect(settings.preventRepeatCarbs, isTrue);
    });

    test('singleton row integrity is preserved', () async {
      await db.appSettingsDao.updateCooldownDays(7);
      await db.appSettingsDao.updateCooldownDays(14);
      await db.appSettingsDao.updateThemeMode(AppThemeModePreference.light);

      final allRows = await db.select(db.appSettings).get();
      expect(allRows.length, equals(1));
      expect(allRows.first.id, equals(1));
    });

    test('watchSettings emits updates reactively', () async {
      final stream = db.appSettingsDao.watchSettings();

      final expectation = expectLater(
        stream.map((s) => s.cooldownDays),
        emitsInOrder([14, 25]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await db.appSettingsDao.updateCooldownDays(25);
      await expectation;
    });
  });
}
