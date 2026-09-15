import 'dart:async';
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

  // Show loading only on first load when no value is available yet.
  // Once hasValue is true we keep showing data even while isLoading
  // (scoped-undo 1.3 needs instant recompute after delete).
  final isInitialLoading = (mealsAsync.isLoading && !mealsAsync.hasValue) ||
      (historyAsync.isLoading && !historyAsync.hasValue) ||
      (settingsAsync.isLoading && !settingsAsync.hasValue);
  if (isInitialLoading) {
    return const AsyncValue.loading();
  }

  final meals = mealsAsync.valueOrNull ?? const [];
  final history = historyAsync.valueOrNull ?? const [];
  final AppSettingsData fallbackSettings = AppSettingsData(
    id: 1,
    cooldownDays: 14,
    chickenCooldownDays: 7,
    beefCooldownDays: 10,
    fishCooldownDays: 5,
    meatlessCooldownDays: 0, // 0 = disabled by default per migration v8, optimal
    preventRepeatProtein: true,
    preventRepeatCarbs: true,
    notificationHour: 12,
    notificationMinute: 0,
    notificationsEnabled: false,
    themeMode: AppThemeModePreference.system,
    language: AppLanguagePreference.ar,
    isFirstRun: true,
  );
  final settings = settingsAsync.valueOrNull ?? fallbackSettings;

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



/// Recommendation mutation controller for marking cooked/leftovers.
class RecommendationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Logs a meal as 'cooked today'. Dynamically obtains DateTime.now() if cookedAt is null.
  Future<int> logCookedToday(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await historyDao.logCookedMeal(
        meal,
        cookedAt: cookedAt ?? DateTime.now(),
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
  Future<int> markCookedToday(Meal meal, {DateTime? cookedAt, String? notes}) =>
      logCookedToday(meal, cookedAt: cookedAt, notes: notes);

  /// Logs a meal as 'leftover'. Dynamically obtains DateTime.now() if cookedAt is null.
  Future<int> logLeftover(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      final id = await historyDao.logLeftoverMeal(
        meal,
        cookedAt: cookedAt ?? DateTime.now(),
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
  Future<int> markLeftover(Meal meal, {DateTime? cookedAt, String? notes}) =>
      logLeftover(meal, cookedAt: cookedAt, notes: notes);

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


