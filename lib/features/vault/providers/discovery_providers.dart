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

/// The cloud copy of one specific meal, watched by the full meal screen's sync
/// mark. `null` means the vault no longer carries it.
final cloudMealByIdProvider =
    FutureProvider.autoDispose.family<CloudMeal?, String>((ref, cloudId) {
  return ref.watch(discoveryRepositoryProvider).fetchMealById(cloudId);
});

class DiscoveryNotifier extends StateNotifier<AsyncValue<void>> {
  final MealsDao _mealsDao;
  final AppDatabase _db;
  final Future<String?> Function(String?) _localizeImage;

  DiscoveryNotifier(
    this._mealsDao,
    this._db, {
    Future<String?> Function(String?)? localizeImage,
  })  : _localizeImage =
            localizeImage ?? MealImageLocalizer.instance.localize,
        super(const AsyncValue.data(null));

  /// Copies [cloudMeal] into the vault and returns the new local row id, or
  /// `null` when the insert failed. The meal screen uses the id to swap itself
  /// onto the local row right after a download.
  Future<int?> downloadMeal(CloudMeal cloudMeal) async {
    state = const AsyncValue.loading();
    try {
      final companion = await _createCompanion(cloudMeal);
      final id = await _mealsDao.insertMeal(companion);
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateMeal(int localId, CloudMeal cloudMeal) async {
    state = const AsyncValue.loading();
    try {
      final companion = await _createCompanion(cloudMeal);
      await _mealsDao.updateMealCompanion(localId, companion);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Detaches [oldLocalId] from its cloud link and copies [cloudMeal] in as a
  /// fresh vault row. The image download happens BEFORE any database write so
  /// a network failure can never orphan the old meal, and both writes share
  /// one transaction so they commit together or not at all. Errors are set on
  /// the state AND rethrown so the caller can show a real error toast.
  Future<void> downloadAsNew(int oldLocalId, CloudMeal cloudMeal) async {
    state = const AsyncValue.loading();
    try {
      final companion = await _createCompanion(cloudMeal);
      await _db.transaction(() async {
        await _mealsDao.updateMealCompanion(oldLocalId, const MealsCompanion(
          cloudId: drift.Value(null),
        ));
        await _mealsDao.insertMeal(companion);
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<MealsCompanion> _createCompanion(CloudMeal cloudMeal) async {
    // Store the photo FILE, not the bare URL, so the vault renders offline.
    // On failure the URL is kept (works online) and the startup backfill in
    // MealImageLocalizer retries on a later launch.
    final localPhoto = await _localizeImage(cloudMeal.imageUrl);
    return MealsCompanion(
      name: drift.Value(cloudMeal.name),
      photoPath: drift.Value(localPhoto),
      shortName: drift.Value(cloudMeal.shortName),
      proteinType: drift.Value(cloudProteinType(cloudMeal.proteinType)),
      carbsType: drift.Value(cloudCarbsType(cloudMeal.carbsType)),
      category: drift.Value(cloudCategory(cloudMeal.category)),
      prepTime: drift.Value(cloudMeal.prepTimeMinutes),
      isFridaySpecial: drift.Value(cloudMeal.isFridaySpecial),
      isBudgetFriendly: drift.Value(cloudMeal.isBudgetFriendly),
      cloudId: drift.Value(cloudMeal.id),
      notes: drift.Value(cloudMeal.notes),
    );
  }
}

// The cloud vocabulary is its own string set; these are the only place it is
// translated into local enums (download and sync-diff must agree).
ProteinType cloudProteinType(String p) {
  switch (p) {
    case 'chicken': return ProteinType.chicken;
    case 'beef': return ProteinType.beef;
    case 'fish': return ProteinType.fish;
    case 'meatless': return ProteinType.legume;
    default: return ProteinType.none;
  }
}

CarbsType cloudCarbsType(String c) {
  switch (c) {
    case 'rice': return CarbsType.rice;
    case 'pasta': return CarbsType.pasta;
    case 'bread': return CarbsType.bread;
    default: return CarbsType.none;
  }
}

MealCategory cloudCategory(String c) {
  switch (c) {
    case 'tabeekh': return MealCategory.egyptianTraditional;
    case 'casserole': return MealCategory.ovenBaked;
    case 'dry_sandwich': return MealCategory.fastFood;
    case 'seafood': return MealCategory.seafood;
    case 'soup_stew': return MealCategory.soupStew;
    case 'vegetarian': return MealCategory.vegetarian;
    default: return MealCategory.egyptianTraditional;
  }
}

final discoveryControllerProvider = StateNotifierProvider<DiscoveryNotifier, AsyncValue<void>>((ref) {
  final dao = ref.watch(mealsDaoProvider);
  final db = ref.watch(appDatabaseProvider);
  return DiscoveryNotifier(dao, db);
});
