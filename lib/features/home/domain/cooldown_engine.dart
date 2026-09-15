import 'dart:math';

import '../../../core/database/app_database.dart';

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

  /// Full recommendation engine pipeline returning metadata (relaxationLevel, relaxationReason).
  /// Generic over [T] to support both Drift database entities and generic/contract models.
  /// Optimal: uses typed settings when possible, falls back to dynamic for tests.
  /// Implements per-protein cooldowns (chicken/beef/fish/meatless) that were previously dead UI.
  RecommendationResult<T> compute<T>({
    required List<T> meals,
    required List<dynamic> history,
    required dynamic settings,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);

    if (meals.isEmpty) {
      return RecommendationResult<T>(
        recommendations: const [],
        relaxationLevel: 5,
        relaxationReason: _relaxationReason(5, isEmpty: true),
        computedDate: normalizedToday,
      );
    }

    // 1. Adapt and sort history descending (primary: rawCookedDate, secondary: createdAt)
    // Optimal: O(n log n) once, then O(n) map for last cooked per meal
    final adaptedHistory = history.map((h) => _HistoryCandidate.from(h)).toList()
      ..sort((a, b) {
        final dateCmp = b.rawCookedDate.compareTo(a.rawCookedDate);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

    // Precompute mealId -> lastCookedDate map for O(1) lookup (optimal)
    final Map<int, DateTime> lastCookedByMealId = {};
    for (final h in adaptedHistory) {
      final id = h.mealId;
      if (id == null) continue;
      final existing = lastCookedByMealId[id];
      if (existing == null || h.normalizedCookedDate.isAfter(existing)) {
        lastCookedByMealId[id] = h.normalizedCookedDate;
      }
    }

    // 2. Identify latest cooked meal context (within <= 1 calendar day)
    _HistoryCandidate? lastCooked;
    for (final entry in adaptedHistory) {
      final daysDiff = _daysBetween(entry.normalizedCookedDate, normalizedToday);
      if (daysDiff >= 0 && daysDiff <= 1) {
        lastCooked = entry;
        break;
      }
    }

    final lastProtein = lastCooked?.proteinName;
    final lastCarbs = lastCooked?.carbsName;

    // Adapt meals
    final adaptedMeals = meals.map((m) => _MealCandidate.from(m)).toList();

    // Parse settings - typed optimal, fallback dynamic for tests
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

    // 3. 5-Level Progressive Relaxation Cascade (Levels 0 through 5)
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

      // Termination Condition
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

    // Safety fallback
    final fallbackRaw = adaptedMeals.take(targetCount).map((c) => c.rawMeal as T).toList();
    return RecommendationResult<T>(
      recommendations: fallbackRaw,
      relaxationLevel: 5,
      relaxationReason: _relaxationReason(5, isEmpty: false),
      computedDate: normalizedToday,
    );
  }

  /// Filters candidate meals based on the strictness rules of the given relaxation level.
  /// Optimal: uses precomputed map instead of scanning history per meal.
  /// Implements per-protein cooldowns (0 = disabled).
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
      // Determine per-protein specific cooldown (0 = disabled, optimal feature)
      final int specificCooldown;
      switch (meal.proteinName) {
        case 'chicken':
          specificCooldown = chickenCooldownDays;
          break;
        case 'beef':
          specificCooldown = beefCooldownDays;
          break;
        case 'fish':
          specificCooldown = fishCooldownDays;
          break;
        default:
          specificCooldown = meatlessCooldownDays;
          break;
      }

      // If specific cooldown is 0, that protein type is disabled (no cooldown) - respect UI
      // But still apply global cooldown if specific is 0? Spec says 0 = off, so skip both.
      // We treat 0 as completely off for that protein, but global still applies if >0 and protein is not meatless?
      // Optimal: if specific ==0, skip cooldown check for this meal (allow repeat)
      final bool isCooldownDisabled = specificCooldown == 0;

      // Find last cooked date via map O(1)
      final DateTime? lastCookedDate = lastCookedByMealId[meal.id];

      // A. Cooldown Exclusion Evaluation
      if (lastCookedDate != null && !isCooldownDisabled) {
        final deltaDays = _daysBetween(lastCookedDate, today);

        if (level == 4) {
          // Level 4 Emergency Mode: Exclude meals cooked today only
          if (deltaDays == 0) return false;
        } else if (level < 5) {
          // Levels 0..3: use per-protein cooldown if set, else global, with relaxation
          final int baseCooldown = specificCooldown > 0 ? specificCooldown : cooldownDays;
          final effectiveCooldown = _calculateEffectiveCooldown(baseCooldown, level);
          if (deltaDays <= effectiveCooldown) return false;
        }
        // Level 5: Cooldown is completely bypassed
      }

      // B. Carbohydrate Repeat Evaluation
      if (level == 0 && preventCarbs && lastCarbs != null && lastCarbs != 'none') {
        if (meal.carbsName == lastCarbs) return false;
      }

      // C. Protein Repeat Evaluation
      if (level <= 2 && preventProtein && lastProtein != null && lastProtein != 'none') {
        if (meal.proteinName == lastProtein) return false;
      }

      return true;
    }).toList();
  }

  /// Calculates effective cooldown window clamped safely between 1 and configDays.
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

  /// Calculates individual meal ranking score based on recency, Friday, favorite, budget, and jitter.
  /// Optimal: uses precomputed map if provided, else builds map from history list (backward compat for tests).
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
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // Optimal: use precomputed map if available, else build from history list
    Map<int, DateTime> effectiveMap;
    if (lastCookedByMealId != null) {
      effectiveMap = lastCookedByMealId;
    } else if (history is Map<int, DateTime>) {
      effectiveMap = history;
    } else {
      // Build map from history list (O(n)) - backward compat
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
              if (raw is DateTime) hDate = DateTime(raw.year, raw.month, raw.day);
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

    // Determine per-protein cooldown for scoring (use specific if >0)
    final int specificCooldown;
    switch (candidate.proteinName) {
      case 'chicken':
        specificCooldown = chickenCooldownDays;
        break;
      case 'beef':
        specificCooldown = beefCooldownDays;
        break;
      case 'fish':
        specificCooldown = fishCooldownDays;
        break;
      default:
        specificCooldown = meatlessCooldownDays;
        break;
    }
    final int effectiveBaseCooldown = specificCooldown > 0 ? specificCooldown : cooldownDays;

    // 1. Recency Component
    double sRecency;
    if (lastCookedDate == null) {
      sRecency = 25.0; // Rewards untried meals
    } else {
      final deltaDays = _daysBetween(lastCookedDate, normalizedToday);
      sRecency = min(20.0, (deltaDays - effectiveBaseCooldown) / 2.0);
    }

    // 2. Friday Special Component
    double sFriday = 0.0;
    final isFriday = normalizedToday.weekday == DateTime.friday;
    if (isFriday) {
      sFriday = candidate.isFridaySpecial ? 15.0 : 0.0;
    } else {
      sFriday = candidate.isFridaySpecial ? -5.0 : 0.0;
    }

    // 3. Favorite Component
    final sFavorite = candidate.isFavorite ? 5.0 : 0.0;

    // 4. Budget Component
    final sBudget = candidate.isBudgetFriendly ? 2.0 : 0.0;

    // 5. Deterministic Daily Jitter: domain [0.0, 3.96]
    final jitter = ((normalizedToday.day * 17 + candidate.id * 31) % 100) / 25.0;

    return sRecency + sFriday + sFavorite + sBudget + jitter;
  }

  /// Greedy selection of top 3 cards ensuring protein and carbohydrate diversity.
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

    // Sort descending by score (passing map for O(1) lookup)
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

    // 1. Select Card 1: Absolute highest scoring candidate
    selected.add(remaining.removeAt(0));

    // 2. Select Card 2: Highest scoring candidate with distinct protein from Card 1
    if (remaining.isNotEmpty) {
      final card2Index = remaining.indexWhere((m) => m.proteinName != selected[0].proteinName);
      if (card2Index != -1) {
        selected.add(remaining.removeAt(card2Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    // 3. Select Card 3: Distinct protein from Cards 1 & 2 -> Fallback distinct carbs -> Top score
    if (remaining.isNotEmpty) {
      final existingProteins = selected.map((m) => m.proteinName).toSet();
      var card3Index = remaining.indexWhere((m) => !existingProteins.contains(m.proteinName));

      if (card3Index == -1) {
        // Fallback: Carbohydrate diversity
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

  static int _daysBetween(DateTime from, DateTime to) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return t.difference(f).inDays;
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

  static DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
