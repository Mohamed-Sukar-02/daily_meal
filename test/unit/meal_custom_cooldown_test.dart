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
  /// touch. The general window stays at 14 here because no `ProteinType` reaches
  /// it — see the unknown-protein case for the one that does.
  RecommendationResult<Meal> run(
    List<Meal> meals,
    Map<int, int> cookedDaysAgo, {
    int chickenCooldownDays = 2,
    int beefCooldownDays = 2,
    int fishCooldownDays = 4,
    int meatlessCooldownDays = 0,
  }) {
    return const CooldownEngine().compute<Meal>(
      meals: meals,
      history: [
        for (final entry in cookedDaysAgo.entries)
          _Log(mealId: entry.key, cookedAt: today.subtract(Duration(days: entry.value))),
      ],
      settings: _windows(
        14,
        chickenCooldownDays,
        beefCooldownDays,
        fishCooldownDays,
        meatlessCooldownDays,
      ),
      today: today,
    );
  }

  group('the meal\'s own window wins', () {
    test('a long override pulls a meal out of the day', () {
      // Four chicken dishes, every one cooked five days back: the two-day
      // chicken window clears all four, so the pool is the full four and the day
      // needs no relaxation. One of the three cards then gets a thirty-day
      // window of its own — the only thing that changes between the two runs.
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
      // the two controls disagree for every dish in that group.
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

    test('it beats the beef and fish windows, not only the two named above', () {
      // Four windows, four chances to be read first. Beef and fish are the two
      // that no other case here touches, and they are the windows a household
      // writes an exception against most often — the roast the kids ask for out
      // of schedule, the fish that is fine twice a week.
      final blocked = run(
        [
          meal(1, protein: ProteinType.beef),
          meal(2, protein: ProteinType.fish),
          meal(3),
        ],
        {for (var id = 1; id <= 3; id++) id: 4},
        chickenCooldownDays: 1,
        beefCooldownDays: 6,
        fishCooldownDays: 6,
      );
      expect(blocked.relaxationLevel, greaterThan(0),
          reason: 'four days back sits inside both six-day windows, so the day '
              'has to relax to reach three meals');

      final rescued = run(
        [
          meal(1, protein: ProteinType.beef, customCooldownDays: 0),
          meal(2, protein: ProteinType.fish, customCooldownDays: 3),
          meal(3),
        ],
        {for (var id = 1; id <= 3; id++) id: 4},
        chickenCooldownDays: 1,
        beefCooldownDays: 6,
        fishCooldownDays: 6,
      );
      expect(rescued.relaxationLevel, 0,
          reason: 'one meal freed by 0 and one by a shorter window: the pool is '
              'complete without bending any rule');
      expect(rescued.recommendations.map((m) => m.id), containsAll([1, 2]));
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

  group('meals and settings that are not the real rows', () {
    test('a partial row still computes', () {
      // The engine adapts whatever it is handed, and fakes or projections have
      // never been required to declare every column. A missing override is
      // "follow the rules", never a NoSuchMethodError inside a build. `settings:
      // null` is the same lesson one layer up: every window falls back, and the
      // day is still dealt.
      final result = const CooldownEngine().compute<dynamic>(
        meals: [for (var id = 1; id <= 4; id++) _PartialMeal(id)],
        history: const [],
        settings: null,
        today: today,
      );
      expect(result.relaxationLevel, 0);
      expect(result.recommendations, hasLength(3));
    });

    test('an unknown protein falls to the general window, and loses to the override', () {
      // `ProteinType` has a case for every value, so the ONLY way to reach the
      // general window is a row the local vocabulary no longer knows — a tag an
      // older build or a foreign import left behind. "Read the override before
      // the general window" is the owner's wording for exactly this branch, and
      // without a case like this it would be an untested promise.
      final ages = const {1: 30, 2: 60, 3: 60, 4: 60};
      List<dynamic> vault(int? customOnMeal1) => [
            _LegacyMeal(1, customOnMeal1),
            _LegacyMeal(2, null),
            _LegacyMeal(3, null),
            _LegacyMeal(4, null),
          ];
      List<dynamic> history() => [
            for (final age in ages.entries)
              _Log(mealId: age.key, cookedAt: today.subtract(Duration(days: age.value))),
          ];

      // Meal 1 cooked thirty days back inside a forty-day general window; the
      // other three are sixty days old, so they clear it.
      final blocked = const CooldownEngine().compute<dynamic>(
        meals: vault(null),
        history: history(),
        settings: _windows(40, 2, 2, 4, 3),
        today: today,
      );
      expect(blocked.relaxationLevel, 0);
      expect(blocked.recommendations.map((m) => (m as dynamic).id), isNot(contains(1)),
          reason: 'thirty days back is inside a forty-day window');

      final rescued = const CooldownEngine().compute<dynamic>(
        meals: vault(0),
        history: history(),
        settings: _windows(40, 2, 2, 4, 3),
        today: today,
      );
      expect(rescued.relaxationLevel, 0);
      expect(rescued.recommendations.map((m) => (m as dynamic).id), contains(1),
          reason: 'the override is asked before the general window, so a 0 here '
              'is the whole answer for this dish');
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
          reason: 'thirty days is the rule now, and the day has to notice; the '
              'fingerprint excludes cosmetic fields, not this one');
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

/// A settings row carrying only the five windows the engine reads, in the order
/// it reads them: general, chicken, beef, fish, meatless. Positional on purpose
/// — every case states all five, so a window cannot arrive at a default nobody
/// meant. This is the real row type rather than a stand-in because `compute`
/// switches on it: `settings is AppSettingsData` is the branch production takes,
/// and a fake would have left that branch unexercised.
AppSettingsData _windows(int general, int chicken, int beef, int fish, int meatless) =>
    AppSettingsData(
      id: 1,
      cooldownDays: general,
      chickenCooldownDays: chicken,
      beefCooldownDays: beef,
      fishCooldownDays: fish,
      meatlessCooldownDays: meatless,
      notificationHour: 12,
      notificationMinute: 0,
      notificationsEnabled: false,
      themeMode: AppThemeModePreference.system,
      language: AppLanguagePreference.ar,
      isFirstRun: true,
      recommendationSource: RecommendationSource.vault_only,
      autoFridayFeastFilter: false,
    );

/// Real drift rows, because the fingerprint is computed from what the provider
/// actually watches — a fake would have to remember to look like a table.
class _Harness {
  _Harness._(this.db, this.container);

  final AppDatabase db;
  final ProviderContainer container;

  /// Five chicken dishes on a two-day chicken window and a fourteen-day general
  /// one — the settings row is written here rather than trusted, because the case
  /// below compares a meal's window against both of them.
  static Future<_Harness> start() async {
    const meals = 5;
    final db = AppDatabase(NativeDatabase.memory());
    await db.appSettingsDao.ensureSettings();
    await db.appSettingsDao.updateSettings(AppSettingsCompanion(
      cooldownDays: Value(14),
      chickenCooldownDays: Value(2),
    ));
    // `AppDatabase.onCreate` seeds the starter vault, and those rows carry
    // explicit ids — inserting "Meal 1" on top of seed row 1 is a UNIQUE
    // failure, not a test failure. The tuning harness clears first for the same
    // reason; a test that wants the seed can read it before this line.
    await db.mealsDao.deleteAllMeals();
    await db.mealHistoryDao.clearAllHistory();

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

/// A cooked row, in the shape the engine adapts history into: `_HistoryCandidate`
/// reads `mealId`, `cookedAt`, `createdAt` and the two tag axes off whatever it is
/// handed, so all five are here.
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

/// A row whose protein is a name the local enum has no case for: what the
/// engine's `default:` branch — the general window — is actually for.
class _LegacyMeal {
  _LegacyMeal(this.id, this.customCooldownDays);

  final int id;
  final int? customCooldownDays;
  String get name => 'Legacy $id';
  String get proteinType => 'venison';
  CarbsType get carbsType => CarbsType.rice;
  bool get isFridaySpecial => false;
  bool get isFavorite => false;
}
