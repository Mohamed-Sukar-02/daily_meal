import 'dart:async';

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/utils/app_date_utils.dart' as app_date_utils;
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
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

Meal makeMeal(int id, {bool isFavorite = false}) => Meal(
      id: id,
      name: 'Meal $id',
      photoPath: null,
      proteinType: _proteins[id % _proteins.length],
      carbsType: CarbsType.rice,
      category: MealCategory.egyptianTraditional,
      isStarterMeal: false,
      prepTime: 30,
      isFridaySpecial: false,
      isBudgetFriendly: false,
      isFavorite: isFavorite,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      cloudId: null,
      nameNormalized: null,
    );

AppSettingsData makeSettings() => AppSettingsData(
      id: 1,
      cooldownDays: 14,
      chickenCooldownDays: 7,
      beefCooldownDays: 10,
      fishCooldownDays: 5,
      meatlessCooldownDays: 0,
      notificationHour: 12,
      notificationMinute: 0,
      notificationsEnabled: false,
      themeMode: AppThemeModePreference.system,
      language: AppLanguagePreference.ar,
      isFirstRun: false,
      recommendationSource: RecommendationSource.vault_only,
      autoFridayFeastFilter: false,
    );

// ---------------------------------------------------------------------------
// Provider harness for the eligibility-key cases.
//
// `AppDatabase.onCreate` seeds the shipped default vault, so every case wipes
// the table and writes a hand-sized vault with explicit ids: the assertions are
// about *which* ids the provider serves, and "the id list did not change" only
// means something when nothing else could have moved it.
// ---------------------------------------------------------------------------

const _engine = CooldownEngine();
const _chicken = ProteinType.chicken;
const _beef = ProteinType.beef;
const _fish = ProteinType.fish;

class _MealSpec {
  const _MealSpec(this.id, this.protein, {this.favorite = false});

  final int id;
  final ProteinType protein;
  final bool favorite;
}

/// [count] meals cycling through the three cooked proteins, so a three-card
/// draw always has one of each available.
List<_MealSpec> _cycle(int count, {int firstId = 11}) => [
      for (var i = 0; i < count; i++)
        _MealSpec(firstId + i, [ProteinType.chicken, ProteinType.beef, ProteinType.fish][i % 3]),
    ];

/// A local *noon* timestamp `days` calendar days before [reference]: both sides
/// of the engine's `toLocalDay` comparison land on the intended day even across
/// a DST transition, and the hour is free for same-day edits.
DateTime _daysAgo(DateTime reference, int days, {int hour = 12}) =>
    DateTime(reference.year, reference.month, reference.day - days, hour);

class _Harness {
  _Harness._(this.db, this.container, this.subscription, this.today, this._clock);

  final AppDatabase db;
  final ProviderContainer container;
  final ProviderSubscription<AsyncValue<RecommendationResult<Meal>>> subscription;
  final StreamController<DateTime>? _clock;

  /// The day the provider is currently ranking for — the same value is fed to
  /// [_expectedIds] so both sides of an assertion agree on "today".
  DateTime today;

  RecommendationResult<Meal> get result => subscription.read().requireValue;
  List<int> get ids => result.recommendations.map((m) => m.id).toList();

  /// The drift streams + the day ticker are async; the existing cases in this
  /// file use the same 100 ms breathing room.
  Future<void> settle() => Future.delayed(const Duration(milliseconds: 150));

  /// Fires once, exactly like `currentTimeProvider` does when the calendar day
  /// rolls over under the app.
  Future<void> rollClockTo(DateTime day) async {
    _clock!.add(day);
    today = day;
    await settle();
  }

  Future<void> pullToRefresh() async {
    container.read(refreshSeedProvider.notifier).state++;
    await settle();
  }

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    await _clock?.close();
    await db.close();
  }
}

Future<_Harness> _startProvider({
  required List<_MealSpec> meals,
  List<({int mealId, int daysAgo})> cooked = const [],
  int globalCooldown = 14,
  int chickenCooldown = 2,
  int beefCooldown = 2,
  int fishCooldown = 4,
  int meatlessCooldown = 0,
  DateTime? fixedToday,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.appSettingsDao.ensureSettings();
  await db.appSettingsDao.updateSettings(AppSettingsCompanion(
    cooldownDays: Value(globalCooldown),
    chickenCooldownDays: Value(chickenCooldown),
    beefCooldownDays: Value(beefCooldown),
    fishCooldownDays: Value(fishCooldown),
    meatlessCooldownDays: Value(meatlessCooldown),
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
      isFavorite: Value(spec.favorite),
    ));
  }

  final today = fixedToday ?? DateTime.now();
  for (final entry in cooked) {
    final meal = await db.mealsDao.getMealById(entry.mealId);
    await db.mealHistoryDao.logCookedMeal(
      meal!,
      cookedAt: _daysAgo(today, entry.daysAgo),
    );
  }

  StreamController<DateTime>? clock;
  final overrides = <Override>[appDatabaseProvider.overrideWithValue(db)];
  if (fixedToday != null) {
    clock = StreamController<DateTime>();
    final stream = clock.stream;
    overrides.add(currentTimeProvider.overrideWith((ref) => stream));
  }

  final container = ProviderContainer(overrides: overrides);
  final subscription = container
      .listen<AsyncValue<RecommendationResult<Meal>>>(todayRecommendationsProvider, (_, _) {});
  // Pushed only after the provider subscribed, so the first frame is already
  // the fake day rather than the real clock.
  clock?.add(fixedToday!);

  final harness = _Harness._(db, container, subscription, today, clock);
  await harness.settle();
  return harness;
}

/// What [CooldownEngine] answers for the rows currently in the database. The
/// pin is only correct while the provider keeps agreeing with this.
Future<List<int>> _expectedIds(
  _Harness harness, {
  int seed = 0,
  Set<int>? excludeIds,
}) async {
  final result = _engine.compute<Meal>(
    meals: await harness.db.mealsDao.getAllMeals(),
    history: await harness.db.mealHistoryDao.getAllHistory(),
    settings: await harness.db.appSettingsDao.getSettings(),
    today: harness.today,
    shuffleSeed: seed,
    excludeIds: excludeIds,
  );
  return result.recommendations.map((m) => m.id).toList();
}

/// Replaces one history row's `cookedAt` in place: the row count is untouched,
/// which is exactly what the old length-only contribution could not see.
Future<void> _moveHistoryRowTo(AppDatabase db, int historyId, DateTime cookedAt) => db.managers.mealHistory
    .filter((row) => row.id.equals(historyId))
    .update((row) => row(cookedAt: Value(cookedAt)));

void main() {
  // Wednesday: the Friday-special bonus must not sway any expectation below.
  final wednesday = DateTime(2025, 3, 12, 12);
  const engine = CooldownEngine();

  List<int> pick({int seed = 0, List<Meal>? meals}) => engine
      .compute<Meal>(
        meals: meals ?? List.generate(9, makeMeal),
        history: const [],
        settings: makeSettings(),
        today: wednesday,
        shuffleSeed: seed,
      )
      .recommendations
      .map((m) => m.id)
      .toList();

  group('CooldownEngine shuffleSeed', () {
    test('a new seed changes which meals are suggested', () {
      final selections = <String>{
        for (var seed = 0; seed < 6; seed++) pick(seed: seed).join(','),
      };
      expect(
        selections.length,
        greaterThan(1),
        reason: 'pull-to-refresh must be able to surface different meals',
      );
    });

    test('the same seed always replays the same selection', () {
      expect(pick(seed: 4), pick(seed: 4));
    });

    test('a favourite outranks plain meals regardless of the seed', () {
      final meals = [
        for (var id = 1; id <= 9; id++) makeMeal(id, isFavorite: id == 5),
      ];
      for (var seed = 0; seed < 6; seed++) {
        expect(pick(seed: seed, meals: meals).first, 5);
      }
    });
  });

  test('favouriting a meal keeps today\'s recommendations in place', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.appSettingsDao.ensureSettings();
    for (var id = 1; id <= 9; id++) {
      await db.mealsDao.insertMeal(MealsCompanion(
        name: Value('Meal $id'),
        proteinType: Value(_proteins[id % _proteins.length]),
        carbsType: const Value(CarbsType.rice),
        category: const Value(MealCategory.egyptianTraditional),
        prepTime: const Value(30),
      ));
    }

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    final subscription =
        container.listen(todayRecommendationsProvider, (_, __) {});
    await Future.delayed(const Duration(milliseconds: 100));

    final before =
        subscription.read().requireValue.recommendations.map((m) => m.id).toList();
    expect(before.length, 3);

    // The *last* card, not the first: favouriting the top card happens to leave
    // the order intact even when the list is re-ranked, so it proves nothing.
    final bumped = before.last;

    await db.mealsDao.toggleFavorite(bumped, false);
    await Future.delayed(const Duration(milliseconds: 100));

    final after =
        subscription.read().requireValue.recommendations.map((m) => m.id).toList();
    expect(after, before, reason: 'the heart button must not re-rank the cards');
    expect(
      subscription
          .read()
          .requireValue
          .recommendations
          .firstWhere((m) => m.id == bumped)
          .isFavorite,
      isTrue,
      reason: 'but the card itself still reflects the new favourite state',
    );

    subscription.close();
    container.dispose();
    await db.close();
  });

  // -------------------------------------------------------------------------
  // The eligibility key is the gate that decides whether today's pinned cards
  // survive a write. These cases cover every trigger ISSUES.md claims, plus the
  // two blind spots the claim used to paper over: a history write that keeps
  // the row count, and a meal edit that keeps the id list.
  // -------------------------------------------------------------------------
  group('eligibility key: the five re-rank triggers', () {
    test('the calendar day rolling over recomputes today', () async {
      final wednesday = DateTime(2025, 3, 12, 12);
      final thursday = DateTime(2025, 3, 13, 12);
      final harness = await _startProvider(meals: _cycle(4), fixedToday: wednesday);

      expect(harness.result.computedDate, app_date_utils.toLocalDay(wednesday));
      expect(harness.ids, await _expectedIds(harness));

      await harness.rollClockTo(thursday);

      // A replayed pin carries yesterday's computedDate, so a fresh one is the
      // proof that the day was re-ranked instead of the pin held open.
      expect(
        harness.result.computedDate,
        app_date_utils.toLocalDay(thursday),
        reason: 'midnight must re-rank: every cooldown window moved by a day',
      );
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });

    test('pull-to-refresh replaces all three cards', () async {
      final harness = await _startProvider(meals: _cycle(9));
      final before = harness.ids;

      await harness.pullToRefresh();

      final after = harness.ids;
      expect(after, hasLength(3));
      expect(
        after.toSet().intersection(before.toSet()),
        isEmpty,
        reason: 'the refresh dialog promises to change the three current suggestions',
      );
      expect(harness.result.repeatedIds, isEmpty);
      expect(after, await _expectedIds(harness, seed: 1, excludeIds: before.toSet()));

      await harness.dispose();
    });

    test('adding a meal re-ranks the day', () async {
      final harness = await _startProvider(meals: _cycle(4));
      expect(harness.ids, hasLength(3));

      await harness.db.mealsDao.insertMeal(const MealsCompanion(
        id: Value(15),
        name: Value('Meal 15'),
        proteinType: Value(_chicken),
        carbsType: Value(CarbsType.rice),
        category: Value(MealCategory.egyptianTraditional),
        prepTime: Value(30),
        isFavorite: Value(true),
      ));
      await harness.settle();

      expect(
        harness.ids.first,
        15,
        reason: 'a brand new favourite scores 30, a band above every never-cooked meal',
      );
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });

    test('deleting a meal drops it from the cards', () async {
      final harness = await _startProvider(meals: _cycle(9));
      final dropped = harness.ids.last;

      await harness.db.mealsDao.deleteMeal(dropped);
      await harness.settle();

      expect(harness.ids, hasLength(3));
      expect(harness.ids, isNot(contains(dropped)));
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });

    test('a cooldown setting change re-ranks the day', () async {
      final harness = await _startProvider(
        meals: const [
          _MealSpec(11, _chicken, favorite: true),
          _MealSpec(12, _beef),
          _MealSpec(13, _fish),
          _MealSpec(14, _beef),
        ],
        cooked: const [(mealId: 11, daysAgo: 3)],
        chickenCooldown: 2,
      );

      // 3 days old against a 2-day window: eligible, but only the variety rule
      // (it is the one chicken) keeps it on screen, in the last slot.
      expect(harness.ids.contains(11), isTrue);

      await harness.db.appSettingsDao.updateChickenCooldownDays(10);
      await harness.settle();

      expect(
        harness.ids,
        isNot(contains(11)),
        reason: 'widening the chicken window past its last cooked day makes it ineligible',
      );
      expect(harness.result.relaxationLevel, 0, reason: 'the pool never needed relaxing');
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });
  });

  group('eligibility key: history signature', () {
    test('moving a history row to another day re-ranks without changing the count',
        () async {
      final harness = await _startProvider(
        meals: const [
          _MealSpec(11, _chicken, favorite: true),
          _MealSpec(12, _beef),
          _MealSpec(13, _fish),
          _MealSpec(14, _beef),
        ],
        cooked: const [(mealId: 11, daysAgo: 3)],
        chickenCooldown: 2,
      );
      final row = (await harness.db.mealHistoryDao.getAllHistory()).single;
      expect(harness.ids.contains(11), isTrue);

      await _moveHistoryRowTo(harness.db, row.id, _daysAgo(harness.today, 1));
      await harness.settle();

      expect(
        await harness.db.mealHistoryDao.getAllHistory(),
        hasLength(1),
        reason: 'the row count is untouched, which is what a length-only '
            'contribution keyed off of — the pin would have stayed',
      );
      expect(harness.ids, isNot(contains(11)));
      expect(harness.result.relaxationLevel, 0);
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });

    test('a delete+insert landing in one frame re-ranks', () async {
      final harness = await _startProvider(
        meals: const [
          _MealSpec(11, _chicken),
          _MealSpec(12, _beef),
          _MealSpec(13, _fish),
          _MealSpec(14, _chicken),
        ],
        cooked: const [(mealId: 14, daysAgo: 3)],
        chickenCooldown: 2,
      );
      final row = (await harness.db.mealHistoryDao.getAllHistory()).single;
      expect(harness.ids.toSet(), {11, 12, 13});

      // One transaction, so drift flushes a single stream event: the vault ends
      // up with exactly one history row again, only for a different meal.
      await harness.db.transaction(() async {
        await harness.db.mealHistoryDao.deleteHistoryEntry(row.id);
        await harness.db.mealHistoryDao.logCookedMeal(
          (await harness.db.mealsDao.getMealById(11))!,
          cookedAt: _daysAgo(harness.today, 3),
        );
      });
      await harness.settle();

      expect(
        await harness.db.mealHistoryDao.getAllHistory(),
        hasLength(1),
        reason: 'same length, different meal — the old key saw nothing',
      );
      expect(harness.ids.toSet(), {12, 13, 14});
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });

    test('a clock-time edit inside the same calendar day keeps the cards', () async {
      final harness = await _startProvider(
        meals: const [
          _MealSpec(11, _chicken, favorite: true),
          _MealSpec(12, _beef),
          _MealSpec(13, _fish),
          _MealSpec(14, _beef),
        ],
        cooked: const [(mealId: 11, daysAgo: 3)],
        chickenCooldown: 2,
      );
      final before = harness.ids;
      final row = (await harness.db.mealHistoryDao.getAllHistory()).single;

      // Morning -> evening of the same day. The engine normalises cookedAt with
      // toLocalDay, so this genuinely cannot change eligibility and must not be
      // allowed to move cards either.
      await _moveHistoryRowTo(
        harness.db,
        row.id,
        DateTime(row.cookedAt.year, row.cookedAt.month, row.cookedAt.day, 20),
      );
      await harness.settle();

      expect(harness.ids, before, reason: 'day granularity, deliberately');

      await harness.dispose();
    });
  });

  group('eligibility key: meal eligibility signature', () {
    test('changing a meal\'s protein re-ranks the day', () async {
      final harness = await _startProvider(
        meals: const [
          _MealSpec(11, _chicken, favorite: true),
          _MealSpec(12, _beef),
          _MealSpec(13, _fish),
          _MealSpec(14, _beef),
        ],
        cooked: const [(mealId: 11, daysAgo: 3)],
        chickenCooldown: 2,
        beefCooldown: 14,
      );
      expect(harness.ids.contains(11), isTrue);

      await harness.db.mealsDao.updateMealCompanion(
        11,
        const MealsCompanion(proteinType: Value(_beef)),
      );
      await harness.settle();

      expect(
        harness.ids,
        isNot(contains(11)),
        reason: 'the cooldown bucket is resolved from the meal\'s current '
            'protein, so re-tagging chicken as beef puts a 3-day-old dish '
            'inside a 14-day window and it has to lose its slot',
      );
      expect(harness.result.relaxationLevel, 0);
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });

    test('flagging a Friday feast on a Friday moves it to the front', () async {
      final friday = DateTime(2025, 3, 14, 12);
      final harness = await _startProvider(
        meals: const [
          _MealSpec(11, _chicken),
          _MealSpec(12, _beef),
          _MealSpec(13, _fish),
          _MealSpec(14, _beef),
        ],
        cooked: const [(mealId: 11, daysAgo: 42)],
        chickenCooldown: 2,
        fixedToday: friday,
      );

      // Overdue but capped at 20 recency points -> a band below the never-cooked
      // meals, so variety can only ever hand it the third slot.
      expect(harness.ids.last, 11);

      await harness.db.mealsDao.updateMealCompanion(
        11,
        const MealsCompanion(isFridaySpecial: Value(true)),
      );
      await harness.settle();

      expect(
        harness.ids.first,
        11,
        reason: '+15 on a Friday lifts it three bands up; a key blind to the '
            'flag would keep serving it as the afterthought',
      );
      expect(harness.ids, await _expectedIds(harness));

      await harness.dispose();
    });

    test('renaming a meal, its photo or its budget flag never moves a card', () async {
      final harness = await _startProvider(meals: _cycle(4));
      final before = harness.ids;
      final bumped = before.first;

      await harness.db.mealsDao.updateMealCompanion(
        bumped,
        const MealsCompanion(
          name: Value('مكرونة بشاميل باللحمة المفرومة'),
          photoPath: Value('/tmp/renamed.jpg'),
          isBudgetFriendly: Value(true),
        ),
      );
      await harness.settle();

      expect(
        harness.ids,
        before,
        reason: 'the heart button and the edit sheet must not reshuffle the day',
      );
      final shown = harness.result.recommendations.firstWhere((m) => m.id == bumped);
      expect(shown.name, 'مكرونة بشاميل باللحمة المفرومة');
      expect(shown.photoPath, '/tmp/renamed.jpg');
      expect(shown.isBudgetFriendly, isTrue);

      await harness.dispose();
    });
  });
}
