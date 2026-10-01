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

  Future<Meal?> reroll(int index) async {
    final replaced =
        await container.read(todayRecommendationsProvider.notifier).rerollSingle(index);
    await settle();
    return replaced;
  }

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

/// Eleven meals, ids 11..21 — comfortably above the three cards, so a reroll
/// always has somewhere to go unless a case says otherwise.
List<_Spec> _vault() => [
      for (var id = 11; id <= 21; id++) _Spec(id),
    ];

void main() {
  group('single card reroll', () {
    test('replaces one slot and leaves the other two alone', () async {
      final harness = await _start(_vault());
      addTearDown(harness.dispose);

      final before = harness.ids;
      final replacement = await harness.reroll(1);

      expect(replacement, isNotNull);
      final after = harness.ids;
      expect(after, hasLength(3));
      expect(after[0], before[0], reason: 'the first card stays put');
      expect(after[2], before[2], reason: 'the third card stays put');
      expect(after[1], replacement!.id);
      expect(after.toSet(), hasLength(3),
          reason: 'the new card never duplicates one of the staying cards');
    });

    test('says so when the vault has nothing else to offer', () async {
      // Exactly the three cards on screen: every candidate is already shown,
      // so a "new" meal could only be a re-serve.
      final harness = await _start([_Spec(11), _Spec(12), _Spec(13)]);
      addTearDown(harness.dispose);

      expect(harness.ids, hasLength(3));
      expect(await harness.reroll(0), isNull);
      expect(harness.ids, hasLength(3));
    });

    test('a reroll hands back a different meal, not the one it replaced', () async {
      // The three visible ids are all excluded from the draw, so the tapped
      // card cannot be its own replacement — the assertion the "no duplicates
      // between slots" check above cannot make on its own.
      final harness = await _start(_vault());
      addTearDown(harness.dispose);

      final before = harness.ids;
      final replacement = await harness.reroll(1);

      expect(replacement, isNotNull);
      expect(replacement!.id, isNot(before[1]));
      expect(before, isNot(contains(replacement.id)));
    });

    test('an out-of-range slot is refused, not clamped', () async {
      final harness = await _start(_vault());
      addTearDown(harness.dispose);

      final before = harness.ids;

      expect(await harness.reroll(3), isNull);
      expect(await harness.reroll(-1), isNull);
      expect(harness.ids, before, reason: 'a bad index must not disturb the day');
    });

    test('repeated taps keep dealing new meals instead of one answer',
        () async {
      final harness = await _start(_vault());
      addTearDown(harness.dispose);

      final seen = <int>{};
      for (var i = 0; i < 4; i++) {
        final replacement = await harness.reroll(0);
        if (replacement != null) seen.add(replacement.id);
      }

      expect(seen.length, greaterThan(1),
          reason: 'each tap has to move on, not re-serve the same replacement');
    });

    test('a rerolled card survives an unrelated write', () async {
      final harness = await _start(_vault());
      addTearDown(harness.dispose);

      final replacement = await harness.reroll(0);
      expect(replacement, isNotNull);
      final afterReroll = harness.ids;

      // The heart button is the write the eligibility key is blind to: the
      // cards must be replayed in the rerolled order, not re-ranked back.
      await harness.db.mealsDao.toggleFavorite(afterReroll.last, false);
      await harness.settle();

      expect(harness.ids, afterReroll);
    });

    test('does not duplicate a staying card\'s protein', () async {
      // Two meals per protein: the day always shows one of each, so exactly
      // one alternative of the third card's own protein is left in the vault.
      final harness = await _start([
        _Spec(11, protein: ProteinType.chicken),
        _Spec(12, protein: ProteinType.beef),
        _Spec(13, protein: ProteinType.fish),
        _Spec(14, protein: ProteinType.chicken),
        _Spec(15, protein: ProteinType.beef),
        _Spec(16, protein: ProteinType.fish),
      ]);
      addTearDown(harness.dispose);

      final before = harness.shown;
      expect(before.map((m) => m.proteinType).toSet(), hasLength(3),
          reason: 'the day itself starts one-protein-per-card');

      final replacement = await harness.reroll(2);

      expect(replacement, isNotNull);
      expect(harness.shown.map((m) => m.proteinType).toSet(), hasLength(3),
          reason: 'a single reroll must not quietly make two cards the same '
              'protein while an alternative existed');
      expect(replacement!.id, isNot(before[2].id));
    });
  });

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
