import 'dart:ui' show Locale;

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/vault/application/meal_sync_diff.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/providers/discovery_providers.dart';
import 'package:flutter_test/flutter_test.dart';

// The category vocabulary deployed in firestore.rules
// (data.category in ['tabeekh','casserole','dry_sandwich','popular',
//  'seafood','soup_stew','vegetarian']).
//
// cloudCategory must agree with AppConfigSyncService._mapCategory — the
// starter-sync writer that stamps cloudId on the local row — otherwise a
// freshly synced meal reports a phantom category diff and the sync mark
// stays orange forever ("Update from cloud" then flattens the row to match
// the mapper instead of the cloud).
const Map<String, MealCategory> _cloudTokensToCategory = {
  'tabeekh': MealCategory.egyptianTraditional,
  'casserole': MealCategory.ovenBaked,
  'dry_sandwich': MealCategory.fastFood,
  'seafood': MealCategory.seafood,
  'soup_stew': MealCategory.soupStew,
  'vegetarian': MealCategory.vegetarian,
  // 'popular' is the staging catch-all; both sides fold it to the default.
  'popular': MealCategory.egyptianTraditional,
};

void main() {
  test('cloudCategory resolves every deployed token', () {
    _cloudTokensToCategory.forEach((token, expected) {
      expect(cloudCategory(token), expected, reason: 'cloud token $token');
    });
  });

  test('a starter-synced row reads as fully in sync for its cloud category',
      () {
    final strings = const AppStrings(Locale('ar'));
    final now = DateTime(2026, 9, 22, 12);

    for (final entry in _cloudTokensToCategory.entries) {
      final cloud = CloudMeal(
        id: 'c1',
        name: _nameFor(entry.value),
        proteinType: 'chicken',
        carbsType: 'rice',
        category: entry.key,
        prepTimeMinutes: 30,
        createdAt: now,
      );
      final local = Meal(
        id: 1,
        name: _nameFor(entry.value),
        nameNormalized: _nameFor(entry.value),
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        category: entry.value,
        prepTime: 30,
        isFridaySpecial: false,
        isBudgetFriendly: false,
        isFavorite: false,
        isStarterMeal: true,
        createdAt: now,
        updatedAt: now,
        cloudId: 'c1',
      );
      expect(
        mealCloudDiffs(local, cloud, strings),
        isEmpty,
        reason: 'category ${entry.key} must not produce a phantom diff',
      );
    }
  });
}

String _nameFor(MealCategory c) => 'وجبة ${c.name}';
