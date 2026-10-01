import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Meal _createMeal({
  required int id,
  required String name,
  required ProteinType proteinType,
  CarbsType carbsType = CarbsType.rice,
  MealCategory category = MealCategory.egyptianTraditional,
  bool isFavorite = false,
  bool isFridaySpecial = false,
}) {
  return Meal(
    id: id,
    name: name,
    photoPath: null,
    proteinType: proteinType,
    carbsType: carbsType,
    category: category,
    isStarterMeal: false,
    prepTime: 30,
    isFridaySpecial: isFridaySpecial,
    isFavorite: isFavorite,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    cloudId: null,
    nameNormalized: null,
  );
}

MealHistoryData _createHistory({
  required int id,
  required int mealId,
  required String mealName,
  required ProteinType proteinType,
  required DateTime cookedAt,
  CarbsType carbsType = CarbsType.rice,
}) {
  return MealHistoryData(
    id: id,
    mealId: mealId,
    mealName: mealName,
    proteinType: proteinType,
    carbsType: carbsType,
    cookedAt: cookedAt,
    entryType: MealEntryType.cooked,
    notes: null,
    createdAt: cookedAt,
  );
}

AppSettingsData _createSettings({
  int cooldownDays = 14,
  int chickenCooldownDays = 2,
  int beefCooldownDays = 2,
  int fishCooldownDays = 4,
  int meatlessCooldownDays = 0,
}) {
  return AppSettingsData(
    id: 1,
    cooldownDays: cooldownDays,
    chickenCooldownDays: chickenCooldownDays,
    beefCooldownDays: beefCooldownDays,
    fishCooldownDays: fishCooldownDays,
    meatlessCooldownDays: meatlessCooldownDays,
    notificationHour: 12,
    notificationMinute: 0,
    notificationsEnabled: false,
    themeMode: AppThemeModePreference.system,
    language: AppLanguagePreference.ar,
    isFirstRun: false,
    recommendationSource: RecommendationSource.vault_only,
    autoFridayFeastFilter: false,
  );
}

void main() {
  const engine = CooldownEngine();
  // Fixed Wednesday reference date (not a Friday, avoiding Friday feast boost)
  final wednesday = DateTime(2026, 10, 7, 12, 0);

  group('CooldownEngine - R1: Legume & Dairy Cooldown Resolution', () {
    test('legume meals resolve to meatlessCooldownDays instead of global cooldownDays in compute', () {
      final settings = _createSettings(cooldownDays: 14, meatlessCooldownDays: 2);
      final koshari = _createMeal(
        id: 1,
        name: 'كشري مصري',
        proteinType: ProteinType.legume,
        carbsType: CarbsType.rice,
      );

      // Cooked 5 days ago:
      // If using global cooldownDays (14), 5 <= 14 -> blocked at level 0.
      // If using meatlessCooldownDays (2), 5 > 2 -> eligible at level 0.
      final history = [
        _createHistory(
          id: 101,
          mealId: 1,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 5)),
        ),
      ];

      final result = engine.compute<Meal>(
        meals: [koshari],
        history: history,
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      expect(result.recommendations.first.id, 1);
      expect(
        result.relaxationLevel,
        0,
        reason: 'Legume meal cooked 5 days ago should be eligible at level 0 with meatlessCooldownDays=2',
      );
    });

    test('dairy meals resolve to meatlessCooldownDays instead of global cooldownDays in compute', () {
      final settings = _createSettings(cooldownDays: 14, meatlessCooldownDays: 3);
      final shakshouka = _createMeal(
        id: 2,
        name: 'شكشوكة بالجبنة والبيض',
        proteinType: ProteinType.dairy,
        carbsType: CarbsType.bread,
      );

      // Cooked 4 days ago:
      // If using global cooldown (14), 4 <= 14 -> blocked at level 0.
      // If using meatlessCooldown (3), 4 > 3 -> eligible at level 0.
      final history = [
        _createHistory(
          id: 102,
          mealId: 2,
          mealName: 'شكشوكة بالجبنة والبيض',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 4)),
        ),
      ];

      final result = engine.compute<Meal>(
        meals: [shakshouka],
        history: history,
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      expect(result.recommendations.first.id, 2);
      expect(
        result.relaxationLevel,
        0,
        reason: 'Dairy meal cooked 4 days ago should be eligible at level 0 with meatlessCooldownDays=3',
      );
    });

    test('legume and dairy meals respect meatlessCooldownDays = 0 (immediately eligible)', () {
      final settings = _createSettings(cooldownDays: 14, meatlessCooldownDays: 0);
      final foul = _createMeal(
        id: 3,
        name: 'فول مدمس',
        proteinType: ProteinType.legume,
      );
      final omelette = _createMeal(
        id: 4,
        name: 'أومليت بالخضار',
        proteinType: ProteinType.dairy,
      );

      // Both cooked yesterday: with meatlessCooldownDays = 0, deltaDays (1) > 0, so eligible at level 0
      final history = [
        _createHistory(
          id: 103,
          mealId: 3,
          mealName: 'فول مدمس',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 1)),
        ),
        _createHistory(
          id: 104,
          mealId: 4,
          mealName: 'أومليت بالخضار',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 1)),
        ),
      ];

      final result = engine.compute<Meal>(
        meals: [foul, omelette],
        history: history,
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, hasLength(2));
      expect(result.relaxationLevel, 0);
    });

    test('legume and dairy meals are blocked at level 0 if within meatlessCooldownDays', () {
      final settings = _createSettings(cooldownDays: 14, meatlessCooldownDays: 5);
      final lentilSoup = _createMeal(
        id: 5,
        name: 'شوربة عدس',
        proteinType: ProteinType.legume,
      );

      // Cooked 2 days ago: deltaDays = 2 <= meatlessCooldownDays (5), so blocked at level 0
      final history = [
        _createHistory(
          id: 105,
          mealId: 5,
          mealName: 'شوربة عدس',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 2)),
        ),
      ];

      final result = engine.compute<Meal>(
        meals: [lentilSoup],
        history: history,
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      // Level should be relaxed (> 0) because deltaDays (2) <= meatlessCooldownDays (5)
      expect(result.relaxationLevel, greaterThan(0));
    });

    test('calculateMealScore uses meatlessCooldownDays for legume and dairy recency score', () {
      final koshari = _createMeal(
        id: 1,
        name: 'كشري',
        proteinType: ProteinType.legume,
      );
      final cheeseOmelette = _createMeal(
        id: 2,
        name: 'عجة بالبيض والجبن',
        proteinType: ProteinType.dairy,
      );

      final cookedDate = wednesday.subtract(const Duration(days: 6));
      final history = {1: cookedDate, 2: cookedDate};

      // With meatlessCooldownDays = 2, deltaDays = 6:
      // sRecency = min(20.0, (6 - 2) / 2.0) = 2.0.
      // If it erroneously used cooldownDays = 14:
      // sRecency would be (6 - 14) / 2.0 = -4.0.
      final scoreLegume = engine.calculateMealScore(
        meal: koshari,
        lastCookedByMealId: history,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: 2,
      );

      final scoreDairy = engine.calculateMealScore(
        meal: cheeseOmelette,
        lastCookedByMealId: history,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: 2,
      );

      // Wednesday is not Friday, isFavorite is false, so total score == sRecency == 2.0
      expect(scoreLegume, closeTo(2.0, 0.001));
      expect(scoreDairy, closeTo(2.0, 0.001));
    });
  });

  group('CooldownEngine - R1: Second Card Carb Diversity', () {
    test('second card chooses diverse carbs when all remaining candidates share the same protein', () {
      // 4 chicken meals with different carbohydrates
      final chickenRice1 = _createMeal(
        id: 1,
        name: 'فراخ ورز 1',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
      );
      final chickenRice2 = _createMeal(
        id: 2,
        name: 'فراخ ورز 2',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
      );
      final chickenPasta = _createMeal(
        id: 3,
        name: 'فراخ ومكرونة',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.pasta,
      );
      final chickenBread = _createMeal(
        id: 4,
        name: 'ساندوتش فراخ بالعيش',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.bread,
      );

      final settings = _createSettings();

      final result = engine.compute<Meal>(
        meals: [chickenRice1, chickenRice2, chickenPasta, chickenBread],
        history: const [],
        settings: settings,
        today: wednesday,
        shuffleSeed: 0,
      );

      expect(result.recommendations, hasLength(3));
      final pickedCarbs = result.recommendations.map((m) => m.carbsType).toList();

      // Card 1 has rice
      expect(pickedCarbs[0], CarbsType.rice);
      // Card 2 MUST NOT have rice because chickenPasta was available to diversify carbs
      expect(
        pickedCarbs[1],
        isNot(equals(CarbsType.rice)),
        reason: 'Card 2 should enforce carb diversity when protein cannot be diversified',
      );
      // All 3 cards should have unique carbs
      expect(
        pickedCarbs.toSet(),
        hasLength(3),
        reason: 'All cards should have distinct carb types',
      );
    });

    test('second card gracefully falls back to rank order when carb diversity cannot be satisfied', () {
      // 3 chicken meals that ALL have rice
      final chickenRice1 = _createMeal(
        id: 1,
        name: 'فراخ ورز مصري',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
      );
      final chickenRice2 = _createMeal(
        id: 2,
        name: 'فراخ ورز بسمتي',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
      );
      final chickenRice3 = _createMeal(
        id: 3,
        name: 'فراخ ورز كاري',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
      );

      final settings = _createSettings();

      final result = engine.compute<Meal>(
        meals: [chickenRice1, chickenRice2, chickenRice3],
        history: const [],
        settings: settings,
        today: wednesday,
      );

      // Should still return all 3 meals without failing
      expect(result.recommendations, hasLength(3));
      expect(result.recommendations.map((m) => m.id).toSet(), {1, 2, 3});
    });
  });

  group('CooldownEngine - R1: Dead Code Removal & Relaxation Level 5', () {
    test('exhausted pool cleanly returns at relaxation level 5 without reaching dead fallback', () {
      final beefMeal = _createMeal(
        id: 1,
        name: 'لحمة ورز',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.rice,
      );

      // Cooked today -> deltaDays = 0, blocked through levels 0..4
      final history = [
        _createHistory(
          id: 1,
          mealId: 1,
          mealName: 'لحمة ورز',
          proteinType: ProteinType.beef,
          cookedAt: wednesday,
        ),
      ];

      final settings = _createSettings(cooldownDays: 30, beefCooldownDays: 30);

      final result = engine.compute<Meal>(
        meals: [beefMeal],
        history: history,
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      expect(result.relaxationLevel, 5);
      expect(result.isEmptyVault, isFalse);
    });

    test('empty meals list returns early with empty vault flag', () {
      final settings = _createSettings();

      final result = engine.compute<Meal>(
        meals: const [],
        history: const [],
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, isEmpty);
      expect(result.isEmptyVault, isTrue);
      expect(result.relaxationLevel, 5);
    });
  });
}
