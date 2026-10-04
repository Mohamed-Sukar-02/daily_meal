import 'dart:math';
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
  final wednesday = DateTime(2026, 10, 7, 12, 0);

  group('CHALLENGER STRESS SUITE: Legume & Dairy Exclusively in Candidate Pool', () {
    test('10-meal pool of exclusively legume and dairy with varying cooking dates', () {
      final settings = _createSettings(
        cooldownDays: 14, // Global default is 14 days
        meatlessCooldownDays: 3, // Meatless cooldown is 3 days
      );

      final meals = [
        _createMeal(
          id: 1,
          name: 'عدس أصفر',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.bread,
        ),
        _createMeal(
          id: 2,
          name: 'فول مدمس',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.bread,
        ),
        _createMeal(
          id: 3,
          name: 'لوبيا بالأرز',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
        ),
        _createMeal(
          id: 4,
          name: 'فاصوليا بيضاء',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
        ),
        _createMeal(
          id: 5,
          name: 'كشري مصري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.pasta,
        ),
        _createMeal(
          id: 6,
          name: 'جبنة قريش بالطماطم',
          proteinType: ProteinType.dairy,
          carbsType: CarbsType.bread,
        ),
        _createMeal(
          id: 7,
          name: 'شكشوكة بيض بالجبن',
          proteinType: ProteinType.dairy,
          carbsType: CarbsType.bread,
        ),
        _createMeal(
          id: 8,
          name: 'عجة مصرية',
          proteinType: ProteinType.dairy,
          carbsType: CarbsType.bread,
        ),
        _createMeal(
          id: 9,
          name: 'بيض مسلوق وسلطة',
          proteinType: ProteinType.dairy,
          carbsType: CarbsType.potato,
        ),
        _createMeal(
          id: 10,
          name: 'صينية بطاطس بالجبن',
          proteinType: ProteinType.dairy,
          carbsType: CarbsType.potato,
        ),
      ];

      // Cooking history dates:
      // Meals 1 & 6: cooked today (delta 0) -> blocked at level 0
      // Meals 2 & 7: cooked 1 day ago (delta 1) -> blocked at level 0 (1 <= 3)
      // Meals 3 & 8: cooked 3 days ago (delta 3) -> blocked at level 0 (3 <= 3)
      // Meal 4: cooked 4 days ago (delta 4) -> ELIGIBLE at level 0 (4 > 3, but 4 <= 14!)
      // Meal 5: cooked 10 days ago (delta 10) -> ELIGIBLE at level 0 (10 > 3, but 10 <= 14!)
      // Meal 9: cooked 20 days ago (delta 20) -> ELIGIBLE at level 0 (20 > 3)
      // Meal 10: never cooked -> ELIGIBLE at level 0
      final history = [
        _createHistory(
          id: 1,
          mealId: 1,
          mealName: 'عدس أصفر',
          proteinType: ProteinType.legume,
          cookedAt: wednesday,
        ),
        _createHistory(
          id: 2,
          mealId: 6,
          mealName: 'جبنة قريش بالطماطم',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday,
        ),
        _createHistory(
          id: 3,
          mealId: 2,
          mealName: 'فول مدمس',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 1)),
        ),
        _createHistory(
          id: 4,
          mealId: 7,
          mealName: 'شكشوكة بيض بالجبن',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 1)),
        ),
        _createHistory(
          id: 5,
          mealId: 3,
          mealName: 'لوبيا بالأرز',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 3)),
        ),
        _createHistory(
          id: 6,
          mealId: 8,
          mealName: 'عجة مصرية',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 3)),
        ),
        _createHistory(
          id: 7,
          mealId: 4,
          mealName: 'فاصوليا بيضاء',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 4)),
        ),
        _createHistory(
          id: 8,
          mealId: 5,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 10)),
        ),
        _createHistory(
          id: 9,
          mealId: 9,
          mealName: 'بيض مسلوق وسلطة',
          proteinType: ProteinType.dairy,
          cookedAt: wednesday.subtract(const Duration(days: 20)),
        ),
      ];

      final result = engine.compute<Meal>(
        meals: meals,
        history: history,
        settings: settings,
        today: wednesday,
      );

      // Exactly 4 meals eligible at level 0: IDs 4, 5, 9, 10.
      // Since targetCount is 3, level 0 has enough candidates (4 >= 3).
      // If legume/dairy erroneously fell back to 14 days, only IDs 9 and 10 would be eligible (2 < 3),
      // which would have forced relaxationLevel > 0!
      expect(
        result.relaxationLevel,
        0,
        reason:
            'Must stay at level 0 because 4 legume/dairy meals are past meatlessCooldown (3 days)',
      );
      expect(result.recommendations, hasLength(3));

      // All returned recommendations must be from the eligible set {4, 5, 9, 10}
      final recommendedIds = result.recommendations.map((m) => m.id).toSet();
      expect(recommendedIds.difference({4, 5, 9, 10}), isEmpty);

      // Check protein diversity: both legume and dairy must be present in the 3 cards
      final recommendedProteins = result.recommendations
          .map((m) => m.proteinType)
          .toSet();
      expect(recommendedProteins.contains(ProteinType.legume), isTrue);
      expect(recommendedProteins.contains(ProteinType.dairy), isTrue);
    });

    test(
      'calculateMealScore verification against mathematical oracle across 30 days',
      () {
        const cooldownDays = 14;
        const meatlessCooldownDays = 2;

        for (int delta = 0; delta <= 30; delta++) {
          final cookedDate = wednesday.subtract(Duration(days: delta));
          final historyMap = {100: cookedDate, 200: cookedDate};

          final legumeMeal = _createMeal(
            id: 100,
            name: 'عدس',
            proteinType: ProteinType.legume,
          );
          final dairyMeal = _createMeal(
            id: 200,
            name: 'بيض',
            proteinType: ProteinType.dairy,
          );

          final legumeScore = engine.calculateMealScore(
            meal: legumeMeal,
            lastCookedByMealId: historyMap,
            today: wednesday,
            cooldownDays: cooldownDays,
            meatlessCooldownDays: meatlessCooldownDays,
          );

          final dairyScore = engine.calculateMealScore(
            meal: dairyMeal,
            lastCookedByMealId: historyMap,
            today: wednesday,
            cooldownDays: cooldownDays,
            meatlessCooldownDays: meatlessCooldownDays,
          );

          // Expected oracle: sRecency = min(20.0, (delta - meatlessCooldownDays) / 2.0)
          final expectedRecency = min(
            20.0,
            (delta - meatlessCooldownDays) / 2.0,
          );
          // On Wednesday (not Friday) and not favorite: totalScore == sRecency
          expect(
            legumeScore,
            closeTo(expectedRecency, 0.0001),
            reason: 'Legume delta $delta score mismatch',
          );
          expect(
            dairyScore,
            closeTo(expectedRecency, 0.0001),
            reason: 'Dairy delta $delta score mismatch',
          );

          // Confirm that the score is strictly DIFFERENT from what a 14-day global cooldown would yield
          if (delta != meatlessCooldownDays && delta < 20) {
            final badRecency = min(20.0, (delta - cooldownDays) / 2.0);
            expect(legumeScore, isNot(closeTo(badRecency, 0.0001)));
          }
        }
      },
    );
  });

  group('CHALLENGER STRESS SUITE: Single-Protein Candidate Pool Carb Diversity', () {
    test(
      '5 chicken dishes with distinct carbs across 100 random seeds: Card 1 & Card 2 NEVER share carbs',
      () {
        final chickenDishes = [
          _createMeal(
            id: 1,
            name: 'فراخ بالارز',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.rice,
          ),
          _createMeal(
            id: 2,
            name: 'فراخ بالمكرونة',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.pasta,
          ),
          _createMeal(
            id: 3,
            name: 'فراخ بالعيش',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.bread,
          ),
          _createMeal(
            id: 4,
            name: 'فراخ بالبطاطس',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.potato,
          ),
          _createMeal(
            id: 5,
            name: 'فراخ بالفريك',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.grains,
          ),
        ];

        final settings = _createSettings();

        for (int seed = 0; seed < 100; seed++) {
          final result = engine.compute<Meal>(
            meals: chickenDishes,
            history: const [],
            settings: settings,
            today: wednesday,
            shuffleSeed: seed,
          );

          expect(result.recommendations, hasLength(3));

          final card1Carb = result.recommendations[0].carbsType;
          final card2Carb = result.recommendations[1].carbsType;
          final card3Carb = result.recommendations[2].carbsType;

          // CRITICAL INVARIANT: Card 1 and Card 2 must ALWAYS have different carbs
          expect(
            card2Carb,
            isNot(equals(card1Carb)),
            reason:
                'Seed $seed: Card 1 and Card 2 got identical carb ($card1Carb)',
          );

          // Since 5 distinct carbs are available, all 3 cards must have mutually unique carbs
          final carbSet = {card1Carb, card2Carb, card3Carb};
          expect(
            carbSet.length,
            3,
            reason:
                'Seed $seed: Cards do not have 3 distinct carbs (got $carbSet)',
          );
        }
      },
    );

    test(
      'Single-protein pool with only 2 carb types (3 Rice, 2 Pasta): Card 1 & 2 distinct, Card 3 graceful fallback',
      () {
        final beefDishes = [
          _createMeal(
            id: 1,
            name: 'كباب حلة ورز 1',
            proteinType: ProteinType.beef,
            carbsType: CarbsType.rice,
          ),
          _createMeal(
            id: 2,
            name: 'كباب حلة ورز 2',
            proteinType: ProteinType.beef,
            carbsType: CarbsType.rice,
          ),
          _createMeal(
            id: 3,
            name: 'كباب حلة ورز 3',
            proteinType: ProteinType.beef,
            carbsType: CarbsType.rice,
          ),
          _createMeal(
            id: 4,
            name: 'ستيك ومكرونة 1',
            proteinType: ProteinType.beef,
            carbsType: CarbsType.pasta,
          ),
          _createMeal(
            id: 5,
            name: 'ستيك ومكرونة 2',
            proteinType: ProteinType.beef,
            carbsType: CarbsType.pasta,
          ),
        ];

        final settings = _createSettings();

        for (int seed = 0; seed < 50; seed++) {
          final result = engine.compute<Meal>(
            meals: beefDishes,
            history: const [],
            settings: settings,
            today: wednesday,
            shuffleSeed: seed,
          );

          expect(result.recommendations, hasLength(3));

          final c1 = result.recommendations[0].carbsType;
          final c2 = result.recommendations[1].carbsType;
          final c3 = result.recommendations[2].carbsType;

          // Card 1 and Card 2 must have distinct carbs
          expect(
            c2,
            isNot(equals(c1)),
            reason: 'Seed $seed: Card 1 and 2 shared carb $c1',
          );

          // Card 3 must be one of the available carbs without crash
          expect([CarbsType.rice, CarbsType.pasta].contains(c3), isTrue);

          // All 3 recommended meal IDs must be distinct
          final idSet = result.recommendations.map((m) => m.id).toSet();
          expect(idSet.length, 3);
        }
      },
    );

    test(
      'Single-protein pool with only 1 carb type (All Bread): No crash, deterministic fallback',
      () {
        final fishDishes = [
          _createMeal(
            id: 1,
            name: 'ساندوتش جمبري 1',
            proteinType: ProteinType.fish,
            carbsType: CarbsType.bread,
          ),
          _createMeal(
            id: 2,
            name: 'ساندوتش جمبري 2',
            proteinType: ProteinType.fish,
            carbsType: CarbsType.bread,
          ),
          _createMeal(
            id: 3,
            name: 'ساندوتش تونة',
            proteinType: ProteinType.fish,
            carbsType: CarbsType.bread,
          ),
        ];

        final settings = _createSettings();
        final result = engine.compute<Meal>(
          meals: fishDishes,
          history: const [],
          settings: settings,
          today: wednesday,
        );

        expect(result.recommendations, hasLength(3));
        final idSet = result.recommendations.map((m) => m.id).toSet();
        expect(idSet, {1, 2, 3});
      },
    );

    test(
      'Single-protein 2-dish pool: targetCount = 2, distinct carbs verified',
      () {
        final twoDishes = [
          _createMeal(
            id: 1,
            name: 'شاورما دجاج عيش',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.bread,
          ),
          _createMeal(
            id: 2,
            name: 'شاورما دجاج فتة رز',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.rice,
          ),
        ];

        final settings = _createSettings();
        final result = engine.compute<Meal>(
          meals: twoDishes,
          history: const [],
          settings: settings,
          today: wednesday,
        );

        expect(result.recommendations, hasLength(2));
        expect(
          result.recommendations[0].carbsType,
          isNot(equals(result.recommendations[1].carbsType)),
        );
      },
    );
  });

  group('CHALLENGER STRESS SUITE: Extreme Relaxation Level 5 Stability', () {
    test(
      'Severe starvation: all 10 meals cooked today, long cooldown settings',
      () {
        final meals = [
          _createMeal(id: 1, name: 'دجاج 1', proteinType: ProteinType.chicken),
          _createMeal(id: 2, name: 'دجاج 2', proteinType: ProteinType.chicken),
          _createMeal(id: 3, name: 'لحم 1', proteinType: ProteinType.beef),
          _createMeal(id: 4, name: 'لحم 2', proteinType: ProteinType.beef),
          _createMeal(id: 5, name: 'سمك 1', proteinType: ProteinType.fish),
          _createMeal(id: 6, name: 'سمك 2', proteinType: ProteinType.fish),
          _createMeal(id: 7, name: 'عدس', proteinType: ProteinType.legume),
          _createMeal(id: 8, name: 'فول', proteinType: ProteinType.legume),
          _createMeal(id: 9, name: 'جبنة', proteinType: ProteinType.dairy),
          _createMeal(id: 10, name: 'بيض', proteinType: ProteinType.dairy),
        ];

        // All meals cooked today (deltaDays = 0)
        final history = meals.map((m) {
          return _createHistory(
            id: m.id * 10,
            mealId: m.id,
            mealName: m.name,
            proteinType: m.proteinType,
            cookedAt: wednesday,
          );
        }).toList();

        final settings = _createSettings(
          cooldownDays: 30,
          chickenCooldownDays: 30,
          beefCooldownDays: 30,
          fishCooldownDays: 30,
          meatlessCooldownDays: 30,
        );

        // In levels 0..4, all meals are rejected because deltaDays == 0.
        // At level 5, all meals must be accepted.
        final result = engine.compute<Meal>(
          meals: meals,
          history: history,
          settings: settings,
          today: wednesday,
        );

        expect(result.relaxationLevel, 5);
        expect(result.recommendations, hasLength(3));
        expect(result.isEmptyVault, isFalse);

        // Verify all recommended meals are valid unique objects
        final ids = result.recommendations.map((m) => m.id).toSet();
        expect(ids.length, 3);
      },
    );

    test(
      'Starvation with all meals excluded in refresh (excludeIds contains all vault IDs)',
      () {
        final meals = [
          _createMeal(
            id: 1,
            name: 'دجاج',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.rice,
          ),
          _createMeal(
            id: 2,
            name: 'لحم',
            proteinType: ProteinType.beef,
            carbsType: CarbsType.pasta,
          ),
          _createMeal(
            id: 3,
            name: 'سمك',
            proteinType: ProteinType.fish,
            carbsType: CarbsType.bread,
          ),
        ];

        final history = meals.map((m) {
          return _createHistory(
            id: m.id * 10,
            mealId: m.id,
            mealName: m.name,
            proteinType: m.proteinType,
            cookedAt: wednesday,
          );
        }).toList();

        final settings = _createSettings(cooldownDays: 30);

        // Pass all 3 meal IDs in excludeIds
        final result = engine.compute<Meal>(
          meals: meals,
          history: history,
          settings: settings,
          today: wednesday,
          excludeIds: {1, 2, 3},
        );

        expect(result.relaxationLevel, 5);
        expect(result.recommendations, hasLength(3));
        expect(result.repeatedIds, containsAll([1, 2, 3]));
        expect(result.repeatedIds.length, 3);
      },
    );

    test('Single-meal vault cooked today reaches level 5 safely', () {
      final singleMeal = _createMeal(
        id: 42,
        name: 'أكلة وحيدة',
        proteinType: ProteinType.chicken,
      );
      final history = [
        _createHistory(
          id: 1,
          mealId: 42,
          mealName: 'أكلة وحيدة',
          proteinType: ProteinType.chicken,
          cookedAt: wednesday,
        ),
      ];

      final settings = _createSettings(cooldownDays: 14);
      final result = engine.compute<Meal>(
        meals: [singleMeal],
        history: history,
        settings: settings,
        today: wednesday,
      );

      expect(result.recommendations, hasLength(1));
      expect(result.recommendations.first.id, 42);
      expect(result.relaxationLevel, 5);
      expect(result.isEmptyVault, isFalse);
    });

    test(
      'Empty vault returns immediately without reaching relaxation loop',
      () {
        final settings = _createSettings();
        final result = engine.compute<Meal>(
          meals: const [],
          history: const [],
          settings: settings,
          today: wednesday,
        );

        expect(result.recommendations, isEmpty);
        expect(result.relaxationLevel, 5);
        expect(result.isEmptyVault, isTrue);
        expect(result.repeatedIds, isEmpty);
      },
    );
  });

  group('CHALLENGER STRESS SUITE: Large Scale Randomized Harness (Fuzz Testing)', () {
    test(
      '500-meal randomized pool executes under 200ms and satisfies all structural invariants',
      () {
        final rng = Random(42);
        const proteins = [
          ProteinType.chicken,
          ProteinType.beef,
          ProteinType.fish,
          ProteinType.legume,
          ProteinType.dairy,
        ];
        const carbs = [
          CarbsType.rice,
          CarbsType.pasta,
          CarbsType.bread,
          CarbsType.potato,
          CarbsType.grains,
          CarbsType.none,
        ];

        final meals = List.generate(500, (i) {
          return _createMeal(
            id: i + 1,
            name: 'وجبة تجريبية ${i + 1}',
            proteinType: proteins[rng.nextInt(proteins.length)],
            carbsType: carbs[rng.nextInt(carbs.length)],
            isFavorite: rng.nextBool(),
            isFridaySpecial: rng.nextBool(),
          );
        });

        // Random history for 300 meals
        final history = List.generate(300, (i) {
          final daysAgo = rng.nextInt(60);
          final meal = meals[rng.nextInt(meals.length)];
          return _createHistory(
            id: i + 1,
            mealId: meal.id,
            mealName: meal.name,
            proteinType: meal.proteinType,
            cookedAt: wednesday.subtract(Duration(days: daysAgo)),
          );
        });

        final settings = _createSettings(
          cooldownDays: 14,
          chickenCooldownDays: 3,
          beefCooldownDays: 3,
          fishCooldownDays: 5,
          meatlessCooldownDays: 1,
        );

        final stopwatch = Stopwatch()..start();

        // Run 20 iterations with different seeds
        for (int i = 0; i < 20; i++) {
          final result = engine.compute<Meal>(
            meals: meals,
            history: history,
            settings: settings,
            today: wednesday,
            shuffleSeed: i * 7,
          );

          expect(result.recommendations, hasLength(3));
          expect(
            result.recommendations.map((m) => m.id).toSet().length,
            3,
            reason: 'Duplicate meal returned in 3 cards',
          );
        }

        stopwatch.stop();
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason:
              '20 runs of 500-meal pool took ${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );

    test(
      'Seeded lottery idempotency: identical seed produces identical recommendation order',
      () {
        final meals = List.generate(10, (i) {
          return _createMeal(
            id: i + 1,
            name: 'وجبة $i',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.values[i % CarbsType.values.length],
          );
        });

        final settings = _createSettings();

        final run1 = engine.compute<Meal>(
          meals: meals,
          history: const [],
          settings: settings,
          today: wednesday,
          shuffleSeed: 12345,
        );

        final run2 = engine.compute<Meal>(
          meals: meals,
          history: const [],
          settings: settings,
          today: wednesday,
          shuffleSeed: 12345,
        );

        final ids1 = run1.recommendations.map((m) => m.id).toList();
        final ids2 = run2.recommendations.map((m) => m.id).toList();

        expect(
          ids1,
          equals(ids2),
          reason:
              'Identical shuffle seed must produce identical recommendations',
        );
      },
    );
  });

  group('CHALLENGER STRESS SUITE: Adversarial Edge Cases & Boundaries', () {
    test(
      'Out-of-order history entries: engine correctly selects the most recent cooking date',
      () {
        final meal = _createMeal(
          id: 1,
          name: 'شوربة عدس',
          proteinType: ProteinType.legume,
        );
        final olderDate = wednesday.subtract(const Duration(days: 20));
        final newerDate = wednesday.subtract(
          const Duration(days: 1),
        ); // yesterday

        // Insert older date AFTER newer date
        final history = [
          _createHistory(
            id: 1,
            mealId: 1,
            mealName: 'شوربة عدس',
            proteinType: ProteinType.legume,
            cookedAt: newerDate,
          ),
          _createHistory(
            id: 2,
            mealId: 1,
            mealName: 'شوربة عدس',
            proteinType: ProteinType.legume,
            cookedAt: olderDate,
          ),
        ];

        // With meatlessCooldownDays = 2, yesterday (delta 1) is blocked at level 0.
        // If the engine incorrectly overwrote newer with older (delta 20), it would be accepted at level 0.
        final result = engine.compute<Meal>(
          meals: [meal],
          history: history,
          settings: _createSettings(cooldownDays: 14, meatlessCooldownDays: 2),
          today: wednesday,
        );

        expect(
          result.relaxationLevel,
          greaterThan(0),
          reason: 'Most recent date (yesterday) must govern cooldown',
        );
      },
    );

    test(
      'Future-dated history (clock skew / user error) does not crash and is handled safely',
      () {
        final meal = _createMeal(
          id: 1,
          name: 'فول',
          proteinType: ProteinType.legume,
        );
        final futureDate = wednesday.add(
          const Duration(days: 5),
        ); // 5 days in the future

        final history = [
          _createHistory(
            id: 1,
            mealId: 1,
            mealName: 'فول',
            proteinType: ProteinType.legume,
            cookedAt: futureDate,
          ),
        ];

        final result = engine.compute<Meal>(
          meals: [meal],
          history: history,
          settings: _createSettings(meatlessCooldownDays: 0),
          today: wednesday,
        );

        // deltaDays is negative (-5). At levels 0..3, deltaDays <= effectiveCooldown blocks it.
        // At level 4 (only deltaDays == 0 is blocked), deltaDays != 0 is accepted.
        expect(result.recommendations, hasLength(1));
        expect(result.relaxationLevel, 4);
      },
    );

    test('Higher meatless cooldown than global cooldown is strictly respected', () {
      // User sets meatlessCooldownDays to 20, but global cooldownDays to 5
      final settings = _createSettings(
        cooldownDays: 5,
        meatlessCooldownDays: 20,
      );
      final legumeMeal = _createMeal(
        id: 1,
        name: 'بصارة',
        proteinType: ProteinType.legume,
      );

      // Cooked 10 days ago: 10 > 5 (global), but 10 <= 20 (meatless)
      final history = [
        _createHistory(
          id: 1,
          mealId: 1,
          mealName: 'بصارة',
          proteinType: ProteinType.legume,
          cookedAt: wednesday.subtract(const Duration(days: 10)),
        ),
      ];

      final result = engine.compute<Meal>(
        meals: [legumeMeal],
        history: history,
        settings: settings,
        today: wednesday,
      );

      // Legume MUST respect meatlessCooldownDays (20), so it is blocked at level 0
      expect(
        result.relaxationLevel,
        greaterThan(0),
        reason:
            'Legume must respect meatlessCooldownDays=20 and be blocked at level 0',
      );
    });
  });
}
