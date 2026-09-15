import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/cooldown_engine.dart';

/// Provides the pure Dart CooldownEngine instance.
final engineProvider = Provider<CooldownEngine>((ref) {
  return const CooldownEngine();
});

/// Alias for compatibility
final cooldownEngineProvider = engineProvider;

/// Overridable provider for current DateTime (enables deterministic time traveling in tests).
final currentTimeProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

/// Primary derived domain provider returning full recommendation result (top 3 meals + metadata).
final todayRecommendationsProvider = Provider<AsyncValue<RecommendationResult<Meal>>>((ref) {
  final mealsAsync = ref.watch(allMealsProvider);
  final historyAsync = ref.watch(mealHistoryProvider);
  final settingsAsync = ref.watch(appSettingsProvider);
  final engine = ref.watch(engineProvider);
  final now = ref.watch(currentTimeProvider);

  // Propagate Errors if any dependency failed
  if (mealsAsync.hasError) {
    return AsyncValue.error(mealsAsync.error!, mealsAsync.stackTrace!);
  }
  if (historyAsync.hasError) {
    return AsyncValue.error(historyAsync.error!, historyAsync.stackTrace!);
  }
  if (settingsAsync.hasError) {
    return AsyncValue.error(settingsAsync.error!, settingsAsync.stackTrace!);
  }

  // Always compute with available data — never block on isLoading.
  // Using valueOrNull with fallbacks ensures scoped-undo 1.3 recovers instantly
  // even when Drift streams are mid-refresh (fixes waitForRecs polling).
  final meals = mealsAsync.valueOrNull ?? const [];
  final history = historyAsync.valueOrNull ?? const [];
  final settings = settingsAsync.valueOrNull ?? AppSettingsDao.defaultSettings;

  // 3. Compute recommendations via CooldownEngine
  try {
    final result = engine.compute<Meal>(
      meals: meals,
      history: history,
      settings: settings,
      today: now,
    );
    return AsyncValue.data(result);
  } catch (err, st) {
    return AsyncValue.error(err, st);
  }
});

/// Alias matching m3_riverpod_plan
final recommendationProvider = todayRecommendationsProvider;

/// Convenience provider extracting only the `List<Meal>` recommendations
final recommendationMealsProvider = Provider<AsyncValue<List<Meal>>>((ref) {
  return ref.watch(todayRecommendationsProvider).whenData((r) => r.recommendations);
});

/// Provider for Spin the Wheel Roulette candidate pool.
/// Requires at least 2 distinct recommendation candidates; otherwise returns empty list (disabled).
final spinWheelCandidatesProvider = Provider<List<Meal>>((ref) {
  final recsAsync = ref.watch(todayRecommendationsProvider);
  final recs = recsAsync.valueOrNull?.recommendations ?? const [];
  if (recs.length < 2) {
    return const []; // Wheel disabled when candidates count is less than 2
  }
  return recs;
});

/// Recommendation mutation controller for marking cooked/leftovers.
class RecommendationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Logs a meal as 'cooked today'.
  Future<int> logCookedToday(Meal meal, {String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await historyDao.logCookedMeal(
        meal,
        cookedAt: ref.read(currentTimeProvider),
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Alias for logCookedToday
  Future<int> markCookedToday(Meal meal, {String? notes}) =>
      logCookedToday(meal, notes: notes);

  /// Logs a meal as 'leftover'.
  Future<int> logLeftover(Meal meal, {String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await historyDao.logLeftoverMeal(
        meal,
        cookedAt: ref.read(currentTimeProvider),
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Alias for logLeftover
  Future<int> markLeftover(Meal meal, {String? notes}) =>
      logLeftover(meal, notes: notes);

  /// Undoes a cooking log entry.
  /// If [historyEntryId] is provided, deletes that exact history entry (scoped undo).
  /// If [historyEntryId] is omitted or null, falls back to deleting the most recent entry.
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
      // Force immediate recompute of derived providers — Drift's watch() can lag
      // up to a frame, and waitForRecs polls every 20ms for 5s. Invalidating
      // ensures 1.3 sees the restored meal without waiting for stream debounce.
      ref.invalidate(mealHistoryProvider);
      // todayRecommendationsProvider is a Provider watching mealHistoryProvider,
      // but explicitly invalidating guarantees synchronous recompute on next read.
      ref.invalidate(todayRecommendationsProvider);
      // Small pump to let StreamProvider re-emit before callers poll
      await Future.delayed(const Duration(milliseconds: 10));
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Explicitly deletes a specific history log entry by ID (scoped undo alias).
  Future<void> undoHistoryEntry(int historyEntryId) =>
      undoLastCookingLog(historyEntryId);
}

final recommendationControllerProvider =
    AsyncNotifierProvider<RecommendationController, void>(() {
  return RecommendationController();
});

/// Controller handling Spin the Wheel randomization
class HomeController {
  final Ref _ref;
  HomeController(this._ref);

  /// Spins the wheel and returns a randomly selected eligible meal, or null if < 2 candidates.
  Meal? spinTheWheel() {
    final candidates = _ref.read(spinWheelCandidatesProvider);
    if (candidates.length < 2) return null;
    final randomIndex = Random().nextInt(candidates.length);
    return candidates[randomIndex];
  }
}

final homeControllerProvider = Provider<HomeController>((ref) {
  return HomeController(ref);
});
