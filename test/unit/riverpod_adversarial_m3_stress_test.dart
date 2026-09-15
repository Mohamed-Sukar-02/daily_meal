// test/unit/riverpod_adversarial_m3_stress_test.dart
// Adversarial Empirical Stress Test Suite for Milestone 3 Riverpod State Reactivity
// Focus: Rapid Sequential & Concurrent Mutations, todayRecommendationsProvider Consistency,
// and spinWheelCandidatesProvider Small Vault Boundaries (0, 1, 2 candidates).

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:daily_meal/features/history/providers/history_providers.dart';
import 'package:daily_meal/features/settings/providers/settings_providers.dart';
import 'package:daily_meal/features/home/providers/recommendation_provider.dart';
// (cooldown_engine unused import removed)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase inMemoryDb;
  late ProviderContainer container;

  setUp(() async {
    inMemoryDb = AppDatabase(NativeDatabase.memory());
    await inMemoryDb.appSettingsDao.ensureSettings();
    await inMemoryDb.mealsDao.deleteAllMeals();
    await inMemoryDb.mealHistoryDao.clearAllHistory();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(inMemoryDb),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await inMemoryDb.close();
  });

  // Helper to pump microtasks and await Drift stream propagation to Riverpod
  Future<void> settleStreams([int milliseconds = 80]) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  // ============================================================================
  // SUITE 1: RAPID SEQUENTIAL MUTATIONS STRESS
  // ============================================================================
  group('Adversarial Suite 1: Rapid Sequential Mutations Stress', () {
    test('CHALLENGE-1.1: Rapid sequential addition of 50 meals maintains 100% stream consistency', () async {
      // Keep listeners active
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      final proteins = ProteinType.values;
      final carbs = CarbsType.values;
      final categories = MealCategory.values;

      // Rapidly fire 50 sequential additions
      for (int i = 1; i <= 50; i++) {
        await vaultController.addMeal(
          name: 'وجبة تجريبية رقم $i',
          proteinType: proteins[i % proteins.length],
          carbsType: carbs[i % carbs.length],
          category: categories[i % categories.length],
          prepTimeMinutes: 15 + (i % 60),
          isFridaySpecial: i % 7 == 0,
          isBudgetFriendly: i % 3 == 0,
          isFavorite: i % 5 == 0,
        );
      }

      await settleStreams(150);

      // Verify allMealsProvider matches exactly 50 meals
      final allMealsAsync = container.read(allMealsProvider);
      expect(allMealsAsync.hasValue, isTrue, reason: 'allMealsProvider must have value after 50 additions');
      final allMeals = allMealsAsync.value!;
      expect(allMeals.length, equals(50), reason: 'Database and stream must contain exactly 50 meals');

      // Verify todayRecommendationsProvider consistency
      final recsAsync = container.read(todayRecommendationsProvider);
      expect(recsAsync.hasValue, isTrue, reason: 'todayRecommendationsProvider must not fail or stay loading');
      expect(recsAsync.hasError, isFalse, reason: 'todayRecommendationsProvider must have no unhandled errors');

      final recs = recsAsync.value!.recommendations;
      expect(recs.length, equals(3), reason: 'Must recommend exactly 3 meals when vault has 50 items');

      // Check distinctness
      final ids = recs.map((m) => m.id).toSet();
      expect(ids.length, equals(3), reason: 'Recommendations must contain 3 unique meals');

      // Verify all recommended meals actually belong to the 50 meals
      for (final r in recs) {
        expect(allMeals.any((m) => m.id == r.id), isTrue,
            reason: 'Recommended meal ${r.id} must exist in active vault');
      }
    });

    test('CHALLENGE-1.2: Rapid sequential deletion of 30 meals preserves recommendation integrity', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      final addedIds = <int>[];
      for (int i = 1; i <= 40; i++) {
        final id = await vaultController.addMeal(
          name: 'وجبة للحذف $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 20,
        );
        addedIds.add(id);
      }

      await settleStreams(100);
      expect(container.read(allMealsProvider).value?.length, equals(40));

      // Rapidly delete first 30 meals
      final deletedIds = addedIds.take(30).toSet();
      for (final id in deletedIds) {
        await vaultController.deleteMeal(id);
      }

      await settleStreams(150);

      final remainingMeals = container.read(allMealsProvider).value!;
      expect(remainingMeals.length, equals(10), reason: 'Exactly 10 meals should remain after 30 deletions');

      final recs = container.read(todayRecommendationsProvider).value!.recommendations;
      expect(recs.length, equals(3), reason: 'Must still recommend 3 meals from remaining 10');

      // CRITICAL: Ensure NO deleted meal appears in recommendations
      for (final r in recs) {
        expect(deletedIds.contains(r.id), isFalse,
            reason: 'Deleted meal ${r.id} must never appear in active recommendations');
        expect(remainingMeals.any((m) => m.id == r.id), isTrue,
            reason: 'Recommended meal must belong to remaining meals');
      }
    });

    test('CHALLENGE-1.3: Rapid favorite toggles execute accurately and update score calculations', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(favoriteMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      final id = await vaultController.addMeal(
        name: 'وجبة المفضلات السريعة',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        category: MealCategory.egyptianTraditional,
        prepTimeMinutes: 30,
        isFavorite: false,
      );

      await settleStreams(50);
      expect(container.read(favoriteMealsProvider).value?.length, equals(0));

      // Rapidly toggle favorite 20 times on this single meal
      for (int i = 0; i < 20; i++) {
        await vaultController.toggleFavorite(id);
      }

      await settleStreams(100);

      // 20 toggles starting from false: 20 is even, so final state must be false
      var favorites = container.read(favoriteMealsProvider).value!;
      expect(favorites.any((m) => m.id == id), isFalse,
          reason: 'Even number of toggles (20) must leave favorite as false');

      // Toggle once more to true (21st toggle)
      await vaultController.toggleFavorite(id);
      await settleStreams(100);

      favorites = container.read(favoriteMealsProvider).value!;
      expect(favorites.any((m) => m.id == id), isTrue,
          reason: 'Odd number of toggles (21) must leave favorite as true');
    });

    test('CHALLENGE-1.4: Rapid sequential cooking logs and undo draining', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(mealHistoryProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
      final recController = container.read(recommendationControllerProvider.notifier);

      final meals = <Meal>[];
      for (int i = 1; i <= 6; i++) {
        final id = await vaultController.addMeal(
          name: 'وجبة الطهي $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 30,
        );
        final meal = await inMemoryDb.mealsDao.getMealById(id);
        meals.add(meal!);
      }

      await settleStreams(100);

      // Rapidly log 4 meals as cooked
      for (int i = 0; i < 4; i++) {
        await recController.logCookedToday(meals[i]);
      }

      await settleStreams(100);

      var history = container.read(mealHistoryProvider).value!;
      expect(history.length, equals(4), reason: 'History must contain 4 records');

      // Undo 2 logs
      await recController.undoLastCookingLog();
      await recController.undoLastCookingLog();

      await settleStreams(100);

      history = container.read(mealHistoryProvider).value!;
      expect(history.length, equals(2), reason: 'History must contain 2 records after 2 undos');

      // Drain history completely by calling undo 5 more times (more than existing records)
      for (int i = 0; i < 5; i++) {
        await recController.undoLastCookingLog();
      }

      await settleStreams(100);

      history = container.read(mealHistoryProvider).value!;
      expect(history.isEmpty, isTrue, reason: 'History must be empty without error after over-undoing');

      final recsAsync = container.read(todayRecommendationsProvider);
      expect(recsAsync.hasValue, isTrue);
      expect(recsAsync.value!.recommendations.length, equals(3));
    });
  });

  // ============================================================================
  // SUITE 2: CONCURRENT & INTERLEAVED MUTATIONS
  // ============================================================================
  group('Adversarial Suite 2: Concurrent & Interleaved Rapid Mutations', () {
    test('CHALLENGE-2.1: Concurrent additions via Future.wait settle cleanly without race crash', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      // Fire 20 additions concurrently
      final futures = List.generate(20, (i) {
        return vaultController.addMeal(
          name: 'وجبة متزامنة $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 20 + i,
        );
      });

      final ids = await Future.wait(futures);
      expect(ids.length, equals(20));
      expect(ids.toSet().length, equals(20), reason: 'Every meal must receive a unique primary key ID');

      await settleStreams(200);

      final allMeals = container.read(allMealsProvider).value!;
      expect(allMeals.length, equals(20), reason: 'Stream must reflect exactly 20 concurrently added meals');

      final recs = container.read(todayRecommendationsProvider).value!.recommendations;
      expect(recs.length, equals(3), reason: 'Must have 3 valid recommendations');
    });

    test('CHALLENGE-2.2: Interleaved concurrent mutations (Add, Delete, Cook, Favorite)', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(mealHistoryProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
      final recController = container.read(recommendationControllerProvider.notifier);

      // Pre-seed 15 meals
      final preSeededMeals = <Meal>[];
      for (int i = 1; i <= 15; i++) {
        final id = await vaultController.addMeal(
          name: 'وجبة مسبقة $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 25,
        );
        final meal = await inMemoryDb.mealsDao.getMealById(id);
        preSeededMeals.add(meal!);
      }

      await settleStreams(100);

      // Launch interleaved operations concurrently:
      // - 5 additions
      // - 3 deletions of existing meals
      // - 3 cooking logs of remaining meals
      // - 3 favorite toggles
      final concurrentOps = <Future>[
        // Additions
        vaultController.addMeal(name: 'إضافة جديدة 1', proteinType: ProteinType.beef, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20),
        vaultController.addMeal(name: 'إضافة جديدة 2', proteinType: ProteinType.chicken, carbsType: CarbsType.pasta, category: MealCategory.ovenBaked, prepTimeMinutes: 30),
        vaultController.addMeal(name: 'إضافة جديدة 3', proteinType: ProteinType.fish, carbsType: CarbsType.rice, category: MealCategory.seafood, prepTimeMinutes: 40),

        // Deletions
        vaultController.deleteMeal(preSeededMeals[0].id),
        vaultController.deleteMeal(preSeededMeals[1].id),
        vaultController.deleteMeal(preSeededMeals[2].id),

        // Cook logs
        recController.logCookedToday(preSeededMeals[3]),
        recController.logCookedToday(preSeededMeals[4]),
        recController.logLeftover(preSeededMeals[5]),

        // Favorite toggles
        vaultController.toggleFavorite(preSeededMeals[6].id),
        vaultController.toggleFavorite(preSeededMeals[7].id),
      ];

      // Must complete without throwing unhandled exceptions
      await Future.wait(concurrentOps);

      await settleStreams(250);

      final mealsAsync = container.read(allMealsProvider);
      expect(mealsAsync.hasError, isFalse, reason: 'allMealsProvider must have no errors after concurrent burst');
      // 15 initial + 3 added - 3 deleted = 15
      expect(mealsAsync.value!.length, equals(15));

      final historyAsync = container.read(mealHistoryProvider);
      expect(historyAsync.hasError, isFalse);
      expect(historyAsync.value!.length, equals(3));

      final recsAsync = container.read(todayRecommendationsProvider);
      expect(recsAsync.hasError, isFalse);
      expect(recsAsync.hasValue, isTrue);
      expect(recsAsync.value!.recommendations.length, equals(3));
    });

    test('CHALLENGE-2.3: Safe handling when meal is deleted and concurrently marked cooked', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(mealHistoryProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
      container.listen(recommendationControllerProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
      final recController = container.read(recommendationControllerProvider.notifier);

      final id = await vaultController.addMeal(
        name: 'وجبة تصادم الحذف والطهي',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.rice,
        category: MealCategory.egyptianTraditional,
        prepTimeMinutes: 30,
      );
      final meal = await inMemoryDb.mealsDao.getMealById(id);

      await settleStreams(50);

      // Simultaneously delete meal and mark cooked
      Object? cookError;
      final deleteFuture = vaultController.deleteMeal(id);
      final cookFuture = recController.logCookedToday(meal!).catchError((e) {
        cookError = e;
        return -1;
      });

      await Future.wait([deleteFuture, cookFuture]);

      await settleStreams(150);

      // Either:
      // A) logCookedToday ran first: meal was logged with mealId, then deleteMeal set mealId to NULL via foreign key cascade.
      // B) deleteMeal ran first: logCookedToday threw SqliteException (foreign key violation), which was caught and stored in controller state.
      if (cookError != null) {
        expect(container.read(recommendationControllerProvider).hasError, isTrue,
            reason: 'RecommendationController must capture error when foreign key constraint fails');
      } else {
        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1));
        // mealId must have cascaded to null
        expect(history.first.mealId, isNull);
      }

      // CRITICAL: todayRecommendationsProvider must remain valid and crash-free regardless of race winner
      final recsAsync = container.read(todayRecommendationsProvider);
      expect(recsAsync.hasError, isFalse, reason: 'todayRecommendationsProvider must never crash due to racing mutations');
      expect(recsAsync.hasValue, isTrue);
      expect(recsAsync.value!.recommendations.any((m) => m.id == id), isFalse);
    });
  });

  // ============================================================================
  // SUITE 3: SPIN THE WHEEL & SMALL VAULT RIGOR (0, 1, 2 CANDIDATES)
  // ============================================================================
  group('Adversarial Suite 3: Small Vaults & spinWheelCandidatesProvider Rigor', () {
    test('CHALLENGE-3.1: Zero meals vault (0 candidates) disables wheel completely', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
      container.listen(spinWheelCandidatesProvider, (_, _) {});

      await settleStreams(50);

      // 1. allMeals is empty
      final allMeals = container.read(allMealsProvider).value!;
      expect(allMeals.isEmpty, isTrue);

      // 2. todayRecommendations is level 5 empty state
      final recsResult = container.read(todayRecommendationsProvider).value!;
      expect(recsResult.recommendations.isEmpty, isTrue);
      expect(recsResult.relaxationLevel, equals(5));
      expect(recsResult.relaxationReason, contains('قاعدة بيانات الوجبات فارغة'));

      // 3. spinWheelCandidatesProvider must return empty list
      final wheelCandidates = container.read(spinWheelCandidatesProvider);
      expect(wheelCandidates, isEmpty, reason: 'Spin wheel must have 0 candidates on empty vault');

      // 4. HomeController.spinTheWheel must return null without throwing
      final homeController = container.read(homeControllerProvider);
      expect(homeController.spinTheWheel(), isNull, reason: 'spinTheWheel must return null on empty vault');
    });

    test('CHALLENGE-3.2: Single meal vault (1 candidate) disables wheel strictly', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
      container.listen(spinWheelCandidatesProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      final id = await vaultController.addMeal(
        name: 'وجبة يتيمة وحيدة',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 15,
      );

      await settleStreams(80);

      // 1. Vault has 1 meal
      final allMeals = container.read(allMealsProvider).value!;
      expect(allMeals.length, equals(1));

      // 2. todayRecommendations has exactly 1 meal
      final recsResult = container.read(todayRecommendationsProvider).value!;
      expect(recsResult.recommendations.length, equals(1));
      expect(recsResult.recommendations.first.id, equals(id));

      // 3. spinWheelCandidatesProvider MUST BE EMPTY because candidates < 2
      final wheelCandidates = container.read(spinWheelCandidatesProvider);
      expect(wheelCandidates, isEmpty,
          reason: 'Spin wheel MUST return empty list when vault has only 1 candidate (requires >= 2)');

      // 4. HomeController.spinTheWheel must return null
      final homeController = container.read(homeControllerProvider);
      expect(homeController.spinTheWheel(), isNull,
          reason: 'spinTheWheel must return null when only 1 candidate exists');

      // 5. Mark that single meal cooked today -> check Level 5 degradation
      final recController = container.read(recommendationControllerProvider.notifier);
      final singleMeal = allMeals.first;
      await recController.logCookedToday(singleMeal);

      await settleStreams(100);

      final cookedRecsResult = container.read(todayRecommendationsProvider).value!;
      expect(cookedRecsResult.recommendations.length, equals(1),
          reason: 'Emergency Level 5 fallback must still provide the 1 meal');
      expect(cookedRecsResult.relaxationLevel, equals(5));

      // Wheel must STILL be disabled
      expect(container.read(spinWheelCandidatesProvider), isEmpty);
      expect(homeController.spinTheWheel(), isNull);
    });

    test('CHALLENGE-3.3: Two-meal vault (2 candidates) enables wheel and transitions dynamically', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(mealHistoryProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
      container.listen(spinWheelCandidatesProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
// (recController unused variable removed)
      final homeController = container.read(homeControllerProvider);

      final id1 = await vaultController.addMeal(
        name: 'كفتة مشوية',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 20,
      );
      final id2 = await vaultController.addMeal(
        name: 'فراخ بانيه',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.pasta,
        category: MealCategory.fastFood,
        prepTimeMinutes: 25,
      );

      await settleStreams(100);

      // Exactly 2 candidates: wheel is now enabled!
      var wheelCandidates = container.read(spinWheelCandidatesProvider);
      expect(wheelCandidates.length, equals(2), reason: 'Spin wheel must enable with exactly 2 candidates');

      // Spin wheel multiple times: should return non-null and select from the 2
      final spinResults = <int>{};
      for (int i = 0; i < 30; i++) {
        final winner = homeController.spinTheWheel();
        expect(winner, isNotNull);
        expect(winner!.id == id1 || winner.id == id2, isTrue);
        spinResults.add(winner.id);
      }
      expect(spinResults.contains(id1), isTrue, reason: 'Meal 1 must be picked at least once over 30 spins');
      expect(spinResults.contains(id2), isTrue, reason: 'Meal 2 must be picked at least once over 30 spins');

      // Now delete 1 meal: should transition back to disabled!
      await vaultController.deleteMeal(id1);
      await settleStreams(100);

      wheelCandidates = container.read(spinWheelCandidatesProvider);
      expect(wheelCandidates, isEmpty, reason: 'Deleting 1 of 2 meals must immediately disable the wheel');
      expect(homeController.spinTheWheel(), isNull);

      // Re-add a 2nd meal: should re-enable immediately!
      await vaultController.addMeal(
        name: 'طاجن بامية',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.rice,
        category: MealCategory.ovenBaked,
        prepTimeMinutes: 40,
      );
      await settleStreams(100);

      wheelCandidates = container.read(spinWheelCandidatesProvider);
      expect(wheelCandidates.length, equals(2), reason: 'Re-adding a 2nd meal must immediately re-enable the wheel');
      expect(homeController.spinTheWheel(), isNotNull);
    });

    test('CHALLENGE-3.4: Dynamic cascade transitions 4 -> 3 -> 2 -> 1 -> 0 meals', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
      container.listen(spinWheelCandidatesProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
      final homeController = container.read(homeControllerProvider);

      final ids = <int>[];
      for (int i = 1; i <= 4; i++) {
        final id = await vaultController.addMeal(
          name: 'وجبة متدرجة $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 20,
        );
        ids.add(id);
      }

      await settleStreams(100);

      // State 4 meals: recs=3, wheel=3
      expect(container.read(todayRecommendationsProvider).value!.recommendations.length, equals(3));
      expect(container.read(spinWheelCandidatesProvider).length, equals(3));
      expect(homeController.spinTheWheel(), isNotNull);

      // Delete 1 -> 3 meals: recs=3, wheel=3
      await vaultController.deleteMeal(ids[0]);
      await settleStreams(100);
      expect(container.read(todayRecommendationsProvider).value!.recommendations.length, equals(3));
      expect(container.read(spinWheelCandidatesProvider).length, equals(3));
      expect(homeController.spinTheWheel(), isNotNull);

      // Delete 1 -> 2 meals: recs=2, wheel=2
      await vaultController.deleteMeal(ids[1]);
      await settleStreams(100);
      expect(container.read(todayRecommendationsProvider).value!.recommendations.length, equals(2));
      expect(container.read(spinWheelCandidatesProvider).length, equals(2));
      expect(homeController.spinTheWheel(), isNotNull);

      // Delete 1 -> 1 meal: recs=1, wheel=0 (disabled)
      await vaultController.deleteMeal(ids[2]);
      await settleStreams(100);
      expect(container.read(todayRecommendationsProvider).value!.recommendations.length, equals(1));
      expect(container.read(spinWheelCandidatesProvider), isEmpty);
      expect(homeController.spinTheWheel(), isNull);

      // Delete 1 -> 0 meals: recs=0, wheel=0 (disabled)
      await vaultController.deleteMeal(ids[3]);
      await settleStreams(100);
      expect(container.read(todayRecommendationsProvider).value!.recommendations, isEmpty);
      expect(container.read(spinWheelCandidatesProvider), isEmpty);
      expect(homeController.spinTheWheel(), isNull);
    });
  });

  // ============================================================================
  // SUITE 4: INVARIANTS & FILTER REACTIVITY UNDER CONCURRENT MUTATION
  // ============================================================================
  group('Adversarial Suite 4: Invariant Consistency & Filter Concurrency', () {
    test('CHALLENGE-4.1: Mathematical invariants hold across 30 state mutations', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      for (int i = 1; i <= 30; i++) {
        await vaultController.addMeal(
          name: 'وجبة متغيرة $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 20 + i,
        );

        // Spot-check every 5 additions
        if (i % 5 == 0) {
          await settleStreams(40);
          final recsAsync = container.read(todayRecommendationsProvider);
          expect(recsAsync.hasError, isFalse);
          final recs = recsAsync.value!.recommendations;

          // Invariant 1: Cardinality <= min(3, vault.length)
          expect(recs.length, equals(3));

          // Invariant 2: Set uniqueness (no duplicates)
          final uniqueIds = recs.map((m) => m.id).toSet();
          expect(uniqueIds.length, equals(recs.length));
        }
      }
    });

    test('CHALLENGE-4.2: Emergency Level 5 when ALL meals in vault are cooked today', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(mealHistoryProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
      final recController = container.read(recommendationControllerProvider.notifier);

      final addedMeals = <Meal>[];
      for (int i = 1; i <= 5; i++) {
        final id = await vaultController.addMeal(
          name: 'وجبة مطبوخة بالكامل $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 25,
        );
        final meal = await inMemoryDb.mealsDao.getMealById(id);
        addedMeals.add(meal!);
      }

      await settleStreams(80);

      // Cook ALL 5 meals today
      for (final meal in addedMeals) {
        await recController.logCookedToday(meal);
      }

      await settleStreams(120);

      final recResult = container.read(todayRecommendationsProvider).value!;
      // Under strict mode, all 5 meals are on cooldown.
      // Relaxation cascade should gracefully reach Level 5 and still return 3 meals
      expect(recResult.relaxationLevel, equals(5),
          reason: 'When all meals were cooked today, relaxation level must reach 5');
      expect(recResult.recommendations.length, equals(3),
          reason: 'Emergency mode must provide 3 meals even if cooked today');
      expect(recResult.relaxationReason, contains('تم عرض جميع الوجبات المتاحة'));
    });

    test('CHALLENGE-4.3: VaultFilterNotifier reacts immediately without ConcurrentModificationError during active insertions', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(filteredMealsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
      final filterNotifier = container.read(vaultFilterProvider.notifier);

      // Seed 10 meals
      for (int i = 1; i <= 10; i++) {
        await vaultController.addMeal(
          name: i.isEven ? 'كفتة مشوية $i' : 'سمك مقلي $i',
          proteinType: i.isEven ? ProteinType.beef : ProteinType.fish,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
          isFavorite: i % 3 == 0,
        );
      }

      await settleStreams(100);

      // Filter by protein: beef
      filterNotifier.toggleProtein(ProteinType.beef);
      var filtered = container.read(filteredMealsProvider).value!;
      expect(filtered.length, equals(5));
      expect(filtered.every((m) => m.proteinType == ProteinType.beef), isTrue);

      // While filter is active, add another beef meal
      await vaultController.addMeal(
        name: 'كفتة مشوية جديدة 11',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 20,
      );

      await settleStreams(100);

      filtered = container.read(filteredMealsProvider).value!;
      expect(filtered.length, equals(6), reason: 'Newly added beef meal must automatically appear in filtered view');

      // Search query filter
      filterNotifier.setSearchQuery('جديدة');
      filtered = container.read(filteredMealsProvider).value!;
      expect(filtered.length, equals(1));
      expect(filtered.first.name, equals('كفتة مشوية جديدة 11'));

      // Reset
      filterNotifier.resetFilters();
      filtered = container.read(filteredMealsProvider).value!;
      expect(filtered.length, equals(11));
    });

    test('CHALLENGE-4.4: Safe error propagation when database stream throws', () async {
      // Create a container with an error-throwing stream override to test resilience
      final errorContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
          allMealsProvider.overrideWith((ref) {
            return Stream.error(Exception('Simulated SQLite disk corruption'));
          }),
        ],
      );

      // Keep listener active to pump stream events
      errorContainer.listen(todayRecommendationsProvider, (_, _) {});

      // Await stream error emission
      await Future.delayed(const Duration(milliseconds: 50));

      final recsAsync = errorContainer.read(todayRecommendationsProvider);
      expect(recsAsync.hasError, isTrue, reason: 'todayRecommendationsProvider must propagate upstream stream errors cleanly');
      expect(recsAsync.error.toString(), contains('Simulated SQLite disk corruption'));

      errorContainer.dispose();
    });
  });

  // ============================================================================
  // SUITE 5: HIGH CONCURRENCY READ/WRITE STRESS & SETTINGS REACTIVITY
  // ============================================================================
  group('Adversarial Suite 5: High Concurrency Read/Write Stress & Settings Reactivity', () {
    test('CHALLENGE-5.1: Settings mutation (cooldown & dietary rules) dynamically alters recommendations and triggers cascade', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(mealHistoryProvider, (_, _) {});
      container.listen(appSettingsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);
      final settingsController = container.read(settingsControllerProvider.notifier);

      // Add exactly 3 meals: beef, chicken, fish
      final id1 = await vaultController.addMeal(name: 'لحمة باردة', proteinType: ProteinType.beef, carbsType: CarbsType.potato, category: MealCategory.ovenBaked, prepTimeMinutes: 40);
      await vaultController.addMeal(name: 'فراخ محمرة', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 30);
      await vaultController.addMeal(name: 'جمبري مشوي', proteinType: ProteinType.fish, carbsType: CarbsType.bread, category: MealCategory.seafood, prepTimeMinutes: 20);

      final meal1 = (await inMemoryDb.mealsDao.getMealById(id1))!;

      // Log meal1 cooked 20 days ago
      final twentyDaysAgo = DateTime.now().subtract(const Duration(days: 20));
      await inMemoryDb.mealHistoryDao.logCookedMeal(meal1, cookedAt: twentyDaysAgo);

      await settleStreams(100);

      // 1. Default cooldown is 14 days. Since 20 > 14, meal1 is eligible at Level 0
      var recResult = container.read(todayRecommendationsProvider).value!;
      expect(recResult.relaxationLevel, equals(0),
          reason: 'Under 14 days cooldown, all 3 meals are eligible at Level 0');
      expect(recResult.recommendations.length, equals(3));
      expect(recResult.recommendations.any((m) => m.id == id1), isTrue);

      // 2. Mutate cooldown days to 30 days
      // Level 0: 20 <= 30 (excluded -> 2 candidates)
      // Level 1: relax carbs (still 2 candidates)
      // Level 2: halve cooldown (30 / 2 = 15). Since 20 > 15, meal1 is eligible at Level 2!
      await settingsController.updateCooldownDays(30);
      await settleStreams(100);

      final settings = container.read(appSettingsProvider).value!;
      expect(settings.cooldownDays, equals(30));

      recResult = container.read(todayRecommendationsProvider).value!;
      expect(recResult.relaxationLevel, equals(2),
          reason: 'Increasing cooldown to 30 days must trigger Level 2 cascade (halve cooldown) to satisfy 3 candidates');
      expect(recResult.recommendations.length, equals(3));
      expect(recResult.relaxationReason, contains('تقليص فترة الاستبعاد إلى النصف'));

      // 3. Reset settings to default (14 days)
      await settingsController.resetToDefaults();
      await settleStreams(100);

      recResult = container.read(todayRecommendationsProvider).value!;
      expect(recResult.relaxationLevel, equals(0),
          reason: 'Resetting settings must restore recommendations to Level 0');
    });

    test('CHALLENGE-5.2: recommendationMealsProvider remains in 100% lockstep with todayRecommendationsProvider', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
      container.listen(recommendationMealsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      for (int i = 1; i <= 15; i++) {
        await vaultController.addMeal(
          name: 'وجبة تزامن $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 20 + i,
        );
      }

      await settleStreams(100);

      final todayRecs = container.read(todayRecommendationsProvider).value!.recommendations;
      final mealsProviderRecs = container.read(recommendationMealsProvider).value!;

      expect(mealsProviderRecs.length, equals(todayRecs.length));
      for (int i = 0; i < todayRecs.length; i++) {
        expect(mealsProviderRecs[i].id, equals(todayRecs[i].id),
            reason: 'recommendationMealsProvider must match todayRecommendationsProvider exactly at index $i');
      }
    });

    test('CHALLENGE-5.3: Reader/Writer Storm: 50 concurrent mutations while reading 4 providers in parallel', () async {
      container.listen(allMealsProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
      container.listen(recommendationMealsProvider, (_, _) {});
      container.listen(spinWheelCandidatesProvider, (_, _) {});
      container.listen(filteredMealsProvider, (_, _) {});

      final vaultController = container.read(vaultControllerProvider.notifier);

      // Pre-seed 10 meals
      for (int i = 1; i <= 10; i++) {
        await vaultController.addMeal(
          name: 'وجبة العاصفة $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTimeMinutes: 25,
        );
      }

      await settleStreams(50);

      int readCount = 0;

      // Concurrent reader polling providers in parallel with mutations
      Future<void> runReader() async {
        for (int i = 0; i < 20; i++) {
          final recs = container.read(todayRecommendationsProvider);
          final meals = container.read(allMealsProvider);
          final wheel = container.read(spinWheelCandidatesProvider);
          final filtered = container.read(filteredMealsProvider);

          // Assertions on the fly: no unhandled errors during reading
          expect(recs.hasError, isFalse);
          expect(meals.hasError, isFalse);
          expect(filtered.hasError, isFalse);
          expect(wheel.length <= 3, isTrue);

          readCount++;
          await Future.delayed(const Duration(milliseconds: 5));
        }
      }

      // Writer executing 30 additions and 10 deletions
      Future<void> runWriter() async {
        final addedIds = <int>[];
        for (int i = 11; i <= 40; i++) {
          final id = await vaultController.addMeal(
            name: 'وجبة العاصفة $i',
            proteinType: ProteinType.values[i % ProteinType.values.length],
            carbsType: CarbsType.values[i % CarbsType.values.length],
            category: MealCategory.values[i % MealCategory.values.length],
            prepTimeMinutes: 25,
          );
          addedIds.add(id);
        }

        for (int i = 0; i < 10; i++) {
          await vaultController.deleteMeal(addedIds[i]);
        }
      }

      await Future.wait([runReader(), runWriter()]);

      await settleStreams(150);

      // Verify that after the storm, all providers settled to a valid state
      final finalMeals = container.read(allMealsProvider).value!;
      // 10 initial + 30 added - 10 deleted = 30
      expect(finalMeals.length, equals(30));

      final finalRecs = container.read(todayRecommendationsProvider).value!;
      expect(finalRecs.recommendations.length, equals(3));

      final finalWheel = container.read(spinWheelCandidatesProvider);
      expect(finalWheel.length, equals(3));

      expect(readCount, equals(20), reason: 'Reader must execute all 20 passes during concurrent storm');
    });
  });
}
