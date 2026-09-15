import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

final mealHistoryProvider = StreamProvider<List<MealHistoryData>>((ref) {
  final dao = ref.watch(mealHistoryDaoProvider);
  return dao.watchHistory();
});

final mealHistoryWithMealProvider = StreamProvider<List<MealHistoryWithMeal>>((ref) {
  final dao = ref.watch(mealHistoryDaoProvider);
  return dao.watchHistoryWithMeal();
});

final latestCookedMealProvider = StreamProvider<MealHistoryData?>((ref) {
  final dao = ref.watch(mealHistoryDaoProvider);
  return dao.watchLatestCookedMeal();
});

class HistoryController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<int> logCookedMeal(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final dao = ref.read(mealHistoryDaoProvider);
      final id = await db.transaction(() async {
        return await dao.logCookedMeal(
          meal,
          cookedAt: cookedAt,
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

  Future<int> logLeftoverMeal(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final dao = ref.read(mealHistoryDaoProvider);
      final id = await db.transaction(() async {
        return await dao.logLeftoverMeal(
          meal,
          cookedAt: cookedAt,
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

  Future<int> deleteHistoryEntry(int id) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealHistoryDaoProvider);
      final deleted = await dao.deleteHistoryEntry(id);
      state = const AsyncValue.data(null);
      return deleted;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<int> clearAllHistory() async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealHistoryDaoProvider);
      final deleted = await dao.clearAllHistory();
      state = const AsyncValue.data(null);
      return deleted;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
}

final historyControllerProvider = AsyncNotifierProvider<HistoryController, void>(() {
  return HistoryController();
});
