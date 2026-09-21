import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import 'package:daily_meal/features/home/providers/recommendation_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _proteins = [
  ProteinType.chicken,
  ProteinType.beef,
  ProteinType.fish,
];

Meal makeMeal(int id, {bool isFavorite = false}) => Meal(
      id: id,
      name: 'Meal $id',
      photoPath: null,
      proteinType: _proteins[id % _proteins.length],
      carbsType: CarbsType.rice,
      category: MealCategory.egyptianTraditional,
      isStarterMeal: false,
      prepTime: 30,
      isFridaySpecial: false,
      isBudgetFriendly: false,
      isFavorite: isFavorite,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      cloudId: null,
      nameNormalized: null,
    );

AppSettingsData makeSettings() => AppSettingsData(
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

void main() {
  // Wednesday: the Friday-special bonus must not sway any expectation below.
  final wednesday = DateTime(2025, 3, 12, 12);
  const engine = CooldownEngine();

  List<int> pick({int seed = 0, List<Meal>? meals}) => engine
      .compute<Meal>(
        meals: meals ?? List.generate(9, makeMeal),
        history: const [],
        settings: makeSettings(),
        today: wednesday,
        shuffleSeed: seed,
      )
      .recommendations
      .map((m) => m.id)
      .toList();

  group('CooldownEngine shuffleSeed', () {
    test('a new seed changes which meals are suggested', () {
      final selections = <String>{
        for (var seed = 0; seed < 6; seed++) pick(seed: seed).join(','),
      };
      expect(
        selections.length,
        greaterThan(1),
        reason: 'pull-to-refresh must be able to surface different meals',
      );
    });

    test('the same seed always replays the same selection', () {
      expect(pick(seed: 4), pick(seed: 4));
    });

    test('a favourite outranks plain meals regardless of the seed', () {
      final meals = [
        for (var id = 1; id <= 9; id++) makeMeal(id, isFavorite: id == 5),
      ];
      for (var seed = 0; seed < 6; seed++) {
        expect(pick(seed: seed, meals: meals).first, 5);
      }
    });
  });

  test('favouriting a meal keeps today\'s recommendations in place', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.appSettingsDao.ensureSettings();
    for (var id = 1; id <= 9; id++) {
      await db.mealsDao.insertMeal(MealsCompanion(
        name: Value('Meal $id'),
        proteinType: Value(_proteins[id % _proteins.length]),
        carbsType: const Value(CarbsType.rice),
        category: const Value(MealCategory.egyptianTraditional),
        prepTime: const Value(30),
      ));
    }

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    final subscription =
        container.listen(todayRecommendationsProvider, (_, __) {});
    await Future.delayed(const Duration(milliseconds: 100));

    final before =
        subscription.read().requireValue.recommendations.map((m) => m.id).toList();
    expect(before.length, 3);

    // The *last* card, not the first: favouriting the top card happens to leave
    // the order intact even when the list is re-ranked, so it proves nothing.
    final bumped = before.last;

    await db.mealsDao.toggleFavorite(bumped, false);
    await Future.delayed(const Duration(milliseconds: 100));

    final after =
        subscription.read().requireValue.recommendations.map((m) => m.id).toList();
    expect(after, before, reason: 'the heart button must not re-rank the cards');
    expect(
      subscription
          .read()
          .requireValue
          .recommendations
          .firstWhere((m) => m.id == bumped)
          .isFavorite,
      isTrue,
      reason: 'but the card itself still reflects the new favourite state',
    );

    subscription.close();
    container.dispose();
    await db.close();
  });
}
