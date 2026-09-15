import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final databaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(appDatabaseProvider);
});

final mealsDaoProvider = Provider<MealsDao>((ref) {
  return ref.watch(appDatabaseProvider).mealsDao;
});

final mealHistoryDaoProvider = Provider<MealHistoryDao>((ref) {
  return ref.watch(appDatabaseProvider).mealHistoryDao;
});

final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  return ref.watch(appDatabaseProvider).appSettingsDao;
});
