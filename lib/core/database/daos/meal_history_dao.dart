import 'package:drift/drift.dart';
import '../../utils/app_date_utils.dart' as app_date_utils;
import '../app_database.dart';
import '../meal_log_keys.dart';

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

  /// Whether the log holds anything at all.
  ///
  /// Separate from [getAllHistory] because the callers ask a yes/no question,
  /// and materialising every entry to answer it is the expensive way round.
  Future<bool> hasAnyHistory() async {
    final one = await (select(mealHistory)..limit(1)).getSingleOrNull();
    return one != null;
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

  /// The most recent cooked meal that can honestly be called *leftovers*.
  ///
  /// Two bounds, and both are the point of the method:
  ///  * [withinDays] — a reheat claim is about the recent past. The query this
  ///    replaces asked for the latest cooked row with no window at all, so a
  ///    meal cooked three weeks ago was offered as "yesterday's leftovers", and
  ///    logging it today blocked that meal again for a whole new cooldown window.
  ///  * strictly before [referenceDate]'s own local day — lunch cooked this
  ///    morning is not tonight's leftovers.
  ///
  /// Leftovers are deliberately NOT screened against the cooldown windows: the
  /// whole idea of the entry is eating something the log already holds.
  Future<MealHistoryData?> getRecentLeftoverSource({
    int withinDays = 1,
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final today = app_date_utils.toLocalDay(ref);
    final cutoff = today.subtract(Duration(days: withinDays));
    return (select(mealHistory)
          ..where((t) => t.entryType.equalsValue(MealEntryType.cooked))
          ..where((t) => t.cookedAt.isBiggerOrEqualValue(cutoff))
          ..where((t) => t.cookedAt.isSmallerValue(today))
          ..orderBy([
            (t) => OrderingTerm.desc(t.cookedAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .getSingleOrNull();
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
      mealName: MealLogKeys.takeout,
      proteinType: ProteinType.none,
      carbsType: CarbsType.none,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: MealEntryType.takeout,
      notes: notes,
    );
  }

  Future<int> logSkippedMeal({DateTime? cookedAt, String? notes}) {
    return logMeal(
      mealName: MealLogKeys.skipped,
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
