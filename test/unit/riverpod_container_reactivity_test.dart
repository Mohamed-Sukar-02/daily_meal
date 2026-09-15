import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:daily_meal/features/history/providers/history_providers.dart';
import 'package:daily_meal/features/home/providers/recommendation_provider.dart';

/// Polls `recommendationProvider` until [predicate] holds (or 5s timeout).
/// Replaces fixed sleeps so slow drift stream propagation can't flake.
Future<List<Meal>> waitForRecs(
  ProviderContainer container,
  bool Function(List<Meal>) predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  var recs =
      container.read(recommendationProvider).value?.recommendations ?? const <Meal>[];
  while (!predicate(recs) && DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(milliseconds: 20));
    recs =
        container.read(recommendationProvider).value?.recommendations ?? const <Meal>[];
  }
  return recs;
}

Future<List<Meal>> waitForFiltered(
  ProviderContainer container,
  bool Function(List<Meal>) predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  var filtered = container.read(filteredMealsProvider).value ?? const <Meal>[];
  while (!predicate(filtered) && DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(milliseconds: 20));
    filtered = container.read(filteredMealsProvider).value ?? const <Meal>[];
  }
  return filtered;
}

void main() {
  group('Riverpod Provider Reactivity Verification', () {
    late AppDatabase inMemoryDb;
    late ProviderContainer container;

    setUp(() async {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      // Seed default settings and clear pre-seeded starter meals for clean isolated unit tests
      await inMemoryDb.appSettingsDao.ensureSettings();
      await inMemoryDb.mealsDao.deleteAllMeals();
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

    test('1. allMealsProvider emits when VaultController.addMeal is called', () async {
      final initialMeals = await container.read(allMealsProvider.future);
      expect(initialMeals.isEmpty, isTrue);

      final completer = Completer<List<Meal>>();
      final sub = container.listen<AsyncValue<List<Meal>>>(
        allMealsProvider,
        (_, next) {
          next.whenData((meals) {
            if (meals.isNotEmpty && !completer.isCompleted) {
              completer.complete(meals);
            }
          });
        },
      );

      // Add meal via controller
      await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'طاجن مكرونة باللحمة',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.pasta,
        category: MealCategory.ovenBaked,
        prepTimeMinutes: 45,
      );

      final updatedMeals = await completer.future;
      expect(updatedMeals.length, equals(1));
      expect(updatedMeals.first.name, equals('طاجن مكرونة باللحمة'));
      sub.close();
    });

    test('2. recommendationProvider automatically updates when meal is marked cooked', () async {
      // Consume initial empty snapshots
      await container.read(allMealsProvider.future);
      await container.read(mealHistoryProvider.future);

      // Keep reading container so providers stay active
      container.listen(recommendationProvider, (_, _) {});

      // Insert 4 meals
      final mealId = await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'شاورما دجاج',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 30,
      );
      await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'كفتة مشوية',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 25,
      );
      await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'سمك بلطي',
        proteinType: ProteinType.fish,
        carbsType: CarbsType.rice,
        category: MealCategory.seafood,
        prepTimeMinutes: 35,
      );
      await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'كشري مصري',
        proteinType: ProteinType.legume,
        carbsType: CarbsType.rice,
        category: MealCategory.egyptianTraditional,
        prepTimeMinutes: 45,
      );

      final meal = await inMemoryDb.mealsDao.getMealById(mealId);

      // Await next stream event (poll until the meal shows up)
      var recs = await waitForRecs(container, (r) => r.any((m) => m.id == meal!.id));
      expect(recs.any((m) => m.id == meal!.id), isTrue);

      final historyCompleter = Completer<List<MealHistoryData>>();
      final historySub = container.listen<AsyncValue<List<MealHistoryData>>>(
        mealHistoryProvider,
        (_, next) {
          next.whenData((history) {
            if (history.isNotEmpty && !historyCompleter.isCompleted) {
              historyCompleter.complete(history);
            }
          });
        },
      );

      // Mark meal cooked
      await container.read(historyControllerProvider.notifier).logCookedMeal(meal!);
      await historyCompleter.future;
      historySub.close();

      recs = await waitForRecs(container, (r) => !r.any((m) => m.id == meal.id));
      expect(recs.any((m) => m.id == meal.id), isFalse);
    });

    test('3. filteredMealsProvider reacts immediately to filter queries', () async {
      await container.read(allMealsProvider.future);

      container.listen(filteredMealsProvider, (_, _) {});

      await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'كفتة مشوية',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 25,
      );
      await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'سمك بلطي مقلي',
        proteinType: ProteinType.fish,
        carbsType: CarbsType.rice,
        category: MealCategory.seafood,
        prepTimeMinutes: 35,
      );

      var filtered = await waitForFiltered(container, (f) => f.length == 2);
      expect(filtered.length, equals(2));

      // Filter by protein: fish
      container.read(vaultFilterProvider.notifier).toggleProtein(ProteinType.fish);
      filtered = container.read(filteredMealsProvider).value ?? [];
      expect(filtered.length, equals(1));
      expect(filtered.first.name, equals('سمك بلطي مقلي'));

      // Reset
      container.read(vaultFilterProvider.notifier).resetFilters();
      filtered = container.read(filteredMealsProvider).value ?? [];
      expect(filtered.length, equals(2));
    });
  });
}
