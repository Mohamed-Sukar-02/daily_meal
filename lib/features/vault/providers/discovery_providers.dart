import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/services/meal_image_localizer.dart';
import '../data/cloud_vocabulary.dart';
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
      final existingByCloudId = await _mealsDao.getMealByCloudId(cloudMeal.id);
      final existingByName = await _mealsDao.getMealByName(cloudMeal.name);
      
      final targetMeal = existingByCloudId ?? existingByName;
      // When the vault already holds this meal the companion is an UPDATE, and
      // an update may not copy a fold over a value the cloud cannot name.
      final companion = await _createCompanion(cloudMeal, existing: targetMeal);

      int id;
      if (targetMeal != null) {
        await _mealsDao.updateMealCompanion(targetMeal.id, companion);
        id = targetMeal.id;
      } else {
        id = await _mealsDao.insertMeal(companion);
      }
      
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
      final existing = await _mealsDao.getMealById(localId);
      final companion =
          await _createCompanion(cloudMeal, existing: existing);
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

  /// Builds the local row for a cloud meal.
  ///
  /// [existing] is the row being overwritten, when there is one. It matters for
  /// exactly two fields: `proteinType` and `carbsType` are narrower in the cloud
  /// (`firestore.rules` allows five protein tokens and four carbs tokens), so
  /// `dairy` and `potato` are stored as `other`/`none`. Writing that fold back
  /// over a local row would turn a tag the user set into "no protein" / "no
  /// carbs" — and for protein that is not cosmetic, `none` is what selects the
  /// meatless cooldown window. New inserts always carry the full value: the
  /// columns are NOT NULL.
  Future<MealsCompanion> _createCompanion(
    CloudMeal cloudMeal, {
    Meal? existing,
  }) async {
    // Store the photo FILE, not the bare URL, so the vault renders offline.
    // On failure the URL is kept (works online) and the startup backfill in
    // MealImageLocalizer retries on a later launch.
    final localPhoto = await _localizeImage(cloudMeal.imageUrl);
    return MealsCompanion(
      name: drift.Value(cloudMeal.name),
      photoPath: drift.Value(localPhoto),
      shortName: drift.Value(cloudMeal.shortName),
      proteinType: existing != null &&
              MealCloudVocabulary.proteinFoldWouldDowngrade(
                  existing.proteinType, cloudMeal.proteinType)
          ? const drift.Value.absent()
          : drift.Value(cloudProteinType(cloudMeal.proteinType)),
      carbsType: existing != null &&
              MealCloudVocabulary.carbsFoldWouldDowngrade(
                  existing.carbsType, cloudMeal.carbsType)
          ? const drift.Value.absent()
          : drift.Value(cloudCarbsType(cloudMeal.carbsType)),
      category: drift.Value(cloudCategory(cloudMeal.category)),
      prepTime: drift.Value(cloudMeal.prepTimeMinutes),
      isFridaySpecial: drift.Value(cloudMeal.isFridaySpecial),
      cloudId: drift.Value(cloudMeal.id),
      notes: drift.Value(cloudMeal.notes),
    );
  }
}

// The three mappings themselves moved to `MealCloudVocabulary`
// (`../data/cloud_vocabulary.dart`), which now owns the upload direction too —
// the pair used to be maintained separately and they had already drifted once.
// These aliases stay because the meal screen and the sync diff read a cloud row
// through them; they hold no table of their own.
ProteinType cloudProteinType(String p) => MealCloudVocabulary.proteinFromCloud(p);

CarbsType cloudCarbsType(String c) => MealCloudVocabulary.carbsFromCloud(c);

MealCategory cloudCategory(String c) => MealCloudVocabulary.categoryFromCloud(c);

final discoveryControllerProvider = StateNotifierProvider<DiscoveryNotifier, AsyncValue<void>>((ref) {
  final dao = ref.watch(mealsDaoProvider);
  final db = ref.watch(appDatabaseProvider);
  return DiscoveryNotifier(dao, db);
});
