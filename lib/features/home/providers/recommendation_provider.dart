import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utils/app_date_utils.dart' as app_date_utils;
import '../../vault/providers/vault_providers.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/cooldown_engine.dart';
import 'planned_meal_provider.dart';

final engineProvider = Provider<CooldownEngine>((ref) {
  return const CooldownEngine();
});

/// Wall clock for day-scoped providers. A plain `Provider<DateTime>` freezes
/// `DateTime.now()` at its first read, so an app left open past midnight kept
/// filtering cooldowns by yesterday until a restart. This stream stays silent
/// all day and fires once when the local calendar day rolls over; consumers
/// rebuild, their eligibility key changes, and the new day is computed.
final currentTimeProvider = StreamProvider<DateTime>((ref) {
  var lastDay = app_date_utils.toLocalDay(DateTime.now());
  final controller = StreamController<DateTime>();
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    final now = DateTime.now();
    final day = app_date_utils.toLocalDay(now);
    if (day != lastDay) {
      lastDay = day;
      controller.add(now);
    }
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

final refreshSeedProvider = StateProvider<int>((ref) => 0);

/// Fallback row used for the frames in which the settings stream has not
/// emitted yet. Matches the columns' defaults, so the very first suggestion
/// pass ranks against the same windows a fresh install actually has.
AppSettingsData _fallbackSettings() => AppSettingsData(
      id: 1,
      cooldownDays: 14,
      chickenCooldownDays: 2,
      beefCooldownDays: 2,
      fishCooldownDays: 4,
      meatlessCooldownDays: 3,
      notificationHour: 12,
      notificationMinute: 0,
      notificationsEnabled: false,
      themeMode: AppThemeModePreference.system,
      language: AppLanguagePreference.ar,
      isFirstRun: true,
      recommendationSource: RecommendationSource.vault_only,
      autoFridayFeastFilter: false,
    );

/// Fingerprint of everything that is allowed to change *which* meals get
/// suggested. Deliberately blind to a meal's own cosmetic fields: the drift
/// stream emits on every write, and treating a heart tap as a re-rank trigger
/// makes the cards the user is looking at jump mid-click.
///
/// Every part of it maps to a value [CooldownEngine] actually reads:
///  * [dayEpoch] + [refreshSeed] — the seeded lottery in `_rankCandidates`;
///  * the five cooldown ints — `_resolveSpecificCooldown` turns a protein into
///    a window, which is what `_filterCandidates` screens on;
///  * one `id:protein:carbs:friday:cooldown` token per meal — `proteinType`
///    picks the cooldown window *and* the variety rule in `_selectDiverse`,
///    `carbsType` is that rule's second axis, `isFridaySpecial` is a +15/-5
///    swing in `calculateMealScore` (i.e. enough to move a meal across the
///    5-point interchangeable score bands), and `customCooldownDays` is the
///    per-meal window `CooldownEngine._resolveSpecificCooldown` now asks
///    before anything else. Ids alone missed them, so a meal that just became
///    ineligible (or a new Friday feast) kept its pinned slot;
///  * the history signature — see below, the row count was not enough.
///
/// Left out on purpose: `isFavorite` (+5) is a pure score nudge and the heart
/// button is exactly the tap that must never move a card; `name`, `photoPath`,
/// `shortName`, `prepTime`, `category`, `updatedAt` and the history
/// `notes`/`entryType` snapshot are never read by the engine (`category` is a
/// vault-filter tag, not a scheduling rule). None of them make
/// a meal ineligible, and the pin-replay below still rebuilds the cards from
/// the fresh rows, so those edits show up without reshuffling anything.
String _eligibilityKey({
  required int dayEpoch,
  required int refreshSeed,
  required List<Meal> meals,
  required List<MealHistoryData> history,
  required AppSettingsData settings,
}) {
  // `-` for "no override", the number itself once a meal carries one. The
  // engine reads that value before the protein windows, so leaving it out of
  // the token would let a meal set to "never again for 30 days" keep the card
  // slot it had earned under the old window.
  final mealSignature = (meals
          .map((m) =>
              '${m.id}:${m.proteinType.name}:${m.carbsType.name}:${m.isFridaySpecial ? 'F' : '-'}:c${m.customCooldownDays ?? '-'}')
          .toList()
        ..sort())
      .join(',');

  // WHY newest-cooked-day-per-meal instead of history.length: the engine only
  // ever reads that same map (`lastCookedByMealId`), so the count missed real
  // changes — editing a row's date, or a delete+insert landing in one frame,
  // keep the length and left the day's pinned slots stale. It stays blind to
  // history.length itself (older duplicate rows and takeout/skip rows with no
  // meal id) because the engine is blind to them too — re-ranking for those
  // would just move cards for no reason. Day granularity, because
  // `toLocalDay` is what the engine normalises to: a time-only edit inside the
  // same calendar day cannot change the selection.
  final newestDayByMeal = <int, int>{};
  for (final entry in history) {
    final mealId = entry.mealId;
    if (mealId == null) continue;
    final day = app_date_utils.daysSinceEpoch(entry.cookedAt);
    final known = newestDayByMeal[mealId];
    if (known == null || day > known) newestDayByMeal[mealId] = day;
  }
  final historySignature = (newestDayByMeal.keys.toList()..sort())
      .map((id) => '$id@${newestDayByMeal[id]}')
      .join(',');

  return [
    dayEpoch,
    refreshSeed,
    mealSignature,
    historySignature,
    settings.cooldownDays,
    settings.chickenCooldownDays,
    settings.beefCooldownDays,
    settings.fishCooldownDays,
    settings.meatlessCooldownDays,
  ].join('|');
}

final todayRecommendationsProvider =
    NotifierProvider<TodayRecommendationsNotifier, AsyncValue<RecommendationResult<Meal>>>(
  TodayRecommendationsNotifier.new,
);

class TodayRecommendationsNotifier
    extends Notifier<AsyncValue<RecommendationResult<Meal>>> {
  String? _pinnedKey;
  List<int>? _pinnedIds;
  RecommendationResult<Meal>? _pinnedResult;
  int _lastRefreshSeed = 0;

  @override
  AsyncValue<RecommendationResult<Meal>> build() {
    final mealsAsync = ref.watch(allMealsProvider);
    final historyAsync = ref.watch(mealHistoryProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final engine = ref.watch(engineProvider);
    // No blocking on the day-ticker for the very first frame: until it emits
    // (it only fires at midnight rollover) DateTime.now() is the truth.
    final now = ref.watch(currentTimeProvider).valueOrNull ?? DateTime.now();
    final refreshSeed = ref.watch(refreshSeedProvider);

    if (mealsAsync.hasError) {
      return AsyncValue.error(mealsAsync.error!, mealsAsync.stackTrace!);
    }
    if (historyAsync.hasError) {
      return AsyncValue.error(historyAsync.error!, historyAsync.stackTrace!);
    }
    if (settingsAsync.hasError) {
      return AsyncValue.error(settingsAsync.error!, settingsAsync.stackTrace!);
    }

    final isInitialLoading = (mealsAsync.isLoading && !mealsAsync.hasValue) ||
        (historyAsync.isLoading && !historyAsync.hasValue) ||
        (settingsAsync.isLoading && !settingsAsync.hasValue);
    if (isInitialLoading) {
      return const AsyncValue.loading();
    }

    final meals = mealsAsync.valueOrNull ?? const <Meal>[];
    final history = historyAsync.valueOrNull ?? const [];
    final settings = settingsAsync.valueOrNull ?? _fallbackSettings();

    final key = _eligibilityKey(
      dayEpoch: app_date_utils.daysSinceEpoch(now),
      refreshSeed: refreshSeed,
      meals: meals,
      history: history,
      settings: settings,
    );

    final pinned = _pinnedResult;
    final pinnedIds = _pinnedIds;
    if (pinned != null && pinnedIds != null && _pinnedKey == key) {
      // Same eligibility: keep today's three meals and their order, but rebuild
      // them from the fresh rows so edited fields (photo, name, heart) show up.
      final byId = {for (final m in meals) m.id: m};
      final fresh = pinnedIds.map((id) => byId[id]).whereType<Meal>().toList();
      if (fresh.length == pinnedIds.length) {
        return AsyncValue.data(RecommendationResult<Meal>(
          recommendations: fresh,
          relaxationLevel: pinned.relaxationLevel,
          isEmptyVault: pinned.isEmptyVault,
          computedDate: pinned.computedDate,
          repeatedIds: pinned.repeatedIds,
        ));
      }
    }

    // A recompute caused by the pull-to-refresh seed must keep the confirm
    // dialog's promise ("change the 3 current suggestions"): the engine gets
    // the ids currently on screen and avoids re-serving them while the pool
    // still has alternatives. Any OTHER key change (new day, history write,
    // meal added/removed, settings change) wants the natural best selection.
    final isExplicitRefresh =
        _pinnedIds != null && refreshSeed != _lastRefreshSeed;

    try {
      final result = engine.compute<Meal>(
        meals: meals,
        history: history,
        settings: settings,
        today: now,
        shuffleSeed: refreshSeed,
        excludeIds: isExplicitRefresh ? _pinnedIds!.toSet() : null,
      );
      _pinnedKey = key;
      _pinnedIds = result.recommendations.map((m) => m.id).toList();
      _pinnedResult = result;
      _lastRefreshSeed = refreshSeed;
      return AsyncValue.data(result);
    } catch (err, st) {
      return AsyncValue.error(err, st);
    }
  }

}

/// Vault size measured against the longest cooldown window in force — the
/// "vault health" reading behind [vaultCapacityProvider].
class VaultCapacity {
  final int mealCount;

  /// The window the vault is judged by: the global period, or a protein rule
  /// that is stricter than it.
  final int cooldownDays;

  const VaultCapacity({required this.mealCount, required this.cooldownDays});

  /// Days of cooldown the vault cannot cover with distinct meals.
  int get shortfall => cooldownDays - mealCount;

  /// True when the vault is too small to honour its own cooldown: at least one
  /// meal is guaranteed to come back inside a window the user asked to keep
  /// empty, which is exactly what the relaxation banner then apologises for.
  bool get isTooSmall => shortfall > 0;
}

/// Can this vault actually survive its cooldown settings?
///
/// A meal blocks itself for [AppSettingsData.cooldownDays] (or its protein's
/// own window) after being cooked, so one meal covers one day of that window.
/// A vault smaller than the longest window in force therefore repeats — the
/// engine walks its relaxation levels and serves a dish earlier than asked,
/// and the only real fix is more meals. Warns on the headline number the user
/// configured, matching how the cooldown is explained in the Settings screen.
///
/// `null` while either stream has no value yet, or with an empty vault: the
/// empty vault already has its own screen, and a "too small" banner stacked on
/// top of it would say nothing the CTA does not.
final vaultCapacityProvider = Provider<VaultCapacity?>((ref) {
  final meals = ref.watch(allMealsProvider).valueOrNull;
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  if (meals == null || settings == null || meals.isEmpty) return null;

  var longest = settings.cooldownDays;
  for (final protein in meals.map((meal) => meal.proteinType.name).toSet()) {
    // Same resolution order as `CooldownEngine._resolveSpecificCooldown`:
    // chicken, beef, fish, and meatless (none, legume, dairy) own a window
    // of their own; unknown proteins fall back to the global period.
    final window = switch (protein) {
      'chicken' => settings.chickenCooldownDays,
      'beef' => settings.beefCooldownDays,
      'fish' => settings.fishCooldownDays,
      'none' || 'legume' || 'dairy' => settings.meatlessCooldownDays,
      _ => settings.cooldownDays,
    };
    if (window > longest) longest = window;
  }

  return VaultCapacity(mealCount: meals.length, cooldownDays: longest);
});

class RecommendationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<int> logCookedToday(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await db.transaction(() async {
        return await historyDao.logCookedMeal(
          meal,
          cookedAt: cookedAt ?? DateTime.now(),
          notes: notes,
        );
      });
      // The day is answered now; a plan claiming otherwise must go with it.
      await retireTodayPlan(ref);
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<int> markCookedToday(Meal meal, {DateTime? cookedAt, String? notes}) =>
      logCookedToday(meal, cookedAt: cookedAt, notes: notes);

  Future<int> logLeftover(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await db.transaction(() async {
        return await historyDao.logLeftoverMeal(
          meal,
          cookedAt: cookedAt ?? DateTime.now(),
          notes: notes,
        );
      });
      // The day is answered now; a plan claiming otherwise must go with it.
      await retireTodayPlan(ref);
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<int> markLeftover(Meal meal, {DateTime? cookedAt, String? notes}) =>
      logLeftover(meal, cookedAt: cookedAt, notes: notes);

  Future<int> markLeftoverEntry({
    int? mealId,
    required String mealName,
    ProteinType proteinType = ProteinType.none,
    CarbsType carbsType = CarbsType.none,
    DateTime? cookedAt,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await db.transaction(() async {
        return await historyDao.logMeal(
          mealId: mealId,
          mealName: mealName,
          proteinType: proteinType,
          carbsType: carbsType,
          cookedAt: cookedAt ?? DateTime.now(),
          entryType: MealEntryType.leftover,
          notes: notes,
        );
      });
      // The day is answered now; a plan claiming otherwise must go with it.
      await retireTodayPlan(ref);
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<int> markTakeout({DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await db.transaction(() async {
        return await historyDao.logTakeoutMeal(
          cookedAt: cookedAt ?? DateTime.now(),
          notes: notes,
        );
      });
      // The day is answered now; a plan claiming otherwise must go with it.
      await retireTodayPlan(ref);
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<int> markSkipped({DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await db.transaction(() async {
        return await historyDao.logSkippedMeal(
          cookedAt: cookedAt ?? DateTime.now(),
          notes: notes,
        );
      });
      // The day is answered now; a plan claiming otherwise must go with it.
      await retireTodayPlan(ref);
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> undoLastCookingLog([int? historyEntryId]) async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      if (historyEntryId != null) {
        await historyDao.deleteHistoryEntry(historyEntryId);
      } else {
        final recent = await historyDao.getRecentHistory(limit: 1);
        if (recent.isNotEmpty) {
          await historyDao.deleteHistoryEntry(recent.first.id);
        }
      }
      ref.invalidate(mealHistoryProvider);
      ref.invalidate(todayRecommendationsProvider);
      await Future.delayed(const Duration(milliseconds: 10));
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Toggles a meal's favourite flag (heart button on the home cards).
  ///
  /// The caller fires this without awaiting (the heart animates instantly and
  /// the write lands in the background), so errors are captured in [state]
  /// instead of being rethrown — a rethrown, unawaited future would surface
  /// as an unhandled async exception.
  Future<void> toggleFavorite(int mealId, bool currentStatus) async {
    try {
      final dao = ref.read(mealsDaoProvider);
      await dao.toggleFavorite(mealId, currentStatus);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }
}

final recommendationControllerProvider =
    AsyncNotifierProvider<RecommendationController, void>(() {
  return RecommendationController();
});
