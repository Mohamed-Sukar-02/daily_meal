import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_database.dart';
import '../../utils/arabic_normalizer.dart';

part 'meals_dao.g.dart';

@DriftAccessor(tables: [Meals])
class MealsDao extends DatabaseAccessor<AppDatabase> with _$MealsDaoMixin {
  MealsDao(super.db);

  Stream<List<Meal>> watchAllMeals() {
    return (select(meals)
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Stream<Meal?> watchMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<Meal>> watchFavorites() {
    return (select(meals)
          ..where((t) => t.isFavorite.equals(true))
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Stream<List<Meal>> watchSearchMeals(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return watchAllMeals();

    final normalized = normalizeArabic(clean);
    final escaped = escapeLikePattern(normalized);
    final pattern = '%$escaped%';

    return (select(meals)
          ..where((t) => coalesce<String>([t.nameNormalized, t.name]).like(pattern, escapeChar: '\\'))
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Future<List<Meal>> getAllMeals() {
    return (select(meals)
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  Future<Meal?> getMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Meal?> getMealByName(String name) {
    final normalized = normalizeArabic(name);
    return (select(meals)
          ..where((t) => t.nameNormalized.equals(normalized))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Meal?> getMealByCloudId(String cloudId) {
    return (select(meals)
          ..where((t) => t.cloudId.equals(cloudId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<Meal>> getStarterMeals() {
    return (select(meals)..where((t) => t.isStarterMeal.equals(true))).get();
  }

  Future<List<Meal>> searchMeals(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return getAllMeals();

    final normalized = normalizeArabic(clean);
    final escaped = escapeLikePattern(normalized);
    final pattern = '%$escaped%';

    return (select(meals)
          ..where((t) => coalesce<String>([t.nameNormalized, t.name]).like(pattern, escapeChar: '\\'))
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  Future<int> insertMeal(MealsCompanion meal) async {
    if (meal.name.present) {
      if (meal.name.value.trim().isEmpty) {
        throw ArgumentError('Meal name cannot be empty or whitespace');
      }
    }
    if (meal.prepTime.present) {
      if (meal.prepTime.value <= 0) {
        throw ArgumentError('Prep time must be a positive integer');
      }
    }
    
    // If inserting a meal that was previously blacklisted, remove it from blacklist
    if (meal.cloudId.present && meal.cloudId.value != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final deletedList = prefs.getStringList('deleted_starter_meals') ?? [];
        if (deletedList.contains(meal.cloudId.value!)) {
          deletedList.remove(meal.cloudId.value!);
          await prefs.setStringList('deleted_starter_meals', deletedList);
        }
      } catch (_) {}
    }

    // Upsert / deduplication guard:
    // 1. Check if a meal already exists by cloudId
    Meal? existing;
    if (meal.cloudId.present && meal.cloudId.value != null && meal.cloudId.value!.isNotEmpty) {
      existing = await getMealByCloudId(meal.cloudId.value!);
    }
    // 2. Check if a meal already exists by normalized name
    if (existing == null && meal.name.present) {
      existing = await getMealByName(meal.name.value);
    }

    if (existing != null) {
      var updateCompanion = meal;
      // Preserve existing photo if the update doesn't provide one
      if (existing.photoPath != null &&
          (!meal.photoPath.present || meal.photoPath.value == null)) {
        updateCompanion = updateCompanion.copyWith(
          photoPath: Value(existing.photoPath),
        );
      }
      // Preserve favorite status if already favorited
      if (existing.isFavorite &&
          (!meal.isFavorite.present || !meal.isFavorite.value)) {
        updateCompanion = updateCompanion.copyWith(
          isFavorite: const Value(true),
        );
      }
      // Preserve existing cloudId if the new companion doesn't have one
      if (existing.cloudId != null &&
          (!meal.cloudId.present || meal.cloudId.value == null)) {
        updateCompanion = updateCompanion.copyWith(
          cloudId: Value(existing.cloudId),
        );
      }
      // Preserve customCooldownDays if already set
      if (existing.customCooldownDays != null &&
          (!meal.customCooldownDays.present || meal.customCooldownDays.value == null)) {
        updateCompanion = updateCompanion.copyWith(
          customCooldownDays: Value(existing.customCooldownDays),
        );
      }
      // Preserve notes if already set
      if (existing.notes != null && existing.notes!.isNotEmpty &&
          (!meal.notes.present || meal.notes.value == null)) {
        updateCompanion = updateCompanion.copyWith(
          notes: Value(existing.notes),
        );
      }

      await updateMealCompanion(existing.id, updateCompanion, touchUpdatedAt: false);
      return existing.id;
    }
    
    final normalizedCompanion = _withNormalizedName(meal);
    return into(meals).insert(normalizedCompanion);
  }

  Future<void> insertMealsBatch(List<MealsCompanion> mealCompanions) async {
    for (final companion in mealCompanions) {
      await insertMeal(companion);
    }
  }

  Future<bool> updateMeal(Meal meal) {
    final normalized = normalizeArabic(meal.name);
    return update(meals).replace(meal.copyWith(
      updatedAt: DateTime.now(),
      nameNormalized: Value(normalized),
    ));
  }

  /// [touchUpdatedAt]: pass `false` for background, non-user writes (e.g. starter-meal
  /// cloud sync). `updatedAt` is the "user edited this meal" signal for the proposal
  /// duplicate ledger (ProposalGuard.alreadyProposed), so an unattended sync pass
  /// must not falsify it and re-open re-proposal of meals the user never touched.
  Future<int> updateMealCompanion(
    int id,
    MealsCompanion companion, {
    bool touchUpdatedAt = true,
  }) {
    final normalizedCompanion = _withNormalizedName(companion);
    return (update(meals)..where((t) => t.id.equals(id))).write(
      touchUpdatedAt
          ? normalizedCompanion.copyWith(updatedAt: Value(DateTime.now()))
          : normalizedCompanion,
    );
  }

  MealsCompanion _withNormalizedName(MealsCompanion c) {
    if (c.name.present) {
      final normalized = normalizeArabic(c.name.value);
      return c.copyWith(nameNormalized: Value(normalized));
    }
    return c;
  }

  Future<int> deleteMeal(int id) async {
    final meal = await getMealById(id);
    if (meal != null && meal.cloudId != null && meal.isStarterMeal) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final deletedList = prefs.getStringList('deleted_starter_meals') ?? [];
        if (!deletedList.contains(meal.cloudId!)) {
          deletedList.add(meal.cloudId!);
          await prefs.setStringList('deleted_starter_meals', deletedList);
        }
      } catch (_) {}
    }
    final deleted = await (delete(meals)..where((t) => t.id.equals(id))).go();
    // Only once the row is really gone: while it exists the photo is a
    // referenced file, and deleting the bytes first would leave a meal whose
    // hero is a broken frame.
    if (deleted > 0) {
      await _deletePhotoFile(meal);
    }
    return deleted;
  }

  /// Frees the disk space of a deleted meal by removing its photo file.
  ///
  /// `Meals.photoPath` carries three kinds of values (see `MealImageSource`),
  /// and only a device file belongs to us: an `http(s)` URL lives on somebody
  /// else's server, and an `assets/…` path is a photo bundled with the app —
  /// deleting either would destroy something this row never owned.
  ///
  /// Cloud photos are content-addressed (`img_<hash>`), so two vault entries
  /// downloaded from the same URL share one file. The row is deleted before
  /// this runs, so the surviving query asks exactly the right question: is
  /// another meal still looking at this file?
  ///
  /// Best-effort by design. A missing or unreadable file is not worth a crash,
  /// and anything left behind is what the startup orphan sweep collects.
  Future<void> _deletePhotoFile(Meal? meal) async {
    final path = meal?.photoPath?.trim() ?? '';
    if (path.isEmpty) return;
    final lower = path.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('assets/') ||
        lower.startsWith('asset:')) {
      return;
    }
    try {
      final stillReferenced = await (select(meals)
            ..where((t) => t.photoPath.equals(path))
            ..limit(1))
          .getSingleOrNull();
      if (stillReferenced != null) return;
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> deduplicateMeals() async {
    final allMeals = await getAllMeals();
    final nameToMeals = <String, List<Meal>>{};
    
    for (final m in allMeals) {
      final norm = m.nameNormalized ?? normalizeArabic(m.name);
      nameToMeals.putIfAbsent(norm, () => []).add(m);
    }
    
    for (final entry in nameToMeals.entries) {
      final duplicates = entry.value;
      if (duplicates.length <= 1) continue;
      
      duplicates.sort((a, b) {
        if ((a.cloudId != null) != (b.cloudId != null)) {
          return a.cloudId != null ? -1 : 1;
        }
        if (a.isStarterMeal != b.isStarterMeal) {
          return a.isStarterMeal ? -1 : 1;
        }
        if (a.isFavorite != b.isFavorite) {
          return a.isFavorite ? -1 : 1;
        }
        return b.id.compareTo(a.id);
      });
      
      final survivor = duplicates.first;
      final victims = duplicates.skip(1).toList();
      
      await transaction(() async {
        final anyFavorite = duplicates.any((d) => d.isFavorite);
        if (anyFavorite && !survivor.isFavorite) {
          await (update(meals)..where((t) => t.id.equals(survivor.id))).write(
            const MealsCompanion(isFavorite: Value(true)),
          );
        }
        if (survivor.photoPath == null || survivor.photoPath!.isEmpty) {
          final victimWithPhoto = victims.firstWhere(
            (v) => v.photoPath != null && v.photoPath!.isNotEmpty,
            orElse: () => survivor,
          );
          if (victimWithPhoto != survivor) {
            await (update(meals)..where((t) => t.id.equals(survivor.id))).write(
              MealsCompanion(photoPath: Value(victimWithPhoto.photoPath)),
            );
          }
        }
        for (final victim in victims) {
          await customStatement('UPDATE meal_history SET meal_id = ? WHERE meal_id = ?', [survivor.id, victim.id]);
          await (delete(meals)..where((t) => t.id.equals(victim.id))).go();
          await _deletePhotoFile(victim);
        }
      });
    }

    // Secondary pass: deduplicate by cloudId if two rows share the same non-null cloudId
    final cloudIdToMeals = <String, List<Meal>>{};
    final currentMeals = await getAllMeals();
    for (final m in currentMeals) {
      if (m.cloudId != null && m.cloudId!.isNotEmpty) {
        cloudIdToMeals.putIfAbsent(m.cloudId!, () => []).add(m);
      }
    }
    for (final entry in cloudIdToMeals.entries) {
      final duplicates = entry.value;
      if (duplicates.length <= 1) continue;

      duplicates.sort((a, b) {
        if (a.isStarterMeal != b.isStarterMeal) return a.isStarterMeal ? -1 : 1;
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return b.id.compareTo(a.id);
      });

      final survivor = duplicates.first;
      final victims = duplicates.skip(1).toList();

      await transaction(() async {
        final anyFavorite = duplicates.any((d) => d.isFavorite);
        if (anyFavorite && !survivor.isFavorite) {
          await (update(meals)..where((t) => t.id.equals(survivor.id))).write(
            const MealsCompanion(isFavorite: Value(true)),
          );
        }
        for (final victim in victims) {
          await customStatement('UPDATE meal_history SET meal_id = ? WHERE meal_id = ?', [survivor.id, victim.id]);
          await (delete(meals)..where((t) => t.id.equals(victim.id))).go();
          await _deletePhotoFile(victim);
        }
      });
    }
  }

  Future<int> deleteAllMeals() {
    return delete(meals).go();
  }

  Future<void> toggleFavorite(int id, [bool? currentStatus]) async {
    bool newStatus;
    if (currentStatus != null) {
      newStatus = !currentStatus;
    } else {
      final meal = await getMealById(id);
      if (meal == null) return;
      newStatus = !meal.isFavorite;
    }

    await (update(meals)..where((t) => t.id.equals(id))).write(
      MealsCompanion(
        isFavorite: Value(newStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
