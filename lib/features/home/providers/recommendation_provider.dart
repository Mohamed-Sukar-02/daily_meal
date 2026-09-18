import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/cooldown_engine.dart';

final engineProvider = Provider<CooldownEngine>((ref) {
  return const CooldownEngine();
});

final currentTimeProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

final todayRecommendationsProvider = Provider<AsyncValue<RecommendationResult<Meal>>>((ref) {
  final mealsAsync = ref.watch(allMealsProvider);
  final historyAsync = ref.watch(mealHistoryProvider);
  final settingsAsync = ref.watch(appSettingsProvider);
  final engine = ref.watch(engineProvider);
  final now = ref.watch(currentTimeProvider);

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

  final meals = mealsAsync.valueOrNull ?? const [];
  final history = historyAsync.valueOrNull ?? const [];
  final AppSettingsData fallbackSettings = AppSettingsData(
    id: 1,
    cooldownDays: 14,
    chickenCooldownDays: 2,
    beefCooldownDays: 2,
    fishCooldownDays: 4,
    meatlessCooldownDays: 0,
    notificationHour: 12,
    notificationMinute: 0,
    notificationsEnabled: false,
    themeMode: AppThemeModePreference.system,
    language: AppLanguagePreference.ar,
    isFirstRun: true,
    recommendationSource: RecommendationSource.vault_only,
    autoFridayFeastFilter: false,
  );
  final settings = settingsAsync.valueOrNull ?? fallbackSettings;

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

  Future<void> undoHistoryEntry(int historyEntryId) =>
      undoLastCookingLog(historyEntryId);

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
