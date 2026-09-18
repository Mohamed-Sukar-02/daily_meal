import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/core/utils/app_date_utils.dart' as app_date_utils;
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import 'package:daily_meal/core/database/app_database.dart';

void main() {
  group('Date boundary - 23:50 vs 00:10, 31->1, roundtrip [restored]', () {
    test('23:50 and 00:10 next day are different local days', () {
      final t1 = DateTime(2025, 1, 15, 23, 50);
      final t2 = DateTime(2025, 1, 16, 0, 10);

      expect(app_date_utils.isSameLocalDay(t1, t2), false);
      expect(app_date_utils.daysBetweenLocal(t1, t2), 1, reason: '23:50 and 00:10 next day should be 1 day apart');
    });

    test('23:50 and 23:55 same day are same local day', () {
      final t1 = DateTime(2025, 1, 15, 23, 50);
      final t2 = DateTime(2025, 1, 15, 23, 55);
      expect(app_date_utils.isSameLocalDay(t1, t2), true);
      expect(app_date_utils.daysBetweenLocal(t1, t2), 0);
    });

    test('31 -> 1 month boundary does not break daysSinceEpoch', () {
      final jan31 = DateTime(2025, 1, 31, 12, 0);
      final feb1 = DateTime(2025, 2, 1, 12, 0);

      final daysJan31 = app_date_utils.daysSinceEpoch(jan31);
      final daysFeb1 = app_date_utils.daysSinceEpoch(feb1);

      expect(daysFeb1 - daysJan31, 1, reason: 'Should be 1 day apart, not break on month boundary');

      final feb28 = DateTime(2025, 2, 28);
      final mar1 = DateTime(2025, 3, 1);
      expect(app_date_utils.daysBetweenLocal(feb28, mar1), 1);
    });

    test('roundtrip storage - toLocalDay preserves calendar day', () {
      final localCooked = DateTime(2025, 1, 15, 23, 50);
      final stored = localCooked;

      final localDayFromStored = app_date_utils.toLocalDay(stored);
      final localDayOriginal = app_date_utils.toLocalDay(localCooked);

      expect(localDayFromStored.year, localDayOriginal.year);
      expect(localDayFromStored.month, localDayOriginal.month);
      expect(localDayFromStored.day, localDayOriginal.day);
      expect(localDayFromStored.hour, 0);
    });

    test('cooldown engine respects 23:50 vs 00:10 as 1 day', () {
      final engine = const CooldownEngine();

      Meal makeMeal(int id) {
        return Meal(
          id: id,
          name: 'Test $id',
          photoPath: null,
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTime: 30,
          isFridaySpecial: false,
          isBudgetFriendly: false,
          isFavorite: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          cloudId: null,
          nameNormalized: null,
        );
      }

      AppSettingsData makeSettings() {
        return AppSettingsData(
          id: 1,
          cooldownDays: 14,
          chickenCooldownDays: 7,
          beefCooldownDays: 10,
          fishCooldownDays: 5,
          meatlessCooldownDays: 0,
          notificationHour: 12,
          notificationMinute: 0,
          notificationsEnabled: false,
          themeMode: AppThemeModePreference.system,
          language: AppLanguagePreference.ar,
          isFirstRun: false,
          recommendationSource: RecommendationSource.vault_only,
          autoFridayFeastFilter: false,
        );
      }

      final meal1 = makeMeal(1);
      final meal2 = makeMeal(2);
      final cookedAt2350 = DateTime(2025, 1, 15, 23, 50);
      final today0010 = DateTime(2025, 1, 16, 0, 10);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'Test 1',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedAt: cookedAt2350,
          entryType: MealEntryType.cooked,
          notes: null,
          createdAt: DateTime.now(),
        ),
      ];

      final result = engine.compute<Meal>(
        meals: [meal1, meal2],
        history: history,
        settings: makeSettings(),
        today: today0010,
      );

      expect(result.recommendations.isNotEmpty, true);
      expect(app_date_utils.daysBetweenLocal(cookedAt2350, today0010), 1);
    });
  });
}
