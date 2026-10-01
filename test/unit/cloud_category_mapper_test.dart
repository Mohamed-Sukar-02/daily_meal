import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/vault/application/meal_sync_diff.dart';
import 'package:daily_meal/features/vault/data/cloud_vocabulary.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/providers/discovery_providers.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// The cloud vocabulary is narrower than the local enums, and the narrowing is
// not symmetric: `chicken/beef/fish/legume` survive a round trip, while
// `dairy`/`none` collapse into `other` and `potato`/`grains` collapse into
// `none`. Everything below is about the seam that creates — the sync diff and
// the "update from cloud" write — because both of them used to compare *labels*,
// which made a folded value look like a permanent, unfixable disagreement.

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

const Map<String, ProteinType> _cloudTokensToProtein = {
  'chicken': ProteinType.chicken,
  'beef': ProteinType.beef,
  'fish': ProteinType.fish,
  // 'meatless' is the cloud's name for `legume`, and it round-trips.
  'meatless': ProteinType.legume,
  // 'other' is a fold: it stands for `dairy` *and* `none`, so it can only
  // download as the one the cloud can name back.
  'other': ProteinType.none,
};

const Map<String, CarbsType> _cloudTokensToCarbs = {
  'rice': CarbsType.rice,
  'pasta': CarbsType.pasta,
  'bread': CarbsType.bread,
  // 'none' is a fold: `potato` and `grains` upload into it.
  'none': CarbsType.none,
};

CloudMeal _cloud({
  String name = 'وجبة',
  String protein = 'chicken',
  String carbs = 'rice',
  String category = 'tabeekh',
}) =>
    CloudMeal(
      id: 'c1',
      name: name,
      proteinType: protein,
      carbsType: carbs,
      category: category,
      prepTimeMinutes: 30,
      createdAt: DateTime(2026, 9, 22, 12),
    );

Meal _local({
  String name = 'وجبة',
  ProteinType protein = ProteinType.chicken,
  CarbsType carbs = CarbsType.rice,
  MealCategory category = MealCategory.egyptianTraditional,
}) {
  final now = DateTime(2026, 9, 22, 12);
  return Meal(
    id: 1,
    name: name,
    nameNormalized: name,
    proteinType: protein,
    carbsType: carbs,
    category: category,
    prepTime: 30,
    isFridaySpecial: false,
    isFavorite: false,
    isStarterMeal: true,
    createdAt: now,
    updatedAt: now,
    cloudId: 'c1',
  );
}

String _nameFor(MealCategory c) => 'وجبة ${c.name}';

void main() {
  final strings = const AppStrings(Locale('ar'));

  group('cloud → local mapping', () {
    test('cloudCategory resolves every deployed token', () {
      _cloudTokensToCategory.forEach((token, expected) {
        expect(cloudCategory(token), expected, reason: 'cloud token $token');
      });
    });

    test('cloudProteinType / cloudCarbsType resolve every deployed token', () {
      _cloudTokensToProtein.forEach((token, expected) {
        expect(cloudProteinType(token), expected, reason: 'cloud token $token');
      });
      _cloudTokensToCarbs.forEach((token, expected) {
        expect(cloudCarbsType(token), expected, reason: 'cloud token $token');
      });
    });

    test('the download side and the upload side are one table, not two', () {
      _cloudTokensToProtein.forEach((token, expected) {
        expect(cloudProteinType(token), expected);
        // Every token that names a local value maps back to it, so a synced meal
        // keeps its tag across a round trip — except the folds, which cannot.
        final roundTrips = MealCloudVocabulary.proteinToCloud(expected) == token;
        expect(
          roundTrips,
          !MealCloudVocabulary.proteinWouldFoldAway(expected),
          reason: '$expected / $token',
        );
      });
      _cloudTokensToCarbs.forEach((token, expected) {
        expect(cloudCarbsType(token), expected);
        final roundTrips = MealCloudVocabulary.carbsToCloud(expected) == token;
        expect(
          roundTrips,
          !MealCloudVocabulary.carbsWouldFoldAway(expected),
          reason: '$expected / $token',
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // The sync mark must not light up for a difference nobody can express.
  // ---------------------------------------------------------------------------
  group('mealCloudDiffs over the lossy axes', () {
    test('a starter-synced row reads as fully in sync for its cloud category', () {
      for (final entry in _cloudTokensToCategory.entries) {
        final local = _local(name: _nameFor(entry.value), category: entry.value);
        final cloud = _cloud(name: _nameFor(entry.value), category: entry.key);
        expect(
          mealCloudDiffs(local, cloud, strings),
          isEmpty,
          reason: 'category ${entry.key} must not produce a phantom diff',
        );
      }
    });

    test('a protein the cloud cannot name (dairy, none) is not a change', () {
      for (final protein in [ProteinType.dairy, ProteinType.none]) {
        final local = _local(protein: protein);
        final cloud = _cloud(protein: 'other');
        expect(
          mealCloudDiffs(local, cloud, strings),
          isEmpty,
          reason: '$protein uploads as "other"; the cloud cannot disagree with it',
        );
      }
    });

    test('carbs the cloud folds into "none" (potato, grains) are not a change', () {
      for (final carbs in [CarbsType.potato, CarbsType.grains]) {
        expect(
          mealCloudDiffs(_local(carbs: carbs), _cloud(carbs: 'none'), strings),
          isEmpty,
          reason: '$carbs uploads as "none"; flagging it is unfalsifiable',
        );
      }
    });

    test('a real tag difference is still reported', () {
      // rice → none is expressible in both directions, so it is a genuine edit.
      expect(
        mealCloudDiffs(_local(carbs: CarbsType.rice), _cloud(carbs: 'none'), strings),
        isNotEmpty,
      );
      expect(
        mealCloudDiffs(_local(protein: ProteinType.beef), _cloud(protein: 'chicken'), strings),
        isNotEmpty,
      );
      expect(
        mealCloudDiffs(_local(category: MealCategory.ovenBaked), _cloud(category: 'popular'), strings),
        isNotEmpty,
      );
      // …and a category the cloud does name keeps reporting normally.
      expect(
        mealCloudDiffs(
          _local(category: MealCategory.ovenBaked),
          _cloud(category: 'seafood'),
          strings,
        ),
        isNotEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // "Update from cloud" must not overwrite a tag with the fold that stands in
  // for it. This is the write that used to flatten `potato` to "no carbs" — and
  // protein `none` is what selects a different cooldown window, so the damage
  // was behavioural, not cosmetic.
  // ---------------------------------------------------------------------------
  group('applying a cloud row onto a local one', () {
    late AppDatabase db;
    late MealsDao dao;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.mealsDao;
    });
    tearDown(() async => db.close());

    Future<int> insert(Meal meal) => dao.insertMeal(MealsCompanion(
          name: Value(meal.name),
          proteinType: Value(meal.proteinType),
          carbsType: Value(meal.carbsType),
          category: Value(meal.category),
          prepTime: Value(meal.prepTime),
          isFridaySpecial: Value(meal.isFridaySpecial),
          isFavorite: Value(meal.isFavorite),
          isStarterMeal: Value(meal.isStarterMeal),
          cloudId: Value(meal.cloudId),
        ));

    DiscoveryNotifier notifier() =>
        // No photo work in this test: the localizer is injectable precisely so
        // the write path can be exercised without a network.
        DiscoveryNotifier(dao, db, localizeImage: (_) async => null);

    test('a folded axis is left alone, every other field is copied', () async {
      final id = await insert(_local(protein: ProteinType.dairy, carbs: CarbsType.potato));
      final ok = await notifier().updateMeal(
        id,
        _cloud(name: 'اسم من السحابة', protein: 'other', carbs: 'none'),
      );
      expect(ok, isTrue);

      final row = await dao.getMealById(id);
      expect(row?.name, 'اسم من السحابة', reason: 'plain fields still follow the cloud');
      expect(row?.proteinType, ProteinType.dairy,
          reason: 'the cloud\'s "other" cannot say "no protein" about an egg dish');
      expect(row?.carbsType, CarbsType.potato);
    });

    test('a protein the cloud does name is still applied', () async {
      final id = await insert(_local(protein: ProteinType.beef, carbs: CarbsType.potato));
      await notifier().updateMeal(
        id,
        _cloud(protein: 'chicken', carbs: 'rice'),
      );
      final row = await dao.getMealById(id);
      expect(row?.proteinType, ProteinType.chicken);
      expect(row?.carbsType, CarbsType.rice,
          reason: '"rice" is a real value, not a fold over potato');
    });

    test('a fresh insert always carries both tags (the columns are NOT NULL)', () async {
      final id = await notifier().downloadMeal(_cloud(protein: 'other', carbs: 'none'));
      final row = await dao.getMealById(id!);
      expect(row?.proteinType, ProteinType.none);
      expect(row?.carbsType, CarbsType.none);
    });
  });
}
