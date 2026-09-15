import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:daily_meal/features/history/providers/history_providers.dart';
import 'package:daily_meal/features/home/providers/recommendation_provider.dart';

/// Polls `todayRecommendationsProvider` until [predicate] holds (or 5s timeout).
Future<List<Meal>> waitForRecs(
  ProviderContainer container,
  bool Function(List<Meal>) predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  var recs =
      container.read(todayRecommendationsProvider).value?.recommendations ?? const <Meal>[];
  while (!predicate(recs) && DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(milliseconds: 20));
    recs = container.read(todayRecommendationsProvider).value?.recommendations ??
        const <Meal>[];
  }
  return recs;
}

void main() {
  group('Empirical Challenger: Scoped Undo & Reactivity Adversarial Suite', () {
    late AppDatabase inMemoryDb;
    late ProviderContainer container;

    Future<void> settle(int milliseconds) async {
      await Future.delayed(Duration(milliseconds: milliseconds));
      // Extra event-loop grace so drift stream propagation can't flake on
      // slow machines (stream -> StreamProvider -> derived providers).
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

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

      // Keep active listeners so stream providers don't auto-dispose
      container.listen(allMealsProvider, (_, _) {});
      container.listen(mealHistoryProvider, (_, _) {});
      container.listen(todayRecommendationsProvider, (_, _) {});
    });

    tearDown(() async {
      container.dispose();
      await inMemoryDb.close();
    });

    // =========================================================================
    // SUITE 1: EXACT SCOPED DELETION & REACTIVITY RESTORATION
    // =========================================================================
    group('Suite 1: Exact Scoped Deletion & Reactivity Restoration', () {
      test('1.1 Scoped undo of middle record deletes ONLY targeted entry (preserves earlier & later)', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final idA = await vaultController.addMeal(
          name: 'وجبة أ (فراخ)',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
        );
        final idB = await vaultController.addMeal(
          name: 'وجبة ب (لحمة)',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.pasta,
          category: MealCategory.ovenBaked,
          prepTimeMinutes: 40,
        );
        final idC = await vaultController.addMeal(
          name: 'وجبة ج (سمك)',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.rice,
          category: MealCategory.seafood,
          prepTimeMinutes: 25,
        );

        final mealA = (await inMemoryDb.mealsDao.getMealById(idA))!;
        final mealB = (await inMemoryDb.mealsDao.getMealById(idB))!;
        final mealC = (await inMemoryDb.mealsDao.getMealById(idC))!;

        await settle(50);

        // Sequential logging
        final histIdA = await recController.logCookedToday(mealA);
        await settle(20);
        final histIdB = await recController.logCookedToday(mealB);
        await settle(20);
        final histIdC = await recController.logCookedToday(mealC);

        await settle(60);

        var history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(3));
        expect(history.map((h) => h.id).toSet(), equals({histIdA, histIdB, histIdC}));

        // SCOPED UNDO of the MIDDLE entry (histIdB)
        await recController.undoLastCookingLog(histIdB);
        await settle(60);

        // Verify in DB directly: ONLY histIdB deleted
        final dbHistory = await inMemoryDb.mealHistoryDao.getAllHistory();
        expect(dbHistory.length, equals(2));
        final dbHistoryIds = dbHistory.map((h) => h.id).toSet();
        expect(dbHistoryIds.contains(histIdB), isFalse, reason: 'Targeted entry B must be deleted');
        expect(dbHistoryIds.contains(histIdA), isTrue, reason: 'Earlier entry A must remain intact');
        expect(dbHistoryIds.contains(histIdC), isTrue, reason: 'Later entry C must remain intact');

        // Verify in Riverpod stream provider
        history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(2));
        expect(history.map((h) => h.id).toSet(), equals({histIdA, histIdC}));
      });

      test('1.2 Scoped undo of oldest entry leaves newer entries intact', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'أكلة 1', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 30);
        final id2 = await vaultController.addMeal(name: 'أكلة 2', proteinType: ProteinType.beef, carbsType: CarbsType.bread, category: MealCategory.ovenBaked, prepTimeMinutes: 30);

        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

        final h1 = await recController.logCookedToday(m1);
        final h2 = await recController.logCookedToday(m2);

        await settle(60);

        // Undo oldest (h1)
        await recController.undoLastCookingLog(h1);
        await settle(60);

        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1));
        expect(history.first.id, equals(h2));
        expect(history.first.mealName, equals('أكلة 2'));
      });

      test('1.3 Scoped undo restores meal cooldown eligibility reactively', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        // Add 4 meals
        final ids = <int>[];
        for (int i = 1; i <= 4; i++) {
          final id = await vaultController.addMeal(
            name: 'وجبة كولداون $i',
            proteinType: ProteinType.values[i % ProteinType.values.length],
            carbsType: CarbsType.values[i % CarbsType.values.length],
            category: MealCategory.egyptianTraditional,
            prepTimeMinutes: 30,
          );
          ids.add(id);
        }

        // Wait for all 4 meals to be fully emitted by the stream
        await settle(60);

        // Pick a target meal that naturally ranks in the top 3 with an empty history
        var recs = await waitForRecs(container, (r) => r.isNotEmpty);
        final targetMeal = recs.first;
        expect(recs.any((m) => m.id == targetMeal.id), isTrue);

        // Cook target meal -> should be excluded by cooldown
        final logId = await recController.markCookedToday(targetMeal);

        recs = await waitForRecs(container, (r) => !r.any((m) => m.id == targetMeal.id));
        expect(recs.any((m) => m.id == targetMeal.id), isFalse, reason: 'Cooked meal must be excluded by cooldown');

        // Scoped undo of this log -> should immediately become eligible and recommended again
        await recController.undoLastCookingLog(logId);

        recs = await waitForRecs(container, (r) => r.any((m) => m.id == targetMeal.id));
        
        if (!recs.any((m) => m.id == targetMeal.id)) {
          print('DEBUG: waitForRecs timed out.');
          print('DEBUG: recs.length = ${recs.length}');
          for (var r in recs) print('DEBUG: rec - ${r.id}: ${r.name}');
          final historyState = container.read(mealHistoryProvider);
          print('DEBUG: historyState = $historyState');
          if (historyState.hasValue) {
            for (var h in historyState.value!) print('DEBUG: hist - ${h.id}: ${h.mealId}');
          }
          final dbHist = await inMemoryDb.mealHistoryDao.getAllHistory();
          print('DEBUG: dbHist.length = ${dbHist.length}');
        }

        expect(recs.any((m) => m.id == targetMeal.id), isTrue, reason: 'Undoing log must restore meal to recommendations');
      });
    });

    // =========================================================================
    // SUITE 2: DOUBLE-TAP & CONCURRENCY IDEMPOTENCY
    // =========================================================================
    group('Suite 2: Double-Tap & Concurrency Idempotency', () {
      test('2.1 Sequential double-tap on undo does not throw and preserves remaining records', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'وجبة 1', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final id2 = await vaultController.addMeal(name: 'وجبة 2', proteinType: ProteinType.beef, carbsType: CarbsType.bread, category: MealCategory.fastFood, prepTimeMinutes: 20);

        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

        final h1 = await recController.logCookedToday(m1);
        final h2 = await recController.logCookedToday(m2);

        await settle(60);

        // First tap
        await recController.undoLastCookingLog(h2);
        // Second tap on the exact same ID (simulating rapid double-tap on SnackBar)
        await recController.undoLastCookingLog(h2);

        await settle(60);

        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1), reason: 'Double-tap must not delete unrelated h1 record');
        expect(history.first.id, equals(h1));
        expect(container.read(recommendationControllerProvider).hasError, isFalse);
      });

      test('2.2 Concurrent double-tap on undo completes without race crash', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'وجبة سباق 1', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final id2 = await vaultController.addMeal(name: 'وجبة سباق 2', proteinType: ProteinType.fish, carbsType: CarbsType.rice, category: MealCategory.seafood, prepTimeMinutes: 20);

        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

        final h1 = await recController.logCookedToday(m1);
        final h2 = await recController.logCookedToday(m2);

        await settle(60);

        // Concurrent double tap
        await Future.wait([
          recController.undoLastCookingLog(h2),
          recController.undoLastCookingLog(h2),
        ]);

        await settle(60);

        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1));
        expect(history.first.id, equals(h1));
      });

      test('2.3 Calling undo with non-existent ID completes cleanly without side effects', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'وجبة حقيقية', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final h1 = await recController.logCookedToday(m1);

        await settle(60);

        // Calling with an ID that does not exist
        await recController.undoLastCookingLog(9999999);
        await settle(60);

        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1));
        expect(history.first.id, equals(h1));
      });
    });

    // =========================================================================
    // SUITE 3: BACKWARDS COMPATIBILITY FOR UNSCOPED UNDO & TIMESTAMP TIE ANALYSIS
    // =========================================================================
    group('Suite 3: Backwards Compatibility for Unscoped Undo', () {
      test('3.1a Unscoped undoLastCookingLog() with distinct timestamps deletes most recent entry', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'أكلة قديمة', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final id2 = await vaultController.addMeal(name: 'أكلة حديثة', proteinType: ProteinType.beef, carbsType: CarbsType.pasta, category: MealCategory.ovenBaked, prepTimeMinutes: 20);

        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

        // First log at time T1
        final h1 = await recController.logCookedToday(m1);
        await settle(30);

        // Refresh time provider so T2 > T1
        container.refresh(currentTimeProvider);
        final h2 = await recController.logCookedToday(m2);

        await settle(60);

        // Call unscoped undo
        await recController.undoLastCookingLog();
        await settle(60);

        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1));
        expect(history.first.id, equals(h1), reason: 'When timestamps differ, newest h2 is deleted and oldest h1 remains');
        expect(history.first.id, isNot(equals(h2)));
      });

      test('3.1b [FIXED] Unscoped undo deletes newest entry (h2) even when timestamps are identical via id DESC tie-breaker', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'وجبة 1 (أولى)', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final id2 = await vaultController.addMeal(name: 'وجبة 2 (ثانية)', proteinType: ProteinType.beef, carbsType: CarbsType.pasta, category: MealCategory.ovenBaked, prepTimeMinutes: 20);

        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

        // Log two meals with identical timestamps to challenge the tie-breaker
        final fixedTime = DateTime(2026, 9, 7, 12, 0, 0);
        final h1 = await recController.logCookedToday(m1, cookedAt: fixedTime);
        final h2 = await recController.logCookedToday(m2, cookedAt: fixedTime);

        await settle(60);

        // Verify both entries share the exact same cookedAt timestamp
        final allEntries = await inMemoryDb.mealHistoryDao.getAllHistory();
        expect(allEntries[0].cookedAt, equals(allEntries[1].cookedAt),
            reason: 'Both entries explicitly share the identical timestamp');

        // Unscoped undo must delete the LAST logged entry (h2) via id DESC tie-breaker
        await recController.undoLastCookingLog();
        await settle(60);

        final remainingHistory = await inMemoryDb.mealHistoryDao.getAllHistory();
        expect(remainingHistory.length, equals(1));
        expect(remainingHistory.first.id, equals(h1), reason: 'Oldest entry h1 must remain intact');

        final deletedId = remainingHistory.first.id == h1 ? h2 : h1;
        expect(deletedId, equals(h2),
            reason: 'Unscoped undo must delete newest entry h2 even when timestamps are identical');
      });

      test('3.1c Rapid sequential logs without explicit cookedAt obtain distinct dynamically progressive timestamps', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'وجبة أ', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final id2 = await vaultController.addMeal(name: 'وجبة ب', proteinType: ProteinType.beef, carbsType: CarbsType.pasta, category: MealCategory.ovenBaked, prepTimeMinutes: 20);

        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

        final h1 = await recController.logCookedToday(m1);
        await settle(15);
        final h2 = await recController.logCookedToday(m2);

        final allEntries = await inMemoryDb.mealHistoryDao.getAllHistory();
        final entry1 = allEntries.firstWhere((e) => e.id == h1);
        final entry2 = allEntries.firstWhere((e) => e.id == h2);

        expect(entry2.cookedAt.isAfter(entry1.cookedAt) || entry2.cookedAt.isAtSameMomentAs(entry1.cookedAt), isTrue);
        expect(entry2.id, greaterThan(entry1.id));
      });

      test('3.2 Unscoped undoLastCookingLog(null) explicitly passes null and acts as unscoped', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'أكلة اختبار نل', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        await recController.logCookedToday(m1);

        await settle(60);
        expect(container.read(mealHistoryProvider).value!.length, equals(1));

        await recController.undoLastCookingLog(null);
        await settle(60);

        expect(container.read(mealHistoryProvider).value!.isEmpty, isTrue);
      });

      test('3.3 Unscoped undo on empty history does not throw', () async {
        final recController = container.read(recommendationControllerProvider.notifier);
        expect(container.read(mealHistoryProvider).value?.isEmpty ?? true, isTrue);

        await recController.undoLastCookingLog();
        expect(container.read(recommendationControllerProvider).hasError, isFalse);
      });

      test('3.4 undoHistoryEntry alias method deletes exact targeted record', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final id1 = await vaultController.addMeal(name: 'أكلة 1', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
        final id2 = await vaultController.addMeal(name: 'أكلة 2', proteinType: ProteinType.beef, carbsType: CarbsType.rice, category: MealCategory.ovenBaked, prepTimeMinutes: 20);

        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

        final h1 = await recController.logCookedToday(m1);
        final h2 = await recController.logCookedToday(m2);

        await settle(60);

        await recController.undoHistoryEntry(h1);
        await settle(60);

        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1));
        expect(history.first.id, equals(h2));
      });
    });

    // =========================================================================
    // SUITE 4: RAPID 10-MEAL LOGGING & RANDOM SCOPED UNDO
    // =========================================================================
    group('Suite 4: Rapid 10-Meal Logging & Random Scoped Undo Stress', () {
      test('4.1 Rapid logging of 10 meals followed by random scoped undo removes ONLY selected entries', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final createdMeals = <Meal>[];
        for (int i = 0; i < 10; i++) {
          final id = await vaultController.addMeal(
            name: 'وجبة سريعة $i',
            proteinType: ProteinType.values[i % ProteinType.values.length],
            carbsType: CarbsType.values[i % CarbsType.values.length],
            category: MealCategory.values[i % MealCategory.values.length],
            prepTimeMinutes: 15 + i * 5,
          );
          final meal = (await inMemoryDb.mealsDao.getMealById(id))!;
          createdMeals.add(meal);
        }

        await settle(60);

        // Rapidly log all 10 meals
        final historyIds = <int>[];
        for (int i = 0; i < 10; i++) {
          final hId = await recController.markCookedToday(createdMeals[i]);
          historyIds.add(hId);
        }

        await settle(100);

        var historyList = container.read(mealHistoryProvider).value!;
        expect(historyList.length, equals(10), reason: 'All 10 meals must be recorded in history');

        // Select 4 pseudo-random indices to undo: [1, 4, 6, 8]
        final undoIndices = [1, 4, 6, 8];
        final undoIds = undoIndices.map((idx) => historyIds[idx]).toSet();
        final expectedRemainingIds = historyIds.where((id) => !undoIds.contains(id)).toSet();

        // Perform scoped undo on the selected 4 IDs
        for (final id in undoIds) {
          await recController.undoLastCookingLog(id);
        }

        await settle(100);

        // Verify remaining entries in DB
        final dbHistory = await inMemoryDb.mealHistoryDao.getAllHistory();
        expect(dbHistory.length, equals(6), reason: 'Exactly 6 entries must remain after undoing 4');

        final actualRemainingIds = dbHistory.map((h) => h.id).toSet();
        expect(actualRemainingIds, equals(expectedRemainingIds),
            reason: 'The remaining IDs in DB must match exactly the un-undone entries');

        for (final removedId in undoIds) {
          expect(actualRemainingIds.contains(removedId), isFalse,
              reason: 'Removed ID $removedId must not exist in history');
        }

        // Verify Riverpod stream state
        historyList = container.read(mealHistoryProvider).value!;
        expect(historyList.length, equals(6));
        final streamIds = historyList.map((h) => h.id).toSet();
        expect(streamIds, equals(expectedRemainingIds));

        // Verify that snapshot data on remaining entries was completely unaffected
        for (final record in historyList) {
          final originalIndex = historyIds.indexOf(record.id);
          expect(originalIndex, isNot(equals(-1)));
          final originalMeal = createdMeals[originalIndex];
          expect(record.mealName, equals(originalMeal.name));
          expect(record.proteinType, equals(originalMeal.proteinType));
          expect(record.carbsType, equals(originalMeal.carbsType));
        }
      });

      test('4.2 Concurrent random scoped undo operations execute cleanly', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final meals = <Meal>[];
        for (int i = 0; i < 8; i++) {
          final id = await vaultController.addMeal(
            name: 'سباق توازي $i',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.rice,
            category: MealCategory.egyptianTraditional,
            prepTimeMinutes: 20,
          );
          meals.add((await inMemoryDb.mealsDao.getMealById(id))!);
        }

        final hIds = <int>[];
        for (final m in meals) {
          hIds.add(await recController.markCookedToday(m));
        }

        await settle(80);

        // Concurrently undo 3 entries
        final toUndo = [hIds[0], hIds[3], hIds[7]];
        await Future.wait(toUndo.map((id) => recController.undoLastCookingLog(id)));

        await settle(100);

        final history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(5));
        for (final undone in toUndo) {
          expect(history.any((h) => h.id == undone), isFalse);
        }
      });
    });

    // =========================================================================
    // SUITE 5: LEFTOVER VS COOKED SCOPED UNDO INTEGRITY
    // =========================================================================
    group('Suite 5: Leftover vs Cooked Scoped Undo Integrity', () {
      test('5.1 Scoped undo of leftover entry deletes ONLY the leftover record', () async {
        final vaultController = container.read(vaultControllerProvider.notifier);
        final recController = container.read(recommendationControllerProvider.notifier);

        final idCooked = await vaultController.addMeal(name: 'طبيخ طازج', proteinType: ProteinType.beef, carbsType: CarbsType.rice, category: MealCategory.ovenBaked, prepTimeMinutes: 30);
        final idLeftover = await vaultController.addMeal(name: 'بواقي أكل', proteinType: ProteinType.chicken, carbsType: CarbsType.bread, category: MealCategory.fastFood, prepTimeMinutes: 10);

        final mCooked = (await inMemoryDb.mealsDao.getMealById(idCooked))!;
        final mLeftover = (await inMemoryDb.mealsDao.getMealById(idLeftover))!;

        final hCooked = await recController.markCookedToday(mCooked);
        await settle(20);
        final hLeftover = await recController.markLeftover(mLeftover);

        await settle(60);

        var history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(2));
        expect(history.map((h) => h.entryType).toSet(), equals({MealEntryType.cooked, MealEntryType.leftover}));

        // Undo ONLY leftover
        await recController.undoLastCookingLog(hLeftover);
        await settle(60);

        history = container.read(mealHistoryProvider).value!;
        expect(history.length, equals(1));
        expect(history.first.id, equals(hCooked));
        expect(history.first.entryType, equals(MealEntryType.cooked));
      });
    });
  });
}
