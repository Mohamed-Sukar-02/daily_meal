import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/services/meal_image_localizer.dart';
import '../data/models/cloud_meal.dart';
import '../data/discovery_repository.dart';
import '../../../core/database/database_providers.dart';

final publicMealsProvider = FutureProvider<List<CloudMeal>>((ref) async {
  final repo = ref.watch(discoveryRepositoryProvider);
  return repo.fetchPublicMeals();
});

class DiscoveryNotifier extends StateNotifier<AsyncValue<void>> {
  final MealsDao _mealsDao;

  DiscoveryNotifier(this._mealsDao) : super(const AsyncValue.data(null));

  Future<void> downloadMeal(CloudMeal cloudMeal) async {
    state = const AsyncValue.loading();
    try {
      final companion = await _createCompanion(cloudMeal);
      await _mealsDao.insertMeal(companion);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateMeal(int localId, CloudMeal cloudMeal) async {
    state = const AsyncValue.loading();
    try {
      final companion = await _createCompanion(cloudMeal);
      await _mealsDao.updateMealCompanion(localId, companion);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> downloadAsNew(int oldLocalId, CloudMeal cloudMeal) async {
    state = const AsyncValue.loading();
    try {
      // 1. Detach old meal from cloud
      await _mealsDao.updateMealCompanion(oldLocalId, const MealsCompanion(
        cloudId: drift.Value(null),
      ));
      
      // 2. Insert new meal with cloudId
      final companion = await _createCompanion(cloudMeal);
      await _mealsDao.insertMeal(companion);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<MealsCompanion> _createCompanion(CloudMeal cloudMeal) async {
    // Store the photo FILE, not the bare URL, so the vault renders offline.
    // On failure the URL is kept (works online) and the startup backfill in
    // MealImageLocalizer retries on a later launch.
    final localPhoto =
        await MealImageLocalizer.instance.localize(cloudMeal.imageUrl);
    return MealsCompanion(
      name: drift.Value(cloudMeal.name),
      photoPath: drift.Value(localPhoto),
      shortName: drift.Value(cloudMeal.shortName),
      proteinType: drift.Value(_mapProtein(cloudMeal.proteinType)),
      carbsType: drift.Value(_mapCarbs(cloudMeal.carbsType)),
      category: drift.Value(_mapCategory(cloudMeal.category)),
      prepTime: drift.Value(cloudMeal.prepTimeMinutes),
      isFridaySpecial: drift.Value(cloudMeal.isFridaySpecial),
      isBudgetFriendly: drift.Value(cloudMeal.isBudgetFriendly),
      cloudId: drift.Value(cloudMeal.id),
    );
  }

  ProteinType _mapProtein(String p) {
    switch (p) {
      case 'chicken': return ProteinType.chicken;
      case 'beef': return ProteinType.beef;
      case 'fish': return ProteinType.fish;
      case 'meatless': return ProteinType.legume;
      default: return ProteinType.none;
    }
  }

  CarbsType _mapCarbs(String c) {
    switch (c) {
      case 'rice': return CarbsType.rice;
      case 'pasta': return CarbsType.pasta;
      case 'bread': return CarbsType.bread;
      default: return CarbsType.none;
    }
  }

  MealCategory _mapCategory(String c) {
    switch (c) {
      case 'tabeekh': return MealCategory.egyptianTraditional;
      case 'casserole': return MealCategory.ovenBaked;
      case 'dry_sandwich': return MealCategory.fastFood;
      case 'seafood': return MealCategory.seafood;
      default: return MealCategory.egyptianTraditional;
    }
  }
}

final discoveryControllerProvider = StateNotifierProvider<DiscoveryNotifier, AsyncValue<void>>((ref) {
  final dao = ref.watch(mealsDaoProvider);
  return DiscoveryNotifier(dao);
});
