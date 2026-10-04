import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// The day's three cards must be a function of the day, not of what the user has
/// already done to it.
///
/// `_rankCandidates` used to break ties with `Random(seed).nextDouble()` drawn
/// once per candidate in ascending id order. `Random` is a stream, so a meal's
/// number depended on *how many smaller ids were in the pool at that moment* —
/// and the pool is exactly what a pick changes: cooking card #1 filters it out
/// at level 0, every later meal slips one draw forward, and the two cards the
/// user never touched are re-dealt under their hands. The same shift happened on
/// an add, a delete, or a relaxation level admitting more meals.
///
/// The lottery is now a hash of `(id, day, seed)`. These cases pin that: an
/// untouched meal keeps its rank when the pool churns around it.
Meal _meal(int id) => Meal(
  id: id,
  name: 'وجبة $id',
  photoPath: null,
  proteinType: ProteinType.chicken,
  carbsType: CarbsType.rice,
  category: MealCategory.egyptianTraditional,
  isStarterMeal: false,
  prepTime: 30,
  isFridaySpecial: false,
  isFavorite: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  cloudId: null,
  nameNormalized: null,
);

/// A history row for [mealId] cooked on [day] — enough to push it out of the
/// candidate pool at relaxation level 0 without touching anybody else's score.
MealHistoryData _cooked(int historyId, int mealId, DateTime day) =>
    MealHistoryData(
      id: historyId,
      mealId: mealId,
      mealName: 'وجبة $mealId',
      proteinType: ProteinType.chicken,
      carbsType: CarbsType.rice,
      cookedAt: day,
      entryType: MealEntryType.cooked,
      notes: null,
      createdAt: day,
    );

AppSettingsData _settings() => AppSettingsData(
  id: 1,
  cooldownDays: 14,
  chickenCooldownDays: 7,
  beefCooldownDays: 2,
  fishCooldownDays: 4,
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

void main() {
  const engine = CooldownEngine();

  // Wednesday — deliberately not a Friday, so `isFridaySpecial` cannot move a
  // band and the lottery is the only thing ordering the pool.
  final wednesday = DateTime(2026, 10, 7, 12, 0);

  // Nine interchangeable meals: same protein, same carbs, none cooked, no
  // favourite, no Friday flag → one score band, so the seeded value decides the
  // whole order, and `_selectDiverse` walks it straight through.
  final pool = List.generate(9, (i) => _meal(i + 1));

  List<int> shown(RecommendationResult<Meal> r) =>
      r.recommendations.map((m) => m.id).toList();

  group('seeded lottery is per meal, not per pool position', () {
    test(
      'cooking the top card leaves the other two exactly where they were',
      () {
        for (var seed = 0; seed < 25; seed++) {
          final before = engine.compute<Meal>(
            meals: pool,
            history: const [],
            settings: _settings(),
            today: wednesday,
            shuffleSeed: seed,
          );
          expect(before.recommendations, hasLength(3), reason: 'seed $seed');
          final topCard = before.recommendations.first.id;

          final after = engine.compute<Meal>(
            meals: pool,
            history: [_cooked(1, topCard, wednesday)],
            settings: _settings(),
            today: wednesday,
            shuffleSeed: seed,
          );

          // The remaining cards keep their relative order and simply move up a
          // slot: what used to be #2 and #3 are the new #1 and #2.
          expect(
            shown(after).sublist(0, 2),
            equals(shown(before).sublist(1, 3)),
            reason:
                'logging $topCard must not re-shuffle the cards nobody tapped '
                '(seed $seed: ${shown(before)} -> ${shown(after)})',
          );
        }
      },
    );

    test('the day is stable across an unrelated history write', () {
      final before = engine.compute<Meal>(
        meals: pool,
        history: const [],
        settings: _settings(),
        today: wednesday,
        shuffleSeed: 3,
      );
      // A takeout row has no meal id, so it cannot change eligibility — and it
      // must not change a single card.
      final after = engine.compute<Meal>(
        meals: pool,
        history: [
          MealHistoryData(
            id: 1,
            mealId: null,
            mealName: 'takeout',
            proteinType: ProteinType.none,
            carbsType: CarbsType.none,
            cookedAt: wednesday,
            entryType: MealEntryType.takeout,
            notes: null,
            createdAt: wednesday,
          ),
        ],
        settings: _settings(),
        today: wednesday,
        shuffleSeed: 3,
      );
      expect(shown(after), equals(shown(before)));
    });

    test('a new day reshuffles, and so does an explicit refresh', () {
      final today = engine.compute<Meal>(
        meals: pool,
        history: const [],
        settings: _settings(),
        today: wednesday,
        shuffleSeed: 0,
      );
      final tomorrow = engine.compute<Meal>(
        meals: pool,
        history: const [],
        settings: _settings(),
        today: wednesday.add(const Duration(days: 1)),
        shuffleSeed: 0,
      );
      final refreshed = engine.compute<Meal>(
        meals: pool,
        history: const [],
        settings: _settings(),
        today: wednesday,
        shuffleSeed: 1,
      );

      // Not a per-day constant and not a per-seed constant: both must be free to
      // move the cards, or "refresh" and "tomorrow" would be no-ops on a vault
      // this uniform.
      expect(shown(tomorrow), isNot(equals(shown(today))));
      expect(shown(refreshed), isNot(equals(shown(today))));
    });

    test('the same day, seed and pool replay identically', () {
      final first = engine.compute<Meal>(
        meals: pool,
        history: const [],
        settings: _settings(),
        today: wednesday,
        shuffleSeed: 7,
      );
      final second = engine.compute<Meal>(
        meals: pool.reversed.toList(),
        history: const [],
        settings: _settings(),
        today: wednesday,
        shuffleSeed: 7,
      );
      // The value belongs to the meal, not to its position in the pool or to the
      // order rows arrive in from the DAO. The pair that used to break this was
      // *set membership* — see the case above — which is the same root cause: a
      // per-position draw makes the pool part of the meal's number.
      expect(shown(second), equals(shown(first)));
    });
  });
}
