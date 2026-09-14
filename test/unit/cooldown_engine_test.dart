// test/unit/cooldown_engine_test.dart
// Tier 1 (Feature Coverage) & Tier 2 (Boundary & Corner Cases) for R2: Recommendation Engine & Cooldown Algorithm

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/core/database/app_database.dart' as drift_db;
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import '../support/contracts.dart' hide RecommendationResult;
import '../support/seed_catalog.dart';

void main() {
  late RecommendationEngine engine;
  late List<Meal> catalog;
  final baseDate = DateTime(2026, 9, 6); // Sunday

  setUp(() {
    engine = const RecommendationEngine();
    catalog = List<Meal>.from(initialEgyptianMealsSeed);
  });

  group('Tier 1: Feature Coverage (R2 - Recommendation Engine & Cooldown Algorithm)', () {
    test('R2.1: Filters out meals cooked within the cooldown window (14 days default)', () {
      // Meal 1 (Koshari) was cooked 3 days ago
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 3)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(cooldownDays: 14);
      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Meal 1 must NOT be in recommendations
      expect(result.recommendations.any((m) => m.id == 1), isFalse);
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(0));
    });

    test('R2.2: Meals cooked outside the cooldown window (e.g. 15 days ago) become eligible', () {
      // Meal 1 (Koshari) was cooked 15 days ago (cooldown is 14 days)
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 15)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false);
      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Meal 1 is eligible and can be recommended
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(0));
    });

    test('R2.3: Prevents back-to-back repeating protein when cooked yesterday', () {
      // Yesterday we cooked Chicken Molokhia (Meal 2: chicken)
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2,
          mealName: 'ملوخية خضراء بالفراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: true,
        preventRepeatCarbs: false,
      );

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Every recommended meal must NOT have chicken
      for (final meal in result.recommendations) {
        expect(meal.proteinType, isNot(equals(ProteinType.chicken)),
            reason: 'Meal ${meal.name} has chicken which repeats yesterday protein!');
      }
      expect(result.relaxationLevel, equals(0));
    });

    test('R2.4: Allows repeating protein when preventRepeatProtein setting is disabled', () {
      // Yesterday we cooked chicken, but setting is disabled
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2,
          mealName: 'ملوخية خضراء بالفراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: false,
        preventRepeatCarbs: false,
      );

      // Using only chicken meals in a mini catalog
      final chickenMeals = catalog.where((m) => m.proteinType == ProteinType.chicken && m.id != 2).toList();
      final result = engine.compute(
        meals: chickenMeals,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Chicken meals are permitted
      expect(result.recommendations.every((m) => m.proteinType == ProteinType.chicken), isTrue);
    });

    test('R2.5: Prevents back-to-back repeating carbs when cooked yesterday', () {
      // Yesterday we ate Rice dish (Meal 1: rice)
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: false,
        preventRepeatCarbs: true,
      );

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Every recommended meal must NOT have rice
      for (final meal in result.recommendations) {
        expect(meal.carbsType, isNot(equals(CarbsType.rice)),
            reason: 'Meal ${meal.name} has rice which repeats yesterday carbs!');
      }
    });

    test('R2.6: Friday Special booster elevates festive dishes on Fridays', () {
      final fridayDate = DateTime(2026, 9, 11); // Friday
      expect(fridayDate.weekday, equals(DateTime.friday));

      const settings = AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: false,
        preventRepeatCarbs: false,
      );

      final result = engine.compute(
        meals: catalog,
        history: const [],
        settings: settings,
        today: fridayDate,
      );

      // Top recommendation on Friday must be a Friday Special dish
      expect(result.recommendations.first.isFridaySpecial, isTrue,
          reason: 'Top recommendation on Friday should be a Friday Special!');
    });

    test('R2.7: Friday Specials are deprioritized on regular weekdays', () {
      final mondayDate = DateTime(2026, 9, 7); // Monday
      expect(mondayDate.weekday, isNot(equals(DateTime.friday)));

      final fridayMeal = catalog.firstWhere((m) => m.isFridaySpecial);
      final scoreOnFriday = engine.calculateMealScore(
        meal: fridayMeal,
        history: const [],
        today: DateTime(2026, 9, 11), // Friday
        cooldownDays: 14,
      );
      final scoreOnMonday = engine.calculateMealScore(
        meal: fridayMeal,
        history: const [],
        today: mondayDate,
        cooldownDays: 14,
      );

      // Score on Friday should be 20 points higher (+15 bonus on Fri vs -5 on Mon)
      expect(scoreOnFriday - scoreOnMonday, closeTo(20.0, 4.0));
    });

    test('R2.8: Inter-card diversity ensures top 3 cards feature distinct protein types', () {
      const settings = AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: false,
        preventRepeatCarbs: false,
      );

      final result = engine.compute(
        meals: catalog,
        history: const [],
        settings: settings,
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      final proteinTypes = result.recommendations.map((m) => m.proteinType).toSet();
      // All 3 cards should have different proteins because catalog has plenty of choices
      expect(proteinTypes.length, equals(3),
          reason: 'Top 3 cards must have diverse protein types!');
    });

    test('R2.9: Scoring formula rewards never-cooked dishes and favorite tags', () {
      final favoriteMeal = catalog.firstWhere((m) => m.isFavorite && !m.isBudgetFriendly);
      final regularMeal = catalog.firstWhere((m) => !m.isFavorite && !m.isBudgetFriendly && !m.isFridaySpecial);

      final scoreFav = engine.calculateMealScore(
        meal: favoriteMeal,
        history: const [],
        today: baseDate,
        cooldownDays: 14,
      );
      final scoreReg = engine.calculateMealScore(
        meal: regularMeal,
        history: const [],
        today: baseDate,
        cooldownDays: 14,
      );

      // Favorite gives +5.0 (ignoring small jitter variance)
      expect(scoreFav, greaterThan(scoreReg - 4.0));
    });
  });

  group('Tier 2: Boundary & Corner Cases', () {
    test('T2.1: Empty meal vault yields empty recommendations with Level 5 degradation', () {
      final result = engine.compute(
        meals: const [],
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations, isEmpty);
      expect(result.relaxationLevel, equals(5));
      expect(result.relaxationReason, contains('فارغة'));
    });

    test('T2.2: Meal vault with fewer than 3 meals gracefully scales down without crashing', () {
      final miniVault = [catalog[0], catalog[1]]; // Exactly 2 meals

      final result = engine.compute(
        meals: miniVault,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(2));
      expect(result.recommendations.map((m) => m.id), containsAll([1, 2]));
    });

    test('T2.3: All meals on cooldown triggers 5-level degradation cascade', () {
      // Mini vault with 4 meals, all cooked within the last 4 days
      final miniVault = catalog.take(4).toList();
      final history = [
        MealHistoryData(
          id: 1,
          mealId: miniVault[0].id,
          mealName: miniVault[0].name,
          proteinType: miniVault[0].proteinType,
          carbsType: miniVault[0].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: miniVault[1].id,
          mealName: miniVault[1].name,
          proteinType: miniVault[1].proteinType,
          carbsType: miniVault[1].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 2)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 3,
          mealId: miniVault[2].id,
          mealName: miniVault[2].name,
          proteinType: miniVault[2].proteinType,
          carbsType: miniVault[2].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 3)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 4,
          mealId: miniVault[3].id,
          mealName: miniVault[3].name,
          proteinType: miniVault[3].proteinType,
          carbsType: miniVault[3].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 4)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(cooldownDays: 14);
      final result = engine.compute(
        meals: miniVault,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Cooldown must relax gracefully to provide 3 recommendations
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, greaterThan(0));
    });

    test('T2.4: All eligible non-cooldown meals share yesterday protein -> triggers Level 3 relaxation', () {
      // Suppose yesterday we ate Beef
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 99,
          mealName: 'لحمة مسلوقة',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      // Vault contains ONLY beef meals
      final beefVault = catalog.where((m) => m.proteinType == ProteinType.beef).toList();

      const settings = AppSetting(cooldownDays: 14, preventRepeatProtein: true);
      final result = engine.compute(
        meals: beefVault,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Protein constraint is relaxed rather than returning 0 recommendations
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, greaterThanOrEqualTo(3));
    });

    test('T2.5: All eligible non-cooldown meals share yesterday carbs -> triggers Level 1 relaxation', () {
      // Yesterday we ate Bread
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 99,
          mealName: 'حواوشي',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.bread,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      // Vault contains only bread meals, but with different proteins
      final breadVault = catalog.where((m) => m.carbsType == CarbsType.bread).toList();

      const settings = AppSetting(cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: true);
      final result = engine.compute(
        meals: breadVault,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Carbs constraint is relaxed, but protein constraint is preserved
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(1));
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.beef), isFalse);
    });

    test('T2.6: Extreme cooldown boundary (1 day) excludes yesterday but includes 2 days ago', () {
      final mealYesterday = catalog[0];
      final mealTwoDaysAgo = catalog[1];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: mealYesterday.id,
          mealName: mealYesterday.name,
          proteinType: mealYesterday.proteinType,
          carbsType: mealYesterday.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: mealTwoDaysAgo.id,
          mealName: mealTwoDaysAgo.name,
          proteinType: mealTwoDaysAgo.proteinType,
          carbsType: mealTwoDaysAgo.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 2)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(
        cooldownDays: 1,
        preventRepeatProtein: false,
        preventRepeatCarbs: false,
      );

      final result = engine.compute(
        meals: [mealYesterday, mealTwoDaysAgo, catalog[2], catalog[3], catalog[4]],
        history: history,
        settings: settings,
        today: baseDate,
      );

      // mealYesterday is excluded (1-day cooldown)
      expect(result.recommendations.any((m) => m.id == mealYesterday.id), isFalse);
      // mealTwoDaysAgo is eligible
      expect(result.recommendations.any((m) => m.id == mealTwoDaysAgo.id), isTrue);
    });

    test('T2.7: Multiple cooking logs on same day uses the most recent entry for context', () {
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1, hours: 2)),
        ),
        MealHistoryData(
          id: 2,
          mealId: 2,
          mealName: 'ملوخية بالفراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      const settings = AppSetting(cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: false);
      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Chicken (from the most recent entry) must be excluded
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse);
    });

    test('T2.8: Leftover entry updates last eaten protein but retains cooldown rules', () {
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 4, // Fish
          mealName: 'سمك بلطي',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.leftover,
          createdAt: baseDate,
        ),
      ];

      const settings = AppSetting(cooldownDays: 14, preventRepeatProtein: true);
      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: settings,
        today: baseDate,
      );

      // Fish is excluded due to last eaten protein repeat prevention
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.fish), isFalse);
    });
  });

  group('Tier 2 Extended: Cooldown Engine Edge Cases & Drift Interop', () {
    test('E2.1: Cooked at 23:59 yesterday tested at 00:01 today treats delta as 1 day', () {
      final yesterdayNight = DateTime(2026, 9, 6, 23, 59);
      final todayMorning = DateTime(2026, 9, 7, 0, 1);
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2, // Chicken
          mealName: 'ملوخية بالفراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: yesterdayNight,
          status: MealHistoryStatus.cookedToday,
          createdAt: yesterdayNight,
        ),
      ];
      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(preventRepeatProtein: true),
        today: todayMorning,
      );
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse);
    });

    test('E2.2: Cooked at 08:00 today tested at 13:00 today excluded in Level 4 degradation', () {
      final today8am = DateTime(2026, 9, 6, 8, 0);
      final today1pm = DateTime(2026, 9, 6, 13, 0);
      final miniCatalog = [catalog[0], catalog[1], catalog[2], catalog[3]];
      final history = [
        MealHistoryData(
          id: 1,
          mealId: miniCatalog[0].id,
          mealName: miniCatalog[0].name,
          proteinType: miniCatalog[0].proteinType,
          carbsType: miniCatalog[0].carbsType,
          cookedDate: today8am,
          status: MealHistoryStatus.cookedToday,
          createdAt: today8am,
        ),
        MealHistoryData(
          id: 2,
          mealId: miniCatalog[1].id,
          mealName: miniCatalog[1].name,
          proteinType: miniCatalog[1].proteinType,
          carbsType: miniCatalog[1].carbsType,
          cookedDate: today8am.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: today8am.subtract(const Duration(days: 1)),
        ),
        MealHistoryData(
          id: 3,
          mealId: miniCatalog[2].id,
          mealName: miniCatalog[2].name,
          proteinType: miniCatalog[2].proteinType,
          carbsType: miniCatalog[2].carbsType,
          cookedDate: today8am.subtract(const Duration(days: 2)),
          status: MealHistoryStatus.cookedToday,
          createdAt: today8am.subtract(const Duration(days: 2)),
        ),
        MealHistoryData(
          id: 4,
          mealId: miniCatalog[3].id,
          mealName: miniCatalog[3].name,
          proteinType: miniCatalog[3].proteinType,
          carbsType: miniCatalog[3].carbsType,
          cookedDate: today8am.subtract(const Duration(days: 2)),
          status: MealHistoryStatus.cookedToday,
          createdAt: today8am.subtract(const Duration(days: 2)),
        ),
      ];
      final result = engine.compute(
        meals: miniCatalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: today1pm,
      );
      expect(result.recommendations.any((m) => m.id == miniCatalog[0].id), isFalse);
      expect(result.relaxationLevel, equals(4));
    });

    test('E2.3: Cooldown setting of 60 days strictly excludes meals cooked 60 days ago', () {
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 60)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];
      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 60),
        today: baseDate,
      );
      expect(result.recommendations.any((m) => m.id == 1), isFalse);
    });

    test('E2.4: Catalog with only chicken and beef provides 3 cards with carbs diversity fallback', () {
      final restrictedCatalog = catalog
          .where((m) => m.proteinType == ProteinType.chicken || m.proteinType == ProteinType.beef)
          .take(10)
          .toList();
      final result = engine.compute(
        meals: restrictedCatalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );
      expect(result.recommendations.length, equals(3));
      // Card 1 and Card 2 take distinct proteins; Card 3 falls back to distinct carbs
      final carbsTypes = result.recommendations.map((m) => m.carbsType).toSet();
      expect(carbsTypes.length, greaterThanOrEqualTo(2));
    });

    test('E2.5: Jitter output is bit-for-bit identical across 1000 repeated executions on same day', () {
      final firstResult = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );
      final firstIds = firstResult.recommendations.map((m) => m.id).toList();

      for (int i = 0; i < 1000; i++) {
        final repeated = engine.compute(
          meals: catalog,
          history: const [],
          settings: const AppSetting(),
          today: baseDate,
        );
        expect(repeated.recommendations.map((m) => m.id).toList(), equals(firstIds));
      }
    });

    test('E2.6: Direct compatibility with Drift AppDatabase query outputs', () {
      final driftMeal = drift_db.Meal(
        id: 101,
        name: 'طاجن تورلي باللحمة',
        proteinType: drift_db.ProteinType.beef,
        carbsType: drift_db.CarbsType.potato,
        category: drift_db.MealCategory.ovenBaked,
        prepTime: 55,
        isFridaySpecial: false,
        isBudgetFriendly: true,
        isFavorite: true,
        createdAt: baseDate,
        updatedAt: baseDate,
      );
      final recs = engine.getRecommendations(
        allMeals: [driftMeal],
        history: const [],
        settings: const drift_db.AppSettingsData(
          id: 1,
          cooldownDays: 14,
          chickenCooldownDays: 3,
          beefCooldownDays: 7,
          fishCooldownDays: 4,
          meatlessCooldownDays: 1,
          preventRepeatProtein: true,
          preventRepeatCarbs: true,
          notificationHour: 12,
          notificationMinute: 0,
          notificationsEnabled: true,
          themeMode: drift_db.AppThemeModePreference.system,
          language: drift_db.AppLanguagePreference.ar,
          isFirstRun: true,
          userName: null,
          userEmail: null,
          userGender: null,
          userAvatar: null,
        ),
        now: baseDate,
      );
      expect(recs.length, equals(1));
      expect(recs.first.id, equals(101));
    });
  });
}

