import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import 'package:daily_meal/features/home/providers/recommendation_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Meals.customCooldownDays` used to have no reader at all, which made it a
/// placebo: a row could carry the value (cloud import wrote it, the meal sheet
/// described it) while the scheduler behaved as if the number did not exist.
///
/// These cases pin the two rules that make it a setting instead:
///  * the meal's own window is asked BEFORE the protein windows and before the
///    general one — an override that only applied when a protein had no window
///    of its own would silently do nothing for every meat dish, i.e. exactly the
///    meals people write exceptions for;
///  * `0` is an answer ("never held back"), not a missing value — the same
///    no-fall-through discipline `ProteinType.none` already follows.
///
/// And the half that lives outside the engine: the day's pinned cards are keyed
/// to a fingerprint of eligibility, so an override edit has to re-deal the day
/// instead of replaying a slot the meal no longer qualifies for.
void main() {
  final today = DateTime(2026, 3, 10);

  Meal meal(
    int id, {
    ProteinType protein = ProteinType.chicken,
    int? customCooldownDays,
  }) {
    return Meal(
      id: id,
      name: 'Meal $id',
      proteinType: protein,
      carbsType: const [
        CarbsType.rice,
        CarbsType.pasta,
        CarbsType.bread,
        CarbsType.potato,
      ][id % 4],
      category: MealCategory.egyptianTraditional,
      prepTime: 30,
      isFridaySpecial: false,
      isFavorite: false,
      isStarterMeal: false,
      createdAt: today,
      updatedAt: today,
      customCooldownDays: customCooldownDays,
    );
  }

  /// [cookedDaysAgo] maps a meal id to how many days back its newest row sits;
  /// a meal absent from it has never been cooked, the one state no window can
  /// touch.
  RecommendationResult<Meal> run(
    List<Meal> meals,
    Map<int, int> cookedDaysAgo, {
    int chickenCooldownDays = 2,
    int meatlessCooldownDays = 0,
  }) {
    return const CooldownEngine().compute<Meal>(
      meals: meals,
      history: [
        for (final entry in cookedDaysAgo.entries)
          _Log(mealId: entry.key, cookedAt: today.subtract(Duration(days: entry.value))),
      ],
      settings: _Settings(
        chickenCooldownDays: chickenCooldownDays,
        meatlessCooldownDays: meatlessCooldownDays,
      ),
      today: today,
    );
  }

  group('the meal\'s own window wins', () {
    test('a long override pulls a meal out of the day', () {
      // Four chicken dishes, every one cooked five days back: the two-day
      // chicken window clears all four, so the pool is the full four and the day
      // needs no relaxation. Meal 1 then gets a thirty-day window of its own —
      // the only thing that changes between the two runs.
      final plain = [for (var id = 1; id <= 4; id++) meal(id)];
      final cooked = {for (var id = 1; id <= 4; id++) id: 5};
      final baseline = run(plain, cooked);
      expect(baseline.relaxationLevel, 0,
          reason: 'nothing may be relaxed in either run, so any difference in '
              'the second one can only be the override doing its job');
      expect(baseline.recommendations, hasLength(3),
          reason: 'one of the four is left out by the draw, not by a rule');
      final target = baseline.recommendations.first.id;

      final after = run(
        [
          for (var id = 1; id <= 4; id++)
            meal(id, customCooldownDays: id == target ? 30 : null),
        ],
        cooked,
      );
      expect(after.recommendations.map((m) => m.id), isNot(contains(target)),
          reason: 'five days back is inside a thirty-day window');
      expect(after.relaxationLevel, 0,
          reason: 'three dishes are still eligible, so the rules must not bend '
              'to drag the excluded one back');
    });

    test('zero means "never held back", not "no opinion"', () {
      // Meal 1 cooked yesterday against a two-day chicken window: without an
      // override the day cannot be filled at all and the engine has to relax.
      // A 0 window is a promise the meal stays offered, and reading it as
      // "missing, fall back to fourteen" would break the promise.
      final relaxed = run(
        [for (var id = 1; id <= 3; id++) meal(id)],
        {for (var id = 1; id <= 3; id++) id: 1},
      );
      expect(relaxed.relaxationLevel, greaterThan(0));

      final honoured = run(
        [meal(1, customCooldownDays: 0), meal(2), meal(3)],
        {1: 1, 2: 9, 3: 9},
      );
      expect(honoured.relaxationLevel, 0);
      expect(honoured.recommendations.map((m) => m.id), contains(1));
    });

    test('it beats the meatless window too', () {
      // `legume`, `dairy` and `none` share one window, and that window is the
      // one Settings talks about most. An override that lost there would make
      // the two controls disagree for every veggie dish in the vault.
      final blocked = run(
        [
          meal(1, protein: ProteinType.none),
          meal(2, protein: ProteinType.legume),
          meal(3, protein: ProteinType.legume),
        ],
        {1: 3, 2: 3, 3: 3},
        meatlessCooldownDays: 14,
      );
      expect(blocked.relaxationLevel, greaterThan(0));

      final overridden = run(
        [
          meal(1, protein: ProteinType.none, customCooldownDays: 0),
          meal(2, protein: ProteinType.legume),
          meal(3, protein: ProteinType.legume),
        ],
        {1: 3, 2: 20, 3: 20},
        meatlessCooldownDays: 14,
      );
      expect(overridden.relaxationLevel, 0);
      expect(overridden.recommendations.map((m) => m.id), contains(1));
    });

    test('a stored negative cannot mean "unblockable"', () {
      // Only a same-day row tells 0 from -1: `0 <= 0` still holds the meal back,
      // while `-1` would wave it through at the first level and leave a meal no
      // rule can ever block again.
      final result = run(
        [meal(1, customCooldownDays: -1), meal(2), meal(3)],
        {1: 0, 2: 40, 3: 40},
      );
      expect(result.relaxationLevel, greaterThan(0),
          reason: 'negatives are clamped at the read, so the meal is blocked '
              'today like any other; it was never cooked -1 days ago');
    });

    test('the score counts overdue days against the same window', () {
      // `sRecency` resolves its window through the same call the eligibility
      // screen uses, so a longer override cools the score too. Without that, a
      // meal could rank as overdue while being filtered as not-overdue.
      const engine = CooldownEngine();
      double scoreFor(int? custom) => engine.calculateMealScore(
            meal: meal(1, customCooldownDays: custom),
            today: today,
            cooldownDays: 14,
            chickenCooldownDays: 2,
            lastCookedByMealId: {1: today.subtract(const Duration(days: 5))},
          );

      expect(scoreFor(30), lessThan(scoreFor(null)));
      expect(scoreFor(0), greaterThan(scoreFor(null)),
          reason: 'a meal with no window is the most overdue thing in the vault');
    });
  });

  group('meals that do not carry the column', () {
    test('a partial row still computes', () {
      // The engine adapts whatever it is handed, and fakes or projections have
      // never been required to declare every column. A missing override is
      // "follow the rules", never a NoSuchMethodError inside a build.
      final result = const CooldownEngine().compute<dynamic>(
        meals: [for (var id = 1; id <= 4; id++) _PartialMeal(id)],
        history: const [],
        settings: _Settings(),
        today: today,
      );
      expect(result.relaxationLevel, 0);
      expect(result.recommendations, hasLength(3));
    });
  });

  group('the day\'s fingerprint', () {
    test('an override edit re-deals the card the meal no longer deserves',
        () async {
      // The pinned-slot bug class, in one case: the meal token carried
      // id/protein/carbs/friday, so making a dish ineligible with its own
      // window left the key identical and the card stayed on screen forever —
      // a suggestion the user could neither reach nor get rid of.
      final harness = await _Harness.start();
      addTearDown(harness.dispose);

      final before = harness.ids;
      expect(before, hasLength(3));
      final target = before.first;

      await harness.setCooldown(target, 30);

      expect(harness.ids, isNot(contains(target)),
          reason: 'thirty days back is the rule now, and the day has to notice; '
              'the fingerprint excludes cosmetic fields, not this one');
      expect(harness.ids, hasLength(3),
          reason: 'four dishes are still eligible, so the slot is filled honestly '
              'rather than left empty');
    });

    test('an edit the engine never reads leaves the cards exactly as they were',
        () async {
      // The other half of the rule, so the key stays narrow: prep time is not an
      // eligibility input, the row still refreshes under the pinned slot, and
      // `updatedAt` moving must not reshuffle anything.
      final harness = await _Harness.start();
      addTearDown(harness.dispose);

      final before = harness.ids;
      final target = before.first;

      await harness.setPrepTime(target, 55);

      expect(harness.ids, equals(before),
          reason: 'the same three meals in the same three slots');
      expect(harness.shown.firstWhere((m) => m.id == target).prepTime, 55,
          reason: 'the replay rebuilds from the fresh rows, so the edit shows up '
              'in place instead of being hidden behind a stale object');
    });
  });
}

/// Real drift rows, because the fingerprint is computed from what the provider
/// actually watches — a fake would have to remember to look like a table.
class _Harness {
  _Harness._(this.db, this.container);

  final AppDatabase db;
  final ProviderContainer container;

  static Future<_Harness> start({int meals = 5, int chickenCooldownDays = 2}) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.appSettingsDao.ensureSettings();
    await db.appSettingsDao.updateSettings(AppSettingsCompanion(
      cooldownDays: const Value(14),
      chickenCooldownDays: Value(chickenCooldownDays),
    ));
    final now = DateTime.now();
    for (var id = 1; id <= meals; id++) {
      await db.mealsDao.insertMeal(MealsCompanion(
        id: Value(id),
        name: Value('Meal $id'),
        proteinType: const Value(ProteinType.chicken),
        carbsType: Value(const [
          CarbsType.rice,
          CarbsType.pasta,
          CarbsType.bread,
          CarbsType.potato,
        ][id % 4]),
        category: const Value(MealCategory.egyptianTraditional),
        prepTime: const Value(30),
      ));
      // Every dish sits five days back: all of them are eligible under the
      // two-day chicken window, so the only thing a case can change is a meal's
      // own window.
      await db.mealHistoryDao.logMeal(
        mealId: id,
        mealName: 'Meal $id',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        cookedAt: now.subtract(const Duration(days: 5)),
      );
    }

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    container.listen(todayRecommendationsProvider, (_, _) {});
    final harness = _Harness._(db, container);
    await harness.settle();
    return harness;
  }

  Future<void> settle() => Future.delayed(const Duration(milliseconds: 200));

  List<Meal> get shown =>
      container.read(todayRecommendationsProvider).requireValue.recommendations;

  List<int> get ids => shown.map((m) => m.id).toList();

  Future<void> setCooldown(int mealId, int? days) async {
    await db.mealsDao.updateMealCompanion(
      mealId,
      MealsCompanion(customCooldownDays: Value(days)),
    );
    await settle();
  }

  Future<void> setPrepTime(int mealId, int minutes) async {
    await db.mealsDao.updateMealCompanion(
      mealId,
      MealsCompanion(prepTime: Value(minutes)),
    );
    await settle();
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

/// Settings as the engine reads them for anything that is not the real row.
class _Settings {
  const _Settings({
    this.cooldownDays = 14,
    this.chickenCooldownDays = 2,
    this.beefCooldownDays = 2,
    this.fishCooldownDays = 4,
    this.meatlessCooldownDays = 0,
  });

  final int cooldownDays;
  final int chickenCooldownDays;
  final int beefCooldownDays;
  final int fishCooldownDays;
  final int meatlessCooldownDays;
}

class _Log {
  const _Log({required this.mealId, required this.cookedAt});

  final int mealId;
  final DateTime cookedAt;
  DateTime get createdAt => cookedAt;
  ProteinType get proteinType => ProteinType.chicken;
  CarbsType get carbsType => CarbsType.rice;
}

/// A meal row with only what the engine needed before the override existed — the
/// shape that must keep working.
class _PartialMeal {
  _PartialMeal(this.id);

  final int id;
  String get name => 'Partial $id';
  ProteinType get proteinType => ProteinType.chicken;
  CarbsType get carbsType => CarbsType.rice;
  bool get isFridaySpecial => false;
  bool get isFavorite => false;
}
