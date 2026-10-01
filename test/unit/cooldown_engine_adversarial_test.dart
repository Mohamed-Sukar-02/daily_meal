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
  // Wednesday reference date (non-Friday)
  final wednesday = DateTime(2026, 10, 7, 12, 0);

  group('Adversarial Challenge - Recency Bonus Formulas & Date Edge Cases', () {
    test('deltaDays == meatlessCooldownDays produces exact score 0.0 for legume and dairy', () {
      const cooldown = 4;
      final koshari = _createMeal(id: 1, name: 'كشري', proteinType: ProteinType.legume);
      final labneh = _createMeal(id: 2, name: 'لبنة وجبنة', proteinType: ProteinType.dairy);

      final cookedDate = wednesday.subtract(const Duration(days: cooldown));
      final historyMap = {1: cookedDate, 2: cookedDate};

      final scoreLegume = engine.calculateMealScore(
        meal: koshari,
        lastCookedByMealId: historyMap,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: cooldown,
      );

      final scoreDairy = engine.calculateMealScore(
        meal: labneh,
        lastCookedByMealId: historyMap,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: cooldown,
      );

      // (4 - 4) / 2.0 = 0.0, non-Friday = 0, non-fav = 0
      expect(scoreLegume, equals(0.0));
      expect(scoreDairy, equals(0.0));
    });

    test('deltaDays == meatlessCooldownDays is filtered out at Level 0/1 and unlocked at Level 2', () {
      const cooldown = 6;
      final foul = _createMeal(id: 1, name: 'فول', proteinType: ProteinType.legume);
      final history = [
        _createHistory(
          id: 101,
          mealId: 1,
          mealName: 'فول',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: cooldown)),
        ),
      ];

      final settings = _createSettings(cooldownDays: 20, meatlessCooldownDays: cooldown);

      // At Level 0 & 1, effectiveCooldown = 6. deltaDays (6) <= 6 -> blocked.
      // At Level 2, effectiveCooldown = min(6, max(1, 6 ~/ 2)) = 3. deltaDays (6) <= 3 is FALSE -> unlocked!
      final result = engine.compute<Meal>(
        meals: [foul],
        history: history,
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      expect(result.relaxationLevel, equals(2));
    });

    test('deltaDays < meatlessCooldownDays yields negative recency score and unlocks at deeper relaxation levels', () {
      const cooldown = 6;
      final lentil = _createMeal(id: 1, name: 'شوربة عدس', proteinType: ProteinType.legume);
      final halloumi = _createMeal(id: 2, name: 'جبنة حلوم', proteinType: ProteinType.dairy);

      // Cooked 2 days ago (deltaDays = 2 < 6)
      final cookedDate = wednesday.subtract(const Duration(days: 2));
      final historyMap = {1: cookedDate, 2: cookedDate};

      // Score: (2 - 6) / 2.0 = -2.0
      final scoreLegume = engine.calculateMealScore(
        meal: lentil,
        lastCookedByMealId: historyMap,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: cooldown,
      );
      final scoreDairy = engine.calculateMealScore(
        meal: halloumi,
        lastCookedByMealId: historyMap,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: cooldown,
      );

      expect(scoreLegume, equals(-2.0));
      expect(scoreDairy, equals(-2.0));

      // In compute:
      // Level 0 & 1: effective = 6. 2 <= 6 -> blocked.
      // Level 2: effective = 3. 2 <= 3 -> blocked.
      // Level 3: effective = min(6, max(1, 6 ~/ 4)) = 1. 2 <= 1 is FALSE -> unlocked at Level 3!
      final result = engine.compute<Meal>(
        meals: [lentil],
        history: [
          _createHistory(
            id: 101,
            mealId: 1,
            mealName: 'شوربة عدس',
            proteinType: ProteinType.legume,
            cookedAt: cookedDate,
          ),
        ],
        settings: _createSettings(meatlessCooldownDays: cooldown),
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      expect(result.relaxationLevel, equals(3));
    });

    test('deltaDays > meatlessCooldownDays yields positive recency score and qualifies at Level 0', () {
      const cooldown = 3;
      final koshari = _createMeal(id: 1, name: 'كشري', proteinType: ProteinType.legume);
      final eggs = _createMeal(id: 2, name: 'بيض مقلي', proteinType: ProteinType.dairy);

      // Cooked 7 days ago (deltaDays = 7 > 3)
      final cookedDate = wednesday.subtract(const Duration(days: 7));
      final historyMap = {1: cookedDate, 2: cookedDate};

      // Score: (7 - 3) / 2.0 = 2.0
      final scoreLegume = engine.calculateMealScore(
        meal: koshari,
        lastCookedByMealId: historyMap,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: cooldown,
      );
      final scoreDairy = engine.calculateMealScore(
        meal: eggs,
        lastCookedByMealId: historyMap,
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: cooldown,
      );

      expect(scoreLegume, equals(2.0));
      expect(scoreDairy, equals(2.0));

      final result = engine.compute<Meal>(
        meals: [koshari, eggs],
        history: [
          _createHistory(
            id: 101,
            mealId: 1,
            mealName: 'كشري',
            proteinType: ProteinType.legume,
            cookedAt: cookedDate,
          ),
          _createHistory(
            id: 102,
            mealId: 2,
            mealName: 'بيض مقلي',
            proteinType: ProteinType.dairy,
            cookedAt: cookedDate,
          ),
        ],
        settings: _createSettings(meatlessCooldownDays: cooldown),
        today: wednesday,
      );

      expect(result.recommendations, hasLength(2));
      expect(result.relaxationLevel, equals(0));
    });

    test('recency score upper cap at 20.0 for extremely overdue legume and dairy meals', () {
      const cooldown = 2;
      final koshari = _createMeal(id: 1, name: 'كشري', proteinType: ProteinType.legume);

      // Cooked 100 days ago: (100 - 2) / 2.0 = 49.0 -> capped at 20.0
      final cookedDate = wednesday.subtract(const Duration(days: 100));
      final score = engine.calculateMealScore(
        meal: koshari,
        lastCookedByMealId: {1: cookedDate},
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: cooldown,
      );

      expect(score, equals(20.0));
    });

    test('never-cooked meals always receive 25.0 beating capped overdue score (20.0)', () {
      final koshariNever = _createMeal(id: 1, name: 'كشري جديد', proteinType: ProteinType.legume);
      final koshariOld = _createMeal(id: 2, name: 'كشري قديم', proteinType: ProteinType.legume);

      final scoreNever = engine.calculateMealScore(
        meal: koshariNever,
        lastCookedByMealId: {},
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: 2,
      );

      final scoreOld = engine.calculateMealScore(
        meal: koshariOld,
        lastCookedByMealId: {2: wednesday.subtract(const Duration(days: 120))},
        today: wednesday,
        cooldownDays: 14,
        meatlessCooldownDays: 2,
      );

      expect(scoreNever, equals(25.0));
      expect(scoreOld, equals(20.0));
      expect(scoreNever, greaterThan(scoreOld));
    });

    test('deltaDays == 0 (cooked today) blocked through levels 0..4 and only admitted at level 5', () {
      final shakshouka = _createMeal(id: 1, name: 'شكشوكة', proteinType: ProteinType.dairy);
      final history = [
        _createHistory(
          id: 101,
          mealId: 1,
          mealName: 'شكشوكة',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday, // today
        ),
      ];

      // Even with meatlessCooldownDays = 0, deltaDays == 0 is blocked at Level 4 (line 180: if (deltaDays == 0) return false)
      final result = engine.compute<Meal>(
        meals: [shakshouka],
        history: history,
        settings: _createSettings(meatlessCooldownDays: 0),
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      expect(result.relaxationLevel, equals(5));
    });
  });

  group('Adversarial Challenge - Card Diversity (Protein vs Carb Priorities)', () {
    test('protein diversity is strictly preferred first over carb diversity', () {
      // Setup pool:
      // Meal 1: Chicken + Rice (Highest score candidate)
      // Meal 2: Beef + Rice (Same carb 'rice', but NEW protein 'beef')
      // Meal 3: Chicken + Pasta (New carb 'pasta', but DUPLICATE protein 'chicken')
      // Meal 4: Fish + Rice (Same carb 'rice', but NEW protein 'fish')
      // Meal 5: Chicken + Bread (New carb 'bread', but DUPLICATE protein 'chicken')

      final m1 = _createMeal(id: 1, name: 'فراخ ورز', proteinType: ProteinType.chicken, carbsType: CarbsType.rice);
      final m2 = _createMeal(id: 2, name: 'لحمة ورز', proteinType: ProteinType.beef, carbsType: CarbsType.rice);
      final m3 = _createMeal(id: 3, name: 'فراخ ومكرونة', proteinType: ProteinType.chicken, carbsType: CarbsType.pasta);
      final m4 = _createMeal(id: 4, name: 'سمك ورز', proteinType: ProteinType.fish, carbsType: CarbsType.rice);
      final m5 = _createMeal(id: 5, name: 'فراخ وعيش', proteinType: ProteinType.chicken, carbsType: CarbsType.bread);

      // Force high scores for all meals, but id 1 > 2 > 3 > 4 > 5
      // To ensure pure ranking order before diversity selection, cook them at different intervals:
      // deltaDays for 1: 50 days (score 20)
      // deltaDays for 2: 40 days (score 19)
      // deltaDays for 3: 30 days (score 14)
      // deltaDays for 4: 25 days (score 10.5)
      // deltaDays for 5: 20 days (score 9)
      // Note: bands are floor(score / 5.0).
      // Band 4: score 20..24
      // Let's give all meals identical band and test deterministic diversity selection.
      final result = engine.compute<Meal>(
        meals: [m1, m2, m3, m4, m5],
        history: const [], // All never cooked -> identical score 25.0
        settings: _createSettings(),
        today: wednesday,
        shuffleSeed: 42,
      );

      expect(result.recommendations, hasLength(3));
      final pickedProteins = result.recommendations.map((m) => m.proteinType).toSet();

      // Crucial assertion: 3 different proteins MUST be selected even though multiple meals shared the same carb (rice)
      expect(
        pickedProteins.length,
        equals(3),
        reason: 'Selection must prioritize 3 distinct proteins ({chicken, beef, fish}) before considering carb variety',
      );
    });

    test('protein diversity is preferred first over higher rank, and carb diversity fallback is preferred when protein is exhausted', () {
      // Four meals with strictly separated score bands:
      // Meal 1 (Band 4, score 20): Chicken + Rice
      // Meal 2 (Band 3, score 15): Chicken + Rice (higher rank than 3 and 4)
      // Meal 3 (Band 2, score 10): Beef + Rice (lower rank than 2, same carb as 1 & 2, but NOVEL PROTEIN)
      // Meal 4 (Band 1, score 5):  Chicken + Pasta (lowest rank, duplicate protein, but NOVEL CARB)
      final m1 = _createMeal(id: 1, name: 'فراخ ورز 1', proteinType: ProteinType.chicken, carbsType: CarbsType.rice);
      final m2 = _createMeal(id: 2, name: 'فراخ ورز 2', proteinType: ProteinType.chicken, carbsType: CarbsType.rice);
      final m3 = _createMeal(id: 3, name: 'لحمة ورز', proteinType: ProteinType.beef, carbsType: CarbsType.rice);
      final m4 = _createMeal(id: 4, name: 'فراخ ومكرونة', proteinType: ProteinType.chicken, carbsType: CarbsType.pasta);

      final history = [
        _createHistory(id: 101, mealId: 1, mealName: 'm1', proteinType: ProteinType.chicken, cookedAt: wednesday.subtract(const Duration(days: 42))),
        _createHistory(id: 102, mealId: 2, mealName: 'm2', proteinType: ProteinType.chicken, cookedAt: wednesday.subtract(const Duration(days: 32))),
        _createHistory(id: 103, mealId: 3, mealName: 'm3', proteinType: ProteinType.beef, cookedAt: wednesday.subtract(const Duration(days: 22))),
        _createHistory(id: 104, mealId: 4, mealName: 'm4', proteinType: ProteinType.chicken, cookedAt: wednesday.subtract(const Duration(days: 12))),
      ];

      final result = engine.compute<Meal>(
        meals: [m1, m2, m3, m4],
        history: history,
        settings: _createSettings(chickenCooldownDays: 2, beefCooldownDays: 2),
        today: wednesday,
      );

      expect(result.recommendations, hasLength(3));

      // Card 1 must be m1 (highest score)
      expect(result.recommendations[0].id, equals(1));
      expect(result.recommendations[0].proteinType, equals(ProteinType.chicken));
      expect(result.recommendations[0].carbsType, equals(CarbsType.rice));

      // Card 2 must be m3 (Beef + Rice) because Protein Diversity strictly beats higher rank (m2) and carb diversity (m4)
      expect(result.recommendations[1].id, equals(3), reason: 'Card 2 must pick m3 for protein diversity, skipping higher-ranked m2');
      expect(result.recommendations[1].proteinType, equals(ProteinType.beef));
      expect(result.recommendations[1].carbsType, equals(CarbsType.rice));

      // Card 3: Proteins {chicken, beef} are exhausted among remaining (m2 & m4 are chicken).
      // Carb diversity fallback MUST skip higher-ranked m2 (Rice) and pick m4 (Pasta)!
      expect(result.recommendations[2].id, equals(4), reason: 'Card 3 must pick m4 for carb diversity fallback, skipping higher-ranked m2');
      expect(result.recommendations[2].proteinType, equals(ProteinType.chicken));
      expect(result.recommendations[2].carbsType, equals(CarbsType.pasta));
    });

    test('single protein pool enforces carb diversity across all 3 cards', () {
      // All 4 meals are Beef, but have different carbs
      final bRice = _createMeal(id: 1, name: 'لحمة ورز', proteinType: ProteinType.beef, carbsType: CarbsType.rice);
      final bRice2 = _createMeal(id: 2, name: 'كباب حلة ورز', proteinType: ProteinType.beef, carbsType: CarbsType.rice);
      final bPasta = _createMeal(id: 3, name: 'لحمة ومكرونة', proteinType: ProteinType.beef, carbsType: CarbsType.pasta);
      final bBread = _createMeal(id: 4, name: 'حواوشي عيش', proteinType: ProteinType.beef, carbsType: CarbsType.bread);

      final result = engine.compute<Meal>(
        meals: [bRice, bRice2, bPasta, bBread],
        history: const [],
        settings: _createSettings(),
        today: wednesday,
        shuffleSeed: 0,
      );

      expect(result.recommendations, hasLength(3));
      final carbs = result.recommendations.map((m) => m.carbsType).toList();

      expect(carbs[0], equals(CarbsType.rice));
      expect(carbs[1], isNot(equals(CarbsType.rice)), reason: 'Card 2 must not repeat rice');
      expect(carbs[2], isNot(equals(CarbsType.rice)), reason: 'Card 3 must not repeat rice');
      expect(carbs.toSet().length, equals(3), reason: 'All 3 cards must have distinct carbs');
    });

    test('pool with identical protein and identical carb handles graceful fallback without error', () {
      // 3 fish meals with rice
      final f1 = _createMeal(id: 1, name: 'سمك 1', proteinType: ProteinType.fish, carbsType: CarbsType.rice);
      final f2 = _createMeal(id: 2, name: 'سمك 2', proteinType: ProteinType.fish, carbsType: CarbsType.rice);
      final f3 = _createMeal(id: 3, name: 'سمك 3', proteinType: ProteinType.fish, carbsType: CarbsType.rice);

      final result = engine.compute<Meal>(
        meals: [f1, f2, f3],
        history: const [],
        settings: _createSettings(),
        today: wednesday,
      );

      expect(result.recommendations, hasLength(3));
      expect(result.recommendations.map((m) => m.id).toSet(), equals({1, 2, 3}));
    });

    test('diversity selection with excludeIds preserves novelty while maintaining variety hierarchy', () {
      final m1 = _createMeal(id: 1, name: 'فراخ ورز', proteinType: ProteinType.chicken, carbsType: CarbsType.rice);
      final m2 = _createMeal(id: 2, name: 'لحمة ورز', proteinType: ProteinType.beef, carbsType: CarbsType.rice);
      final m3 = _createMeal(id: 3, name: 'سمك ومكرونة', proteinType: ProteinType.fish, carbsType: CarbsType.pasta);
      final m4 = _createMeal(id: 4, name: 'فراخ وعيش', proteinType: ProteinType.chicken, carbsType: CarbsType.bread);

      // Exclude meal 1 (already on screen)
      final result = engine.compute<Meal>(
        meals: [m1, m2, m3, m4],
        history: const [],
        settings: _createSettings(),
        today: wednesday,
        excludeIds: {1},
      );

      expect(result.recommendations, hasLength(3));
      expect(result.recommendations.map((m) => m.id), isNot(contains(1)));
      expect(result.repeatedIds, isEmpty);
    });

    test('protein diversity operates across all protein types (chicken, beef, fish, legume, dairy)', () {
      final m1 = _createMeal(id: 1, name: 'كشري', proteinType: ProteinType.legume, carbsType: CarbsType.rice);
      final m2 = _createMeal(id: 2, name: 'فول ورز', proteinType: ProteinType.legume, carbsType: CarbsType.rice);
      final m3 = _createMeal(id: 3, name: 'جبنة قريش', proteinType: ProteinType.dairy, carbsType: CarbsType.rice);
      final m4 = _createMeal(id: 4, name: 'سمك مشوي', proteinType: ProteinType.fish, carbsType: CarbsType.rice);

      final result = engine.compute<Meal>(
        meals: [m1, m2, m3, m4],
        history: const [],
        settings: _createSettings(),
        today: wednesday,
        shuffleSeed: 10,
      );

      expect(result.recommendations, hasLength(3));
      final distinctProteins = result.recommendations.map((m) => m.proteinType).toSet();
      expect(distinctProteins.length, equals(3), reason: 'Must pick 3 distinct protein types (e.g. legume, dairy, fish)');
    });
  });

  group('Adversarial Challenge - Exact Mathematical Relaxation Boundaries', () {
    test('cooldown = 8 unlocks exactly at level 0, 2, 3, 4, 5 based on deltaDays threshold', () {
      const cooldown = 8;
      // Effective cooldowns for cooldown=8:
      // Level 0 & 1: 8 (requires deltaDays > 8 -> 9+)
      // Level 2: 8 ~/ 2 = 4 (requires deltaDays > 4 -> 5+)
      // Level 3: 8 ~/ 4 = 2 (requires deltaDays > 2 -> 3+)
      // Level 4: 1 (requires deltaDays > 0 -> 1+)
      // Level 5: 0 (unconditional, deltaDays >= 0)

      final testCases = [
        {'deltaDays': 9, 'expectedLevel': 0},
        {'deltaDays': 8, 'expectedLevel': 2}, // 8 <= 8 (lvl 0,1 blocked), 8 > 4 (lvl 2 allowed)
        {'deltaDays': 5, 'expectedLevel': 2}, // 5 > 4 (lvl 2 allowed)
        {'deltaDays': 4, 'expectedLevel': 3}, // 4 <= 4 (lvl 2 blocked), 4 > 2 (lvl 3 allowed)
        {'deltaDays': 3, 'expectedLevel': 3}, // 3 > 2 (lvl 3 allowed)
        {'deltaDays': 2, 'expectedLevel': 4}, // 2 <= 2 (lvl 3 blocked), 2 > 0 (lvl 4 allowed)
        {'deltaDays': 1, 'expectedLevel': 4}, // 1 > 0 (lvl 4 allowed)
        {'deltaDays': 0, 'expectedLevel': 5}, // 0 blocked at lvl 4, allowed at lvl 5
      ];

      for (final tc in testCases) {
        final deltaDays = tc['deltaDays'] as int;
        final expectedLevel = tc['expectedLevel'] as int;

        final meal = _createMeal(id: 1, name: 'عدس', proteinType: ProteinType.legume);
        final history = [
          _createHistory(
            id: 1,
            mealId: 1,
            mealName: 'عدس',
            proteinType: ProteinType.legume,
            cookedAt: wednesday.subtract(Duration(days: deltaDays)),
          ),
        ];

        final result = engine.compute<Meal>(
          meals: [meal],
          history: history,
          settings: _createSettings(meatlessCooldownDays: cooldown),
          today: wednesday,
        );

        expect(
          result.relaxationLevel,
          equals(expectedLevel),
          reason: 'deltaDays=$deltaDays with cooldown=$cooldown must unlock at relaxation level $expectedLevel',
        );
      }
    });

    test('leap year and year transition boundaries correctly compute deltaDays and recency bonus', () {
      // Leap day: 2024-02-29
      final leapDay = DateTime(2024, 2, 29, 10, 0);
      final afterLeap = DateTime(2024, 3, 2, 10, 0); // 2 days later

      final meal = _createMeal(id: 1, name: 'كشري', proteinType: ProteinType.legume);
      final score = engine.calculateMealScore(
        meal: meal,
        lastCookedByMealId: {1: leapDay},
        today: afterLeap,
        cooldownDays: 14,
        meatlessCooldownDays: 0,
      );

      // deltaDays = 2 across leap day. (2 - 0) / 2.0 = 1.0
      expect(score, equals(1.0));
    });

    test('history with multiple entries takes latest cooked date and ignores earlier ones', () {
      final meal = _createMeal(id: 1, name: 'بيض', proteinType: ProteinType.dairy);
      final history = [
        _createHistory(
          id: 1,
          mealId: 1,
          mealName: 'بيض',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 30)),
        ),
        _createHistory(
          id: 2,
          mealId: 1,
          mealName: 'بيض',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 1)), // most recent
        ),
        _createHistory(
          id: 3,
          mealId: 1,
          mealName: 'بيض',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 15)),
        ),
      ];

      // With meatlessCooldownDays = 3, deltaDays should be 1 (from most recent entry), so 1 <= 3 -> blocked at level 0
      final result = engine.compute<Meal>(
        meals: [meal],
        history: history,
        settings: _createSettings(meatlessCooldownDays: 3),
        today: wednesday,
      );

      expect(result.relaxationLevel, greaterThan(0), reason: 'Must use latest cooked date (1 day ago) not 30 days ago');
    });

    test('performance and stability under stress load (1000 meals pool)', () {
      final bigPool = List.generate(1000, (i) {
        final p = ProteinType.values[i % ProteinType.values.length];
        final c = CarbsType.values[i % CarbsType.values.length];
        return _createMeal(id: i + 1, name: 'وجبة $i', proteinType: p, carbsType: c);
      });

      final history = List.generate(200, (i) {
        return _createHistory(
          id: i + 1,
          mealId: i + 1,
          mealName: 'وجبة $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          cookedAt: wednesday.subtract(Duration(days: (i % 20) + 1)),
        );
      });

      final stopwatch = Stopwatch()..start();
      final result = engine.compute<Meal>(
        meals: bigPool,
        history: history,
        settings: _createSettings(),
        today: wednesday,
      );
      stopwatch.stop();

      expect(result.recommendations, hasLength(3));
      expect(result.relaxationLevel, equals(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000), reason: 'Large pool must compute in under 1 second even under parallel test load');
    });
  });
}
