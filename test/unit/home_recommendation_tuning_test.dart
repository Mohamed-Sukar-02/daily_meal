import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/features/home/providers/recommendation_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _proteins = [
  ProteinType.chicken,
  ProteinType.beef,
  ProteinType.fish,
];

/// The two knobs the cases below care about, per meal.
class _Spec {
  _Spec(this.id, {ProteinType? protein})
      : protein = protein ?? _proteins[id % _proteins.length];

  final int id;
  final ProteinType protein;
}

class _Harness {
  _Harness._(this.db, this.container);

  final AppDatabase db;
  final ProviderContainer container;

  Future<void> settle() => Future.delayed(const Duration(milliseconds: 150));

  List<Meal> get shown =>
      container.read(todayRecommendationsProvider).requireValue.recommendations;

  List<int> get ids => shown.map((m) => m.id).toList();

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

Future<_Harness> _start(
  List<_Spec> meals, {
  int cooldownDays = 14,
  int chickenCooldownDays = 2,
  int beefCooldownDays = 2,
  int fishCooldownDays = 4,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.appSettingsDao.ensureSettings();
  await db.appSettingsDao.updateSettings(AppSettingsCompanion(
    cooldownDays: Value(cooldownDays),
    chickenCooldownDays: Value(chickenCooldownDays),
    beefCooldownDays: Value(beefCooldownDays),
    fishCooldownDays: Value(fishCooldownDays),
  ));
  await db.mealsDao.deleteAllMeals();
  for (final spec in meals) {
    await db.mealsDao.insertMeal(MealsCompanion(
      id: Value(spec.id),
      name: Value('Meal ${spec.id}'),
      proteinType: Value(spec.protein),
      carbsType: const Value(CarbsType.rice),
      category: const Value(MealCategory.egyptianTraditional),
      prepTime: const Value(30),
    ));
  }

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
  final harness = _Harness._(db, container);
  container.listen(todayRecommendationsProvider, (_, _) {});
  await harness.settle();
  return harness;
}

/// Eleven meals, ids 11..21 — comfortably above the three cards the day shows,
/// so the variety and cooldown rules have somewhere to go.
List<_Spec> _vault() => [
      for (var id = 11; id <= 21; id++) _Spec(id),
    ];

void main() {
  group('vault capacity vs cooldown', () {
    test('a vault smaller than the cooldown window is flagged', () async {
      final harness = await _start([
        _Spec(11),
        _Spec(12),
        _Spec(13),
        _Spec(14),
      ], cooldownDays: 14);
      addTearDown(harness.dispose);

      final capacity = harness.container.read(vaultCapacityProvider);
      expect(capacity, isNotNull);
      expect(capacity!.isTooSmall, isTrue);
      expect(capacity.mealCount, 4);
      expect(capacity.cooldownDays, 14);
      expect(capacity.shortfall, 10);
    });

    test('a vault that covers its window stays quiet', () async {
      final harness = await _start(_vault(), cooldownDays: 10);
      addTearDown(harness.dispose);

      expect(harness.container.read(vaultCapacityProvider)!.isTooSmall, isFalse);
    });

    test('a protein rule stricter than the global one drives the warning',
        () async {
      final harness = await _start(
        [_Spec(11, protein: ProteinType.chicken)],
        cooldownDays: 3,
        chickenCooldownDays: 21,
      );
      addTearDown(harness.dispose);

      final capacity = harness.container.read(vaultCapacityProvider);
      expect(capacity!.cooldownDays, 21,
          reason: 'the chicken window is the one that will re-serve this meal');
      expect(capacity.isTooSmall, isTrue);
    });
  });
}
