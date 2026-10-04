import 'dart:math';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_date_utils.dart' as app_date_utils;

class RecommendationResult<T> {
  final List<T> recommendations;

  /// 0 = perfect match … 5 = every rule relaxed. The UI turns this into
  /// localised copy via `AppStrings.relaxationReason`; the domain layer stays
  /// free of display text so it can be unit-tested without a locale.
  final int relaxationLevel;

  /// True when the vault itself was empty (a distinct message from "relaxed").
  final bool isEmptyVault;

  /// Ids the caller asked the engine to avoid (the cards currently on screen)
  /// that still had to be re-served because the pool offered no alternative
  /// to fill their slot. Empty unless an explicit refresh passed `excludeIds`.
  /// The UI uses this to be honest ("no new suggestions today") instead of
  /// silently reshuffling the same cards.
  final List<int> repeatedIds;

  final DateTime computedDate;

  const RecommendationResult({
    required this.recommendations,
    required this.relaxationLevel,
    required this.computedDate,
    this.isEmptyVault = false,
    this.repeatedIds = const [],
  });
}

class CooldownEngine {
  const CooldownEngine();

  /// [excludeIds]: ids of the cards currently on screen. Passed ONLY for an
  /// explicit "change my suggestions" refresh: selection then prefers meals
  /// the user is not already looking at, and any id it is forced to re-serve
  /// is reported back in [RecommendationResult.repeatedIds]. Without it the
  /// seed used to be nothing more than a tie-breaker inside score bands, so
  /// dominant meals were pinned in place across refreshes — the very bug this
  /// parameter exists to fix.
  RecommendationResult<T> compute<T>({
    required List<T> meals,
    required List<dynamic> history,
    required dynamic settings,
    DateTime? today,
    int shuffleSeed = 0,
    Set<int>? excludeIds,
  }) {
    final now = today ?? DateTime.now();
    final normalizedToday = app_date_utils.toLocalDay(now);

    if (meals.isEmpty) {
      return RecommendationResult<T>(
        recommendations: const [],
        relaxationLevel: 5,
        isEmptyVault: true,
        computedDate: normalizedToday,
      );
    }

    final adaptedHistory =
        history.map((h) => _HistoryCandidate.from(h)).toList()..sort((a, b) {
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

    final adaptedMeals = meals.map((m) => _MealCandidate.from(m)).toList();

    final int configCooldown;
    final int chickenCooldown;
    final int beefCooldown;
    final int fishCooldown;
    final int meatlessCooldown;

    if (settings is AppSettingsData) {
      configCooldown = settings.cooldownDays;
      chickenCooldown = settings.chickenCooldownDays;
      beefCooldown = settings.beefCooldownDays;
      fishCooldown = settings.fishCooldownDays;
      meatlessCooldown = settings.meatlessCooldownDays;
    } else {
      configCooldown = (settings as dynamic)?.cooldownDays as int? ?? 14;
      chickenCooldown = (settings as dynamic)?.chickenCooldownDays as int? ?? 2;
      beefCooldown = (settings as dynamic)?.beefCooldownDays as int? ?? 2;
      fishCooldown = (settings as dynamic)?.fishCooldownDays as int? ?? 4;
      meatlessCooldown =
          (settings as dynamic)?.meatlessCooldownDays as int? ?? 0;
    }

    final targetCount = min(3, meals.length);
    final excluded = excludeIds ?? const <int>{};

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
        level: level,
      );

      final ranked = _rankCandidates(
        candidates: candidates,
        lastCookedByMealId: lastCookedByMealId,
        today: normalizedToday,
        cooldownDays: configCooldown,
        chickenCooldownDays: chickenCooldown,
        beefCooldownDays: beefCooldown,
        fishCooldownDays: fishCooldown,
        meatlessCooldownDays: meatlessCooldown,
        shuffleSeed: shuffleSeed,
      );

      // Pool-size acceptance is judged against the FULL ranked pool, exactly
      // as before; the novelty split below never pushes selection into a more
      // relaxed level, it only re-orders who gets a slot inside this level.
      if (ranked.length >= targetCount || level == 5) {
        final selection = _selectWithNovelty(ranked, targetCount, excluded);
        final selectedRaw = selection.map((c) => c.rawMeal as T).toList();
        return RecommendationResult<T>(
          recommendations: selectedRaw,
          relaxationLevel: level,
          computedDate: normalizedToday,
          repeatedIds: selection
              .where((c) => excluded.contains(c.id))
              .map((c) => c.id)
              .toList(),
        );
      }
    }

    throw StateError('Unreachable: relaxation level 5 is exhaustive');
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
    required int level,
  }) {
    return meals.where((meal) {
      final int specificCooldown = _resolveSpecificCooldown(
        proteinName: meal.proteinName,
        customCooldownDays: meal.customCooldownDays,
        cooldownDays: cooldownDays,
        chickenCooldownDays: chickenCooldownDays,
        beefCooldownDays: beefCooldownDays,
        fishCooldownDays: fishCooldownDays,
        meatlessCooldownDays: meatlessCooldownDays,
      );

      final DateTime? lastCookedDate = lastCookedByMealId[meal.id];

      if (lastCookedDate != null) {
        final deltaDays = app_date_utils.daysBetweenLocal(
          lastCookedDate,
          today,
        );

        if (level == 4) {
          if (deltaDays == 0) return false;
        } else if (level < 5) {
          final effectiveCooldown = _calculateEffectiveCooldown(
            specificCooldown,
            level,
          );
          if (deltaDays <= effectiveCooldown) return false;
        }
      }

      return true;
    }).toList();
  }

  /// The window that applies to one meal, in the order the app trusts it:
  /// the meal's own override, then the protein window, then the general one.
  int _resolveSpecificCooldown({
    required String proteinName,
    required int cooldownDays,
    required int chickenCooldownDays,
    required int beefCooldownDays,
    required int fishCooldownDays,
    required int meatlessCooldownDays,
    int? customCooldownDays,
  }) {
    // Read before the switch and before the general window on purpose: this
    // number was written about THIS meal, so nothing derived from its protein
    // can outrank it. `0` is a real answer ("always eligible") and does not
    // fall through, for the same reason `ProteinType.none` does not.
    final int? mealOverride = customCooldownDays;
    if (mealOverride != null) return mealOverride;

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
      case 'legume':
        specific = meatlessCooldownDays;
        break;
      case 'dairy':
        specific = meatlessCooldownDays;
        break;
      case 'none':
        specific = meatlessCooldownDays;
        break;
      default:
        specific = cooldownDays;
        break;
    }
    // NOTE: 0 means "no cooldown" (user explicitly disabled it).
    // Do NOT fall back to the global default here.
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

  /// Pure meal quality: how overdue it is, Friday fit and favourite flag.
  /// Deliberately contains no randomness — variety is decided in
  /// [_rankCandidates] and [_selectDiverse], so this stays a stable
  /// "goodness" number.
  double calculateMealScore({
    required dynamic meal,
    dynamic history = const [],
    required DateTime today,
    required int cooldownDays,
    int chickenCooldownDays = 2,
    int beefCooldownDays = 2,
    int fishCooldownDays = 4,
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
              if (existing == null || hDate.isAfter(existing))
                effectiveMap[hMealId] = hDate;
            }
          } catch (_) {}
        }
      }
    }

    final DateTime? lastCookedDate = effectiveMap[candidate.id];

    final int specificCooldown = _resolveSpecificCooldown(
      proteinName: candidate.proteinName,
      customCooldownDays: candidate.customCooldownDays,
      cooldownDays: cooldownDays,
      chickenCooldownDays: chickenCooldownDays,
      beefCooldownDays: beefCooldownDays,
      fishCooldownDays: fishCooldownDays,
      meatlessCooldownDays: meatlessCooldownDays,
    );

    // `specificCooldown` came out of the same resolver the eligibility screen
    // uses, so a meal's own window moves its "how overdue am I" term with it:
    // an override that lengthens the window also lowers the score, which is
    // the point — otherwise a meal could be scored as though it were overdue
    // while being filtered as though it were not.
    double sRecency;
    if (lastCookedDate == null) {
      sRecency = 25.0;
    } else {
      final deltaDays = app_date_utils.daysBetweenLocal(
        lastCookedDate,
        normalizedToday,
      );
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

    return sRecency + sFriday + sFavorite;
  }

  /// A meal's seeded draw for one day: the same number for as long as none of
  /// the three inputs changes, a fresh shuffle for the whole day when any of
  /// them does.
  ///
  /// MurmurHash3's 32-bit finalizer, done in halves on purpose:
  ///  * `dart:math`'s `Random` is a *stream* — using it here is what made the
  ///    pool's composition part of a meal's value, the bug this replaces;
  ///  * 32-bit arithmetic keeps the VM and the web build in agreement, which a
  ///    "today's three cards" rule absolutely has to be.
  static double _lotteryFor({
    required int id,
    required int dayEpoch,
    required int seed,
  }) {
    var h = _u32(0x9e3779b9);
    h = _u32(h ^ _mul32(_u32(dayEpoch), 0x85ebca6b));
    h = _u32(h ^ _mul32(_u32(id), 0xc2b2ae35));
    h = _u32(h ^ _mul32(_u32(seed), 0x27d4eb2f));
    h = _u32(h ^ (h >>> 16));
    h = _mul32(h, 0x85ebca6b);
    h = _u32(h ^ (h >>> 13));
    h = _mul32(h, 0xc2b2ae35);
    h = _u32(h ^ (h >>> 16));
    // 24 bits of the avalanche: enough to order a few thousand vault rows
    // without collisions in practice, and exact in a double on every platform.
    return (h >>> 8) / 0x1000000;
  }

  /// `&` is a *signed* int32 operation on the web, so every step is normalised
  /// back to an unsigned 32-bit value; without `>>> 0` the VM and dart2js would
  /// disagree on the high bit — i.e. on which meal wins a slot.
  static const int _mask32 = 0xFFFFFFFF;

  static int _u32(int x) => (x & _mask32) >>> 0;

  /// The low 32 bits of `a * b`, from four 16-bit partials. A web build computes
  /// on a 53-bit double, so a raw 32×32 product would round before it could be
  /// masked; the partial sum here never exceeds 2^33.
  static int _mul32(int a, int b) {
    final al = a & 0xFFFF;
    final ah = (a >> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    final bh = (b >> 16) & 0xFFFF;
    return _u32(al * bl + _u32((al * bh + ah * bl) & 0xFFFF) * 0x10000);
  }

  /// Score gap within which two meals count as equally worthy of a card slot.
  /// Equal to the favourite bonus, so a favourite and a plain meal cooked
  /// around the same time stay interchangeable.
  static const double _interchangeableBand = 5.0;

  /// Scores every candidate and returns the WHOLE pool ranked best-first:
  /// band (score bracket) first, the seeded lottery inside the band, then id
  /// for total stability. Selection and diversity picking happen afterwards,
  /// separately, so this stays a pure ordering.
  List<_MealCandidate> _rankCandidates({
    required List<_MealCandidate> candidates,
    required Map<int, DateTime> lastCookedByMealId,
    required DateTime today,
    required int cooldownDays,
    int chickenCooldownDays = 2,
    int beefCooldownDays = 2,
    int fishCooldownDays = 4,
    int meatlessCooldownDays = 0,
    int shuffleSeed = 0,
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
    }).toList();

    // One seeded value per meal, hashed from (id, day, seed) alone. It used to be
    // a `Random` stream advanced in ascending id order, which pinned a meal's
    // value to *how many smaller ids happened to be in the pool*: the DAO sorts
    // by name, so a rename was harmless, but logging today's lunch removed a
    // candidate and shifted every draw after it — re-dealing the two cards the
    // user was not touching, and again on every add, delete or relaxation-level
    // change. A hash has no stream to shift: the pool can churn and each meal
    // keeps its number for the day. Within a band the value decides; across
    // bands quality still rules.
    final dayEpoch = app_date_utils.daysSinceEpoch(today);
    final lottery = <int, double>{
      for (final candidate in candidates)
        candidate.id: _lotteryFor(
          id: candidate.id,
          dayEpoch: dayEpoch,
          seed: shuffleSeed,
        ),
    };

    scored.sort((a, b) {
      final bandA = (a.value / _interchangeableBand).floor();
      final bandB = (b.value / _interchangeableBand).floor();
      if (bandA != bandB) return bandB.compareTo(bandA);
      final drawCmp = lottery[b.key.id]!.compareTo(lottery[a.key.id]!);
      if (drawCmp != 0) return drawCmp;
      return b.key.id.compareTo(a.key.id);
    });

    return scored.map((e) => e.key).toList();
  }

  /// Picks [targetCount] slots from the ranked [pool] while honouring an
  /// explicit "show me something else" request: ids in [excluded] are only
  /// re-served when the rest of the pool cannot fill a slot. With an empty
  /// [excluded] this is exactly the classic selection.
  List<_MealCandidate> _selectWithNovelty(
    List<_MealCandidate> ranked,
    int targetCount,
    Set<int> excluded,
  ) {
    if (excluded.isEmpty) return _selectDiverse(ranked, targetCount);

    // Rank is preserved inside both sides, so fresh picks stay "best first"
    // and repeats are backfilled best-of-the-worst case.
    final novel = <_MealCandidate>[];
    final repeats = <_MealCandidate>[];
    for (final candidate in ranked) {
      (excluded.contains(candidate.id) ? repeats : novel).add(candidate);
    }

    var selection = _selectDiverse(novel, targetCount);
    if (selection.length < targetCount && repeats.isNotEmpty) {
      selection = _selectDiverse(repeats, targetCount, selection);
    }
    return selection;
  }

  /// Greedy diversity pick over an already-ranked [pool]: the first card
  /// takes the best meal, every later card takes the best meal whose protein
  /// the earlier cards don't already have (falling back to carbs variety when
  /// no new protein is available, then to plain rank order). [preselected] seeds the
  /// selection when backfilling with repeats after a refresh, so variety is
  /// judged against the cards already chosen.
  List<_MealCandidate> _selectDiverse(
    List<_MealCandidate> pool,
    int targetCount, [
    List<_MealCandidate> preselected = const [],
  ]) {
    final selected = List<_MealCandidate>.of(preselected);
    final remaining = List<_MealCandidate>.of(pool);

    while (selected.length < targetCount && remaining.isNotEmpty) {
      if (selected.isEmpty) {
        selected.add(remaining.removeAt(0));
        continue;
      }

      final proteins = selected.map((m) => m.proteinName).toSet();
      var index = remaining.indexWhere(
        (m) => !proteins.contains(m.proteinName),
      );
      if (index == -1) {
        final carbs = selected.map((m) => m.carbsName).toSet();
        index = remaining.indexWhere((m) => !carbs.contains(m.carbsName));
      }

      selected.add(remaining.removeAt(index == -1 ? 0 : index));
    }

    return selected;
  }
}

class _MealCandidate {
  final dynamic rawMeal;
  final int id;
  final String name;
  final String proteinName;
  final String carbsName;
  final bool isFridaySpecial;
  final bool isFavorite;

  /// This meal's own cooldown window, `null` = "follow the protein/general
  /// windows". Read through a `dynamic` lookup inside a `try` because the
  /// engine also receives partial meal objects (fakes, projections) that do not
  /// declare the column at all; for those, "no override" is the honest answer
  /// and a missing field must never throw.
  final int? customCooldownDays;

  _MealCandidate.from(this.rawMeal)
    : id = (rawMeal as dynamic).id as int,
      name = (rawMeal as dynamic).name as String,
      proteinName = _extractEnumName((rawMeal as dynamic).proteinType),
      carbsName = _extractEnumName((rawMeal as dynamic).carbsType),
      isFridaySpecial = (rawMeal as dynamic).isFridaySpecial as bool,
      isFavorite = (rawMeal as dynamic).isFavorite as bool,
      customCooldownDays = _extractCustomCooldown(rawMeal);

  /// Negatives are clamped at the read, not left to the callers: a stored `-1`
  /// would survive `_calculateEffectiveCooldown` as a negative window, i.e. a
  /// meal that can never be blocked at all — a different answer from the `0`
  /// that means "no cooldown", and one no editor can even produce.
  static int? _extractCustomCooldown(dynamic rawMeal) {
    try {
      final dynamic value = (rawMeal as dynamic).customCooldownDays;
      if (value is! int) return null;
      return value < 0 ? 0 : value;
    } catch (_) {
      return null;
    }
  }

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
      proteinName = _MealCandidate._extractEnumName(
        (rawHistory as dynamic).proteinType,
      ),
      carbsName = _MealCandidate._extractEnumName(
        (rawHistory as dynamic).carbsType,
      );

  /// Falls back to epoch 0 ("never cooked") rather than `DateTime.now()`: a
  /// corrupted row that reads as "cooked today" would block the meal for the
  /// whole cooldown window, while an absent date only leaves it rankable.
  static DateTime _extractRawDate(dynamic raw) {
    try {
      final dynamic d = (raw as dynamic).cookedAt;
      if (d is DateTime) return d;
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime _normalizeDate(DateTime dt) => app_date_utils.toLocalDay(dt);
}
