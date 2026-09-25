import 'package:drift/drift.dart';
import '../app_database.dart';

part 'meal_history_dao.g.dart';

class MealHistoryWithMeal {
  final MealHistoryData history;
  final Meal? meal;

  MealHistoryWithMeal({required this.history, this.meal});
}

@DriftAccessor(tables: [MealHistory, Meals])
class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
  MealHistoryDao(super.db);

  /// Reactive stream of history entries ordered descending by cookedAt
  Stream<List<MealHistoryData>> watchHistory({int? limit}) {
    final query = select(mealHistory)
      ..orderBy([
        (t) => OrderingTerm.desc(t.cookedAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null && limit > 0) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Reactive stream joining history with meals (meal may be null if deleted)
  Stream<List<MealHistoryWithMeal>> watchHistoryWithMeal() {
    final query = select(mealHistory).join([
      leftOuterJoin(meals, meals.id.equalsExp(mealHistory.mealId)),
    ])..orderBy([
      OrderingTerm.desc(mealHistory.cookedAt),
      OrderingTerm.desc(mealHistory.id),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return MealHistoryWithMeal(
          history: row.readTable(mealHistory),
          meal: row.readTableOrNull(meals),
        );
      }).toList();
    });
  }

  /// Reactive stream for latest cooked meal
  Stream<MealHistoryData?> watchLatestCookedMeal() {
    return (select(mealHistory)
          ..orderBy([
            (t) => OrderingTerm.desc(t.cookedAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Snapshot of all history entries
  Future<List<MealHistoryData>> getAllHistory() {
    return (select(mealHistory)
          ..orderBy([
            (t) => OrderingTerm.desc(t.cookedAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  /// Fetch recent history entries up to [limit]
  Future<List<MealHistoryData>> getRecentHistory({int limit = 60}) {
    return (select(mealHistory)
      ..orderBy([
        (t) => OrderingTerm.desc(t.cookedAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit)).get();
  }

  /// Fetch history within the last [days] days
  Future<List<MealHistoryData>> getHistoryWithinDays(
    int days, {
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final cutoff = ref.subtract(Duration(days: days));
    return (select(mealHistory)
      ..where((t) => t.cookedAt.isBiggerOrEqualValue(cutoff))
      ..orderBy([
        (t) => OrderingTerm.desc(t.cookedAt),
        (t) => OrderingTerm.desc(t.id),
      ])).get();
  }

  /// Fetch the latest single cooked meal entry
  Future<MealHistoryData?> getLatestCookedMeal({DateTime? beforeDate}) {
    final query = select(mealHistory);
    if (beforeDate != null) {
      query.where((t) => t.cookedAt.isSmallerOrEqualValue(beforeDate));
    }
    query
      ..orderBy([
        (t) => OrderingTerm.desc(t.cookedAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Log a cooked meal with full snapshot fields
  Future<int> logMeal({
    int? mealId,
    required String mealName,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required DateTime cookedAt,
    MealEntryType entryType = MealEntryType.cooked,
    String? notes,
  }) {
    return into(mealHistory).insert(
      MealHistoryCompanion(
        mealId: Value(mealId),
        mealName: Value(mealName),
        proteinType: Value(proteinType),
        carbsType: Value(carbsType),
        cookedAt: Value(cookedAt),
        entryType: Value(entryType),
        notes: Value(notes),
      ),
    );
  }

  /// Convenience helper to log directly from a Meal instance
  Future<int> logMealFromMeal(
    Meal meal, {
    DateTime? cookedAt,
    MealEntryType entryType = MealEntryType.cooked,
    String? notes,
  }) {
    return logMeal(
      mealId: meal.id,
      mealName: meal.name,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: entryType,
      notes: notes,
    );
  }

  /// Quick helper to log cooked meal
  Future<int> logCookedMeal(Meal meal, {DateTime? cookedAt, String? notes}) {
    return logMealFromMeal(meal, cookedAt: cookedAt, entryType: MealEntryType.cooked, notes: notes);
  }

  /// Quick helper to log leftover meal
  Future<int> logLeftoverMeal(Meal meal, {DateTime? cookedAt, String? notes}) {
    return logMealFromMeal(meal, cookedAt: cookedAt, entryType: MealEntryType.leftover, notes: notes);
  }

  Future<int> logTakeoutMeal({DateTime? cookedAt, String? notes}) {
    return logMeal(
      // Language-neutral key, not display copy — resolved via
      // AppStrings.historyEntryDisplayName so switching language localizes it.
      mealName: 'takeout',
      proteinType: ProteinType.none,
      carbsType: CarbsType.none,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: MealEntryType.takeout,
      notes: notes,
    );
  }

  Future<int> logSkippedMeal({DateTime? cookedAt, String? notes}) {
    return logMeal(
      mealName: 'skipped',
      proteinType: ProteinType.none,
      carbsType: CarbsType.none,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: MealEntryType.skipped,
      notes: notes,
    );
  }

  /// Delete a single history log entry
  Future<int> deleteHistoryEntry(int id) {
    return (delete(mealHistory)..where((t) => t.id.equals(id))).go();
  }

  /// Delete history for a specific meal
  Future<int> deleteHistoryForMeal(int mealId) {
    return (delete(mealHistory)..where((t) => t.mealId.equals(mealId))).go();
  }

  /// Clear all history logs
  Future<int> clearAllHistory() {
    return delete(mealHistory).go();
  }
}
