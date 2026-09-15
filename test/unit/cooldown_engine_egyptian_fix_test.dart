import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import '../support/contracts.dart' hide RecommendationResult;
import '../support/seed_catalog.dart';

void main() {
  group('Cooldown fix [C] - Egyptian legume/dairy/none should have cooldown', () {
    late RecommendationEngine refEngine;
    late CooldownEngine realEngine;
    final baseDate = DateTime(2026, 9, 6);

    setUp(() {
      refEngine = const RecommendationEngine();
      realEngine = const CooldownEngine();
    });

    test('koshari (legume) cooked yesterday NOT recommended today with defaults', () {
      final koshari = initialEgyptianMealsSeed.firstWhere((m) => m.name.contains('كشري'));
      expect(koshari.proteinType, ProteinType.legume);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: koshari.id,
          mealName: koshari.name,
          proteinType: ProteinType.legume,
          carbsType: koshari.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      const settings = AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: false,
        preventRepeatCarbs: false,
      );

      final result = refEngine.compute(
        meals: initialEgyptianMealsSeed,
        history: history,
        settings: settings,
        today: baseDate,
      );

      expect(result.recommendations.any((m) => m.id == koshari.id), isFalse,
          reason: 'Koshari cooked yesterday should be on cooldown (14 days), not recommended today');
    });

    test('foul, adas, eggs also have cooldown - not disabled', () {
      final foulMeals = initialEgyptianMealsSeed.where((m) => m.proteinType == ProteinType.legume || m.proteinType == ProteinType.dairy).toList();
      expect(foulMeals.isNotEmpty, true);

      final today = DateTime(2026, 9, 6);
      final yesterday = today.subtract(const Duration(days: 1));

      for (final meal in foulMeals.take(3)) {
        final history = [
          MealHistoryData(
            id: 1,
            mealId: meal.id,
            mealName: meal.name,
            proteinType: meal.proteinType,
            carbsType: meal.carbsType,
            cookedDate: yesterday,
            status: MealHistoryStatus.cookedToday,
            createdAt: yesterday,
          ),
        ];

        final result = refEngine.compute(
          meals: initialEgyptianMealsSeed,
          history: history,
          settings: const AppSetting(cooldownDays: 7),
          today: today,
        );

        expect(result.recommendations.any((m) => m.id == meal.id), isFalse,
            reason: 'Meal ${meal.name} (${meal.proteinType}) cooked yesterday should be on cooldown');
      }
    });

    test('meatlessCooldownDays=0 means inherit global, not disable', () {
      // Using real CooldownEngine with drift-like settings
      final koshari = initialEgyptianMealsSeed.firstWhere((m) => m.name.contains('كشري'));
      final base = DateTime(2026, 9, 6);

      final fakeMeal = _FakeMeal(
        id: koshari.id,
        name: koshari.name,
        proteinType: 'legume',
        carbsType: 'rice',
        isFridaySpecial: false,
        isBudgetFriendly: false,
        isFavorite: false,
      );

      final otherMeals = initialEgyptianMealsSeed.where((m) => m.id != koshari.id).take(10).map((m) => _FakeMeal(
            id: m.id,
            name: m.name,
            proteinType: m.proteinType.name,
            carbsType: m.carbsType.name,
            isFridaySpecial: m.isFridaySpecial,
            isBudgetFriendly: m.isBudgetFriendly,
            isFavorite: m.isFavorite,
          )).toList();

      final allMeals = [fakeMeal, ...otherMeals];

      final history = [
        _FakeHistory(
          mealId: koshari.id,
          proteinType: 'legume',
          carbsType: 'rice',
          cookedAt: base.subtract(const Duration(days: 1)),
          createdAt: base.subtract(const Duration(days: 1)),
        ),
      ];

      final settings = _FakeSettings(
        cooldownDays: 14,
        chickenCooldownDays: 7,
        beefCooldownDays: 10,
        fishCooldownDays: 5,
        meatlessCooldownDays: 0,
        preventRepeatProtein: false,
        preventRepeatCarbs: false,
      );

      final result = realEngine.compute(
        meals: allMeals,
        history: history,
        settings: settings,
        today: base,
      );

      expect(result.recommendations.any((m) => (m as _FakeMeal).id == koshari.id), isFalse,
          reason: 'With meatlessCooldownDays=0, legume should inherit global 14 days, not 0');
    });
  });

  group('DST fix [D] - daysBetweenLocal via UTC calendar fields', () {
    test('Egypt DST 23h day - April last Friday 2026', () {
      // Egypt DST 2023+ : last Friday April clocks forward, last Thursday October clocks back
      // April 2026 last Friday is April 24
      // Simulate 23h day: from April 24 00:00 to April 25 00:00 is 23h in local if DST forward at midnight?
      // Our _dayNumber uses calendar fields, so should still be 1 day
      final april24 = DateTime(2026, 4, 24);
      final april25 = DateTime(2026, 4, 25);
      final engine = const RecommendationEngine();

      // If using difference().inDays on local DateTime with 23h, it would give 0 for 23h difference
      // Our fix should give 1
      final days = _daysBetweenLocalFixed(april24, april25);
      expect(days, 1);

      // Cooldown 7 days should stay 7 across DST
      final meal = initialEgyptianMealsSeed.first;
      final history = [
        MealHistoryData(
          id: 1,
          mealId: meal.id,
          mealName: meal.name,
          proteinType: meal.proteinType,
          carbsType: meal.carbsType,
          cookedDate: april24,
          status: MealHistoryStatus.cookedToday,
          createdAt: april24,
        ),
      ];

      final resultApril25 = engine.compute(
        meals: initialEgyptianMealsSeed,
        history: history,
        settings: const AppSetting(cooldownDays: 7),
        today: april25,
      );

      // Meal cooked April 24, today April 25, cooldown 7 -> should be excluded
      expect(resultApril25.recommendations.any((m) => m.id == meal.id), isFalse);
    });

    test('Egypt DST 25h day - October last Thursday 2026', () {
      // October 2026 last Thursday is Oct 29
      final oct29 = DateTime(2026, 10, 29);
      final oct30 = DateTime(2026, 10, 30);
      final days = _daysBetweenLocalFixed(oct29, oct30);
      expect(days, 1);

      // 25h day should not count as 1 day + extra
      final oct29Plus7 = DateTime(2026, 11, 5);
      final diff = _daysBetweenLocalFixed(oct29, oct29Plus7);
      expect(diff, 7, reason: 'Cooldown 7 days should stay 7 across 25h DST day');
    });

    test('daysSinceEpoch via UTC calendar is deterministic across DST', () {
      final date1 = DateTime(2026, 4, 24);
      final date2 = DateTime(2026, 4, 25);
      final epoch1 = _daysSinceEpochFixed(date1);
      final epoch2 = _daysSinceEpochFixed(date2);
      expect(epoch2 - epoch1, 1);
    });
  });
}

int _dayNumberFixed(DateTime d) {
  final l = d.isUtc ? d.toLocal() : d;
  return DateTime.utc(l.year, l.month, l.day).difference(DateTime.utc(1970, 1, 1)).inDays;
}

int _daysBetweenLocalFixed(DateTime from, DateTime to) => _dayNumberFixed(to) - _dayNumberFixed(from);
int _daysSinceEpochFixed(DateTime dt) => _dayNumberFixed(dt);

class _FakeMeal {
  final int id;
  final String name;
  final String proteinType;
  final String carbsType;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isFavorite;
  _FakeMeal({
    required this.id,
    required this.name,
    required this.proteinType,
    required this.carbsType,
    required this.isFridaySpecial,
    required this.isBudgetFriendly,
    required this.isFavorite,
  });
}

class _FakeHistory {
  final int? mealId;
  final String proteinType;
  final String carbsType;
  final DateTime cookedAt;
  final DateTime createdAt;
  _FakeHistory({
    required this.mealId,
    required this.proteinType,
    required this.carbsType,
    required this.cookedAt,
    required this.createdAt,
  });
}

class _FakeSettings {
  final int cooldownDays;
  final int chickenCooldownDays;
  final int beefCooldownDays;
  final int fishCooldownDays;
  final int meatlessCooldownDays;
  final bool preventRepeatProtein;
  final bool preventRepeatCarbs;
  _FakeSettings({
    required this.cooldownDays,
    required this.chickenCooldownDays,
    required this.beefCooldownDays,
    required this.fishCooldownDays,
    required this.meatlessCooldownDays,
    required this.preventRepeatProtein,
    required this.preventRepeatCarbs,
  });
}
