import 'package:flutter/material.dart' show Locale;

import '../localization/app_strings.dart';

/// Central date helper - single source of truth for day boundaries [1][D]
/// Handles DST correctly via calendar fields, not difference().inDays on local DateTime

/// Returns local calendar day at midnight (no time component)
DateTime getLocalToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Converts any DateTime (UTC or local) to local calendar day at midnight
DateTime toLocalDay(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  return DateTime(local.year, local.month, local.day);
}

/// DST-safe day number from calendar fields [D]
/// Egypt has DST since 2023, difference().inDays on local DateTime gives 23/25h days wrong
int _dayNumber(DateTime d) {
  final l = d.isUtc ? d.toLocal() : d;
  return DateTime.utc(l.year, l.month, l.day)
      .difference(DateTime.utc(1970, 1, 1))
      .inDays;
}

/// Continuous days since epoch for deterministic jitter [1][D]
int daysSinceEpoch(DateTime dt) => _dayNumber(dt);

/// DST-safe days between two dates via calendar fields [D]
int daysBetweenLocal(DateTime from, DateTime to) {
  return _dayNumber(to) - _dayNumber(from);
}

/// Checks if two DateTimes are same local calendar day
bool isSameLocalDay(DateTime a, DateTime b) {
  final la = a.isUtc ? a.toLocal() : a;
  final lb = b.isUtc ? b.toLocal() : b;
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Formats history date as Today/Yesterday or dd/MM/yyyy
/// Handles UTC stored dates by converting to local first.
///
/// The relative labels come from [AppStrings] so they follow the app language;
/// callers that have no locale handy get Arabic (the app default).
String formatHistoryDate(
  DateTime dt, {
  DateTime? referenceToday,
  AppStrings strings = const AppStrings(Locale('ar')),
}) {
  final today = referenceToday != null ? toLocalDay(referenceToday) : getLocalToday();
  final localDay = toLocalDay(dt);

  if (isSameLocalDay(localDay, today)) {
    return strings.today;
  }

  final yesterday = today.subtract(const Duration(days: 1));
  if (isSameLocalDay(localDay, yesterday)) {
    return strings.yesterday;
  }

  // Format as dd/MM/yyyy in local calendar
  final l = dt.isUtc ? dt.toLocal() : dt;
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}
