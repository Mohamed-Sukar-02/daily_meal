import 'package:drift/drift.dart';
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

  Stream<List<Meal>> watchFilterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).watch();
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

  Future<List<Meal>> filterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).get();
  }

  Future<int> insertMeal(MealsCompanion meal) {
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
    final normalizedCompanion = _withNormalizedName(meal);
    return into(meals).insert(normalizedCompanion);
  }

  Future<void> insertMealsBatch(List<MealsCompanion> mealCompanions) {
    final normalized = mealCompanions.map(_withNormalizedName).toList();
    return batch((b) {
      b.insertAll(meals, normalized);
    });
  }

  Future<bool> updateMeal(Meal meal) {
    final normalized = normalizeArabic(meal.name);
    return update(meals).replace(meal.copyWith(
      updatedAt: DateTime.now(),
      nameNormalized: Value(normalized),
    ));
  }

  Future<int> updateMealCompanion(int id, MealsCompanion companion) {
    final normalizedCompanion = _withNormalizedName(companion);
    return (update(meals)..where((t) => t.id.equals(id)))
        .write(normalizedCompanion.copyWith(updatedAt: Value(DateTime.now())));
  }

  MealsCompanion _withNormalizedName(MealsCompanion c) {
    if (c.name.present) {
      final normalized = normalizeArabic(c.name.value);
      return c.copyWith(nameNormalized: Value(normalized));
    }
    return c;
  }

  Future<int> deleteMeal(int id) {
    return (delete(meals)..where((t) => t.id.equals(id))).go();
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

  SimpleSelectStatement<$MealsTable, Meal> _buildFilteredQuery({
    String? query,
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    final statement = select(meals);
    statement.where((t) {
      final predicates = <Expression<bool>>[];
      if (query != null && query.trim().isNotEmpty) {
        final normalized = normalizeArabic(query.trim());
        final escaped = escapeLikePattern(normalized);
        final pattern = '%$escaped%';
        predicates.add(coalesce<String>([t.nameNormalized, t.name]).like(pattern, escapeChar: '\\'));
      }
      if (proteinType != null) {
        predicates.add(t.proteinType.equalsValue(proteinType));
      }
      if (carbsType != null) {
        predicates.add(t.carbsType.equalsValue(carbsType));
      }
      if (category != null) {
        predicates.add(t.category.equalsValue(category));
      }
      if (isFridaySpecial != null) {
        predicates.add(t.isFridaySpecial.equals(isFridaySpecial));
      }
      if (isBudgetFriendly != null) {
        predicates.add(t.isBudgetFriendly.equals(isBudgetFriendly));
      }
      if (isFavorite != null) {
        predicates.add(t.isFavorite.equals(isFavorite));
      }
      if (maxPrepTimeMinutes != null) {
        predicates.add(t.prepTime.isSmallerOrEqualValue(maxPrepTimeMinutes));
      }

      if (predicates.isEmpty) return const Constant(true);
      return Expression.and(predicates);
    });

    statement.orderBy([
      (t) => OrderingTerm.asc(t.name),
      (t) => OrderingTerm.desc(t.id),
    ]);
    return statement;
  }
}
