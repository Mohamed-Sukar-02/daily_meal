import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_date_utils.dart' as app_date_utils;
import 'recommendation_provider.dart';

/// Today's *plan*: a meal the user picked for today, without claiming it was
/// cooked.
///
/// The app had exactly one state between "haven't thought about it" and "it is
/// in the log", and the log is where the consequences live: a cooked row starts a
/// cooldown, moves the month's stats, and is a statement that the dish was made.
/// Choosing a meal is not that statement — it is the thing a person does at 10am
/// for dinner at 8pm. So the choice gets its own store.
///
/// It lives in SharedPreferences on purpose. A Drift column would be the tidier
/// home for a value the day is keyed by, but it means a schema change, a
/// migration, and the cloud vocabulary question all over again for a piece of
/// state whose entire job is to be forgettable: nothing else may depend on it.
/// If the process dies with a plan set, the worst case is a banner that says
/// "you meant to cook this", which is exactly what it is for.
///
/// Two keys, one of which is the day, because prefs have no expiry:
/// "what I decided yesterday" must not become today's banner. Reading compares
/// the stored day against today's local day and answers `null` if they differ —
/// no clean-up pass, no timer, no stale state to inherit at midnight.
class PlannedMeal {
  PlannedMeal._();

  static const String _idKey = 'planned_meal_id';
  static const String _dayKey = 'planned_meal_day';

  /// The meal chosen for [now]'s day, or `null` when that day has no plan —
  /// including the case where a plan exists but belongs to another day.
  ///
  /// [now] is a seam for the tests, which must be able to put a plan on
  /// October 2nd and ask about October 3rd without waiting for midnight.
  static Future<int?> current({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = prefs.getInt(_dayKey);
      if (day == null) return null;
      if (day != _dayKeyFor(now ?? DateTime.now())) return null;
      return prefs.getInt(_idKey);
    } catch (_) {
      // A plan is a convenience. A prefs read that fails must not take the
      // home screen down with it.
      return null;
    }
  }

  static Future<void> plan(int mealId, {DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_idKey, mealId);
      await prefs.setInt(_dayKey, _dayKeyFor(now ?? DateTime.now()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_idKey);
      await prefs.remove(_dayKey);
    } catch (_) {}
  }

  /// Clear the plan only if it is still [mealId].
  ///
  /// This is what an undo from a toast needs: the toast outlives the moment it
  /// described, and by the time it is tapped the user may have planned something
  /// else. A undo that silently withdraws a newer decision is worse than a tap
  /// that does nothing.
  static Future<void> clearIfMatches(int mealId, {DateTime? now}) async {
    if (await current(now: now) == mealId) await clear();
  }

  /// Local midnight, as an int, because that is the unit the plan is keyed by:
  /// the same function the cooldown windows and the day ticker use, so "today"
  /// means the same thing here as it does everywhere else in the app.
  static int _dayKeyFor(DateTime day) =>
      app_date_utils.toLocalDay(day).millisecondsSinceEpoch;
}

/// The meal planned for today, or `null`.
///
/// Watched rather than read, because the banner it drives has to disappear the
/// moment the day turns: `currentTimeProvider` fires at midnight rollover, which
/// is when yesterday's plan stops being anybody's business.
final plannedMealIdProvider = FutureProvider<int?>((ref) {
  ref.watch(currentTimeProvider);
  return PlannedMeal.current();
});

/// Whether today still has a question to ask — which is the whole condition
/// behind suppressing the daily reminder.
///
/// Two answers count. A log row says the day was settled (in either direction:
/// cooked, or "not cooking — takeout"). A *plan* counts too, and that is the
/// deliberate product call behind this feature: the reminder exists to make the
/// user pick, and once they have picked, repeating the question for the rest of
/// the day is noise even though nothing has been cooked yet.
///
/// A plan pointing at a deleted meal does not count: it is not an answer, it is
/// a leftover pointer, and Home hides the banner for it. Checking the row exists
/// is cheaper than it looks (`getMealById` is a primary-key lookup) and it keeps
/// the two readers of the plan agreeing on what a stale one is worth.
Future<bool> isTodayAlreadyAnswered(AppDatabase db) async {
  try {
    if (await db.mealHistoryDao.hasAnyEntryToday()) return true;
    final plannedId = await PlannedMeal.current();
    if (plannedId == null) return false;
    return await db.mealsDao.getMealById(plannedId) != null;
  } catch (_) {
    // Fail towards the reminder, not away from it: a nag that should have been
    // quiet is a nuisance, a silence that should have been a nag loses the one
    // nudge this feature exists to provide.
    return false;
  }
}

/// Retire today's plan because the day has been answered by a real log row.
///
/// A cooked/leftover/takeout/skipped entry says more than a plan does — it says
/// it happened — so the intention must not sit there afterwards claiming the
/// opposite ("nothing landed in the log", which is now false). Undoing the log
/// does **not** bring the plan back: the tap that restores a row restores the
/// log, and re-choosing a dish is one tap on the card.
///
/// Lives here rather than in [PlannedMeal] so that the invalidation of
/// [plannedMealIdProvider] cannot be forgotten by a caller, and the plan store
/// stays free of Riverpod.
Future<void> retireTodayPlan(Ref ref) async {
  await PlannedMeal.clear();
  ref.invalidate(plannedMealIdProvider);
}
