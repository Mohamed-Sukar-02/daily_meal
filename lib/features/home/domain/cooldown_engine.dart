import 'dart:math';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_date_utils.dart' as app_date_utils;

class RecommendationResult<T> {
  final List<T> recommendations;
  final int relaxationLevel;
  final String relaxationReason;
  final DateTime computedDate;

  const RecommendationResult({
    required this.recommendations,
    required this.relaxationLevel,
    required this.relaxationReason,
    required this.computedDate,
  });
}

class CooldownEngine {
  const CooldownEngine();

  RecommendationResult<T> compute<T>({
    required List<T> meals,
    required List<dynamic> history,
    required dynamic settings,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final normalizedToday = app_date_utils.toLocalDay(now);

    if (meals.isEmpty) {
      return RecommendationResult<T>(
        recommendations: const [],
        relaxationLevel: 5,
        relaxationReason: _relaxationReason(5, isEmpty: true),
        computedDate: normalizedToday,
      );
    }

    final adaptedHistory = history.map((h) => _HistoryCandidate.from(h)).toList()
      ..sort((a, b) {
        final dateCmp = b.rawCookedDate.compareTo(a.rawCookedDate);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

    final Map<int, DateTime> lastCookedByMealId = {};
    for (final h in adaptedHistory) {
      final id = h.mealId;
      if (id == null) continue;
      final existing = lastCookedByMealId[id];
      if (existing == null || h.normalizedCookedDate.isAfter(existing)) {
        lastCookedByMealId[id] = h.normalizedCookedDate;
      }
    }

    _HistoryCandidate? lastCooked;
    for (final entry in adaptedHistory) {
      final daysDiff = app_date_utils.daysBetweenLocal(entry.normalizedCookedDate, normalizedToday);
      if (daysDiff >= 0 && daysDiff <= 1) {
        lastCooked = entry;
        break;
      }
    }

    final lastProtein = lastCooked?.proteinName;
    final lastCarbs = lastCooked?.carbsName;

    final adaptedMeals = meals.map((m) => _MealCandidate.from(m)).toList();

    final int configCooldown;
    final int chickenCooldown;
    final int beefCooldown;
    final int fishCooldown;
    final int meatlessCooldown;
    final bool preventProtein;
    final bool preventCarbs;

    if (settings is AppSettingsData) {
      configCooldown = settings.cooldownDays;
      chickenCooldown = settings.chickenCooldownDays;
      beefCooldown = settings.beefCooldownDays;
      fishCooldown = settings.fishCooldownDays;
      meatlessCooldown = settings.meatlessCooldownDays;
      preventProtein = settings.preventRepeatProtein;
      preventCarbs = settings.preventRepeatCarbs;
    } else {
      configCooldown = (settings as dynamic)?.cooldownDays as int? ?? 14;
      chickenCooldown = (settings as dynamic)?.chickenCooldownDays as int? ?? 7;
      beefCooldown = (settings as dynamic)?.beefCooldownDays as int? ?? 10;
      fishCooldown = (settings as dynamic)?.fishCooldownDays as int? ?? 5;
      meatlessCooldown = (settings as dynamic)?.meatlessCooldownDays as int? ?? 0;
      preventProtein = (settings as dynamic)?.preventRepeatProtein as bool? ?? true;
      preventCarbs = (settings as dynamic)?.preventRepeatCarbs as bool? ?? true;
    }

    final targetCount = min(3, meals.length);

    for (int level = 0; level <= 5; level++) {
      final candidates = _filterCandidates(
        meals: adaptedMeals,
        lastCookedByMealId: lastCookedByMealId,
        today: normalizedToday,
        cooldownDays: configCooldown,
        chickenCooldownDays: chickenCooldown,
        beefCooldownDays: beefCooldown,
        fishCooldownDays: fishCooldown,
        meatlessCooldownDays: meatlessCooldown,
        preventProtein: preventProtein,
        preventCarbs: preventCarbs,
        lastProtein: lastProtein,
        lastCarbs: lastCarbs,
        level: level,
      );

      final ranked = _rankAndSelectDiversity(
        candidates: candidates,
        lastCookedByMealId: lastCookedByMealId,
        today: normalizedToday,
        cooldownDays: configCooldown,
        chickenCooldownDays: chickenCooldown,
        beefCooldownDays: beefCooldown,
        fishCooldownDays: fishCooldown,
        meatlessCooldownDays: meatlessCooldown,
      );

      if (ranked.length >= targetCount || level == 5) {
        final selectedRaw = ranked.take(targetCount).map((c) => c.rawMeal as T).toList();
        return RecommendationResult<T>(
          recommendations: selectedRaw,
          relaxationLevel: level,
          relaxationReason: _relaxationReason(level, isEmpty: false),
          computedDate: normalizedToday,
        );
      }
    }

    final fallbackRaw = adaptedMeals.take(targetCount).map((c) => c.rawMeal as T).toList();
    return RecommendationResult<T>(
      recommendations: fallbackRaw,
      relaxationLevel: 5,
      relaxationReason: _relaxationReason(5, isEmpty: false),
      computedDate: normalizedToday,
    );
  }

  List<_MealCandidate> _filterCandidates({
    required List<_MealCandidate> meals,
    required Map<int, DateTime> lastCookedByMealId,
    required DateTime today,
    required int cooldownDays,
    required int chickenCooldownDays,
    required int beefCooldownDays,
    required int fishCooldownDays,
    required int meatlessCooldownDays,
    required bool preventProtein,
    required bool preventCarbs,
    required String? lastProtein,
    required String? lastCarbs,
    required int level,
  }) {
    return meals.where((meal) {
      final int specificCooldown = _resolveSpecificCooldown(
        proteinName: meal.proteinName,
        cooldownDays: cooldownDays,
        chickenCooldownDays: chickenCooldownDays,
        beefCooldownDays: beefCooldownDays,
        fishCooldownDays: fishCooldownDays,
        meatlessCooldownDays: meatlessCooldownDays,
      );

      final DateTime? lastCookedDate = lastCookedByMealId[meal.id];

      if (lastCookedDate != null) {
        final deltaDays = app_date_utils.daysBetweenLocal(lastCookedDate, today);

        if (level == 4) {
          if (deltaDays == 0) return false;
        } else if (level < 5) {
          final effectiveCooldown = _calculateEffectiveCooldown(specificCooldown, level);
          if (deltaDays <= effectiveCooldown) return false;
        }
      }

      if (level == 0 && preventCarbs && lastCarbs != null && lastCarbs != 'none') {
        if (meal.carbsName == lastCarbs) return false;
      }

      if (level <= 2 && preventProtein && lastProtein != null && lastProtein != 'none') {
        if (meal.proteinName == lastProtein) return false;
      }

      return true;
    }).toList();
  }

  int _resolveSpecificCooldown({
    required String proteinName,
    required int cooldownDays,
    required int chickenCooldownDays,
    required int beefCooldownDays,
    required int fishCooldownDays,
    required int meatlessCooldownDays,
  }) {
    int specific;
    switch (proteinName) {
      case 'chicken':
        specific = chickenCooldownDays;
        break;
      case 'beef':
        specific = beefCooldownDays;
        break;
      case 'fish':
        specific = fishCooldownDays;
        break;
      case 'none':
        specific = meatlessCooldownDays;
        break;
      default:
        specific = cooldownDays;
        break;
    }
    if (specific == 0) {
      return cooldownDays;
    }
    return specific;
  }

  int _calculateEffectiveCooldown(int configDays, int level) {
    switch (level) {
      case 0:
      case 1:
        return configDays;
      case 2:
        return min(configDays, max(1, configDays ~/ 2));
      case 3:
        return min(configDays, max(1, configDays ~/ 4));
      case 4:
      case 5:
      default:
        return 1;
    }
  }

  double calculateMealScore({
    required dynamic meal,
    dynamic history = const [],
    required DateTime today,
    required int cooldownDays,
    int chickenCooldownDays = 7,
    int beefCooldownDays = 10,
    int fishCooldownDays = 5,
    int meatlessCooldownDays = 0,
    Map<int, DateTime>? lastCookedByMealId,
  }) {
    final candidate = meal is _MealCandidate ? meal : _MealCandidate.from(meal);
    final normalizedToday = app_date_utils.toLocalDay(today);

    Map<int, DateTime> effectiveMap;
    if (lastCookedByMealId != null) {
      effectiveMap = lastCookedByMealId;
    } else if (history is Map<int, DateTime>) {
      effectiveMap = history;
    } else {
      effectiveMap = {};
      if (history is List) {
        for (final h in history) {
          try {
            final int? hMealId = (h as dynamic).mealId as int?;
            if (hMealId == null) continue;
            DateTime? hDate;
            if (h is _HistoryCandidate) {
              hDate = h.normalizedCookedDate;
            } else {
              final dynamic raw = (h as dynamic).cookedAt;
              if (raw is DateTime) hDate = app_date_utils.toLocalDay(raw);
            }
            if (hDate != null) {
              final existing = effectiveMap[hMealId];
              if (existing == null || hDate.isAfter(existing)) effectiveMap[hMealId] = hDate;
            }
          } catch (_) {}
        }
      }
    }

    final DateTime? lastCookedDate = effectiveMap[candidate.id];

    final int specificCooldown = _resolveSpecificCooldown(
      proteinName: candidate.proteinName,
      cooldownDays: cooldownDays,
      chickenCooldownDays: chickenCooldownDays,
      beefCooldownDays: beefCooldownDays,
      fishCooldownDays: fishCooldownDays,
      meatlessCooldownDays: meatlessCooldownDays,
    );

    double sRecency;
    if (lastCookedDate == null) {
      sRecency = 25.0;
    } else {
      final deltaDays = app_date_utils.daysBetweenLocal(lastCookedDate, normalizedToday);
      sRecency = min(20.0, (deltaDays - specificCooldown) / 2.0);
    }

    double sFriday = 0.0;
    final isFriday = normalizedToday.weekday == DateTime.friday;
    if (isFriday) {
      sFriday = candidate.isFridaySpecial ? 15.0 : 0.0;
    } else {
      sFriday = candidate.isFridaySpecial ? -5.0 : 0.0;
    }

    final sFavorite = candidate.isFavorite ? 5.0 : 0.0;
    final sBudget = candidate.isBudgetFriendly ? 2.0 : 0.0;

    final jitter = ((app_date_utils.daysSinceEpoch(normalizedToday) * 17 + candidate.id * 31) % 100) / 25.0;

    return sRecency + sFriday + sFavorite + sBudget + jitter;
  }

  List<_MealCandidate> _rankAndSelectDiversity({
    required List<_MealCandidate> candidates,
    required Map<int, DateTime> lastCookedByMealId,
    required DateTime today,
    required int cooldownDays,
    int chickenCooldownDays = 7,
    int beefCooldownDays = 10,
    int fishCooldownDays = 5,
    int meatlessCooldownDays = 0,
  }) {
    if (candidates.isEmpty) return const [];

    final scored = candidates.map((m) {
      return MapEntry(
        m,
        calculateMealScore(
          meal: m,
          lastCookedByMealId: lastCookedByMealId,
          today: today,
          cooldownDays: cooldownDays,
          chickenCooldownDays: chickenCooldownDays,
          beefCooldownDays: beefCooldownDays,
          fishCooldownDays: fishCooldownDays,
          meatlessCooldownDays: meatlessCooldownDays,
        ),
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = <_MealCandidate>[];
    final remaining = scored.map((e) => e.key).toList();

    selected.add(remaining.removeAt(0));

    if (remaining.isNotEmpty) {
      final card2Index = remaining.indexWhere((m) => m.proteinName != selected[0].proteinName);
      if (card2Index != -1) {
        selected.add(remaining.removeAt(card2Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    if (remaining.isNotEmpty) {
      final existingProteins = selected.map((m) => m.proteinName).toSet();
      var card3Index = remaining.indexWhere((m) => !existingProteins.contains(m.proteinName));

      if (card3Index == -1) {
        final existingCarbs = selected.map((m) => m.carbsName).toSet();
        card3Index = remaining.indexWhere((m) => !existingCarbs.contains(m.carbsName));
      }

      if (card3Index != -1) {
        selected.add(remaining.removeAt(card3Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    return selected;
  }

  static String _relaxationReason(int level, {bool isEmpty = false}) {
    if (isEmpty) {
      return 'قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات.';
    }
    switch (level) {
      case 0:
        return 'اقتراحات مثالية مطابقة لجميع شروط التنوع الغذائي وفترة الاستبعاد.';
      case 1:
        return 'تم السماح بتكرار صنف النشويات لتوفير اقتراحات كافية.';
      case 2:
        return 'تم تقليص فترة الاستبعاد إلى النصف لتوفير اقتراحات كافية.';
      case 3:
        return 'تم تخفيف شرط البروتين وفترة الاستبعاد لتوفير اقتراحات متنوعة.';
      case 4:
        return 'وضع الطوارئ: استبعاد وجبات اليوم فقط لتوفير اقتراحات.';
      case 5:
      default:
        return 'تم عرض جميع الوجبات المتاحة لعدم توفر خيارات أخرى.';
    }
  }
}

class _MealCandidate {
  final dynamic rawMeal;
  final int id;
  final String name;
  final String proteinName;
  final String carbsName;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isFavorite;

  _MealCandidate.from(this.rawMeal)
      : id = (rawMeal as dynamic).id as int,
        name = (rawMeal as dynamic).name as String,
        proteinName = _extractEnumName((rawMeal as dynamic).proteinType),
        carbsName = _extractEnumName((rawMeal as dynamic).carbsType),
        isFridaySpecial = (rawMeal as dynamic).isFridaySpecial as bool,
        isBudgetFriendly = (rawMeal as dynamic).isBudgetFriendly as bool,
        isFavorite = (rawMeal as dynamic).isFavorite as bool;

  static String _extractEnumName(dynamic val) {
    if (val == null) return 'none';
    if (val is Enum) return val.name;
    final str = val.toString();
    return str.contains('.') ? str.split('.').last : str;
  }
}

class _HistoryCandidate {
  final dynamic rawHistory;
  final int? mealId;
  final DateTime rawCookedDate;
  final DateTime normalizedCookedDate;
  final DateTime createdAt;
  final String proteinName;
  final String carbsName;

  _HistoryCandidate.from(this.rawHistory)
      : mealId = (rawHistory as dynamic).mealId as int?,
        rawCookedDate = _extractRawDate(rawHistory),
        normalizedCookedDate = _normalizeDate(_extractRawDate(rawHistory)),
        createdAt = (rawHistory as dynamic).createdAt is DateTime
            ? (rawHistory as dynamic).createdAt as DateTime
            : DateTime.now(),
        proteinName = _MealCandidate._extractEnumName((rawHistory as dynamic).proteinType),
        carbsName = _MealCandidate._extractEnumName((rawHistory as dynamic).carbsType);

  static DateTime _extractRawDate(dynamic raw) {
    try {
      final dynamic d = (raw as dynamic).cookedAt;
      if (d is DateTime) return d;
    } catch (_) {}
    return DateTime.now();
  }

  static DateTime _normalizeDate(DateTime dt) => app_date_utils.toLocalDay(dt);
}
