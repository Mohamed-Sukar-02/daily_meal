import 'dart:ui' show Locale;

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/vault/application/meal_sync_diff.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/providers/discovery_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The sync mark turns orange while ANY compared field differs — notes included
// (meal_sync_diff.dart). So both cloud→local copy paths (download and the sync
// window's "Update from cloud") must carry notes over, otherwise the mark can
// never settle back to plain sync.

const String _cloudId = 'cloud-1';
const String _name = 'ملوخية خضراء بالفراخ';
const String _notes = 'تقلب على نار هادئة مع الثوم والكزبرة';

CloudMeal _cloudMeal({String? notes = _notes}) {
  return CloudMeal(
    id: _cloudId,
    name: _name,
    proteinType: 'chicken',
    carbsType: 'rice',
    category: 'tabeekh',
    prepTimeMinutes: 45,
    notes: notes,
    createdAt: DateTime(2026, 9, 20, 12),
  );
}

MealsCompanion _localRow({String? notes, String? cloudId = _cloudId}) {
  final now = DateTime(2026, 9, 22, 12);
  return MealsCompanion.insert(
    name: _name,
    nameNormalized: const drift.Value(_name),
    proteinType: ProteinType.chicken,
    carbsType: CarbsType.rice,
    category: MealCategory.egyptianTraditional,
    prepTime: 45,
    createdAt: drift.Value(now),
    updatedAt: drift.Value(now),
    cloudId: drift.Value(cloudId),
    notes: drift.Value(notes),
  );
}

void main() {
  final strings = const AppStrings(Locale('ar'));
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('downloadMeal copies the cloud notes so the fresh row starts in sync',
      () async {
    final cloud = _cloudMeal();
    final id = await container
        .read(discoveryControllerProvider.notifier)
        .downloadMeal(cloud);
    expect(id, isNotNull);

    final row = (await db.mealsDao.getMealById(id!))!;
    expect(row.notes?.trim(), _notes);
    expect(mealCloudDiffs(row, cloud, strings), isEmpty);
  });

  test('"Update from cloud" clears a notes-only difference', () async {
    final localId = await db.mealsDao.insertMeal(_localRow(notes: null));
    final cloud = _cloudMeal();

    final before = (await db.mealsDao.getMealById(localId))!;
    expect(
      mealCloudDiffs(before, cloud, strings).map((d) => d.field),
      contains(strings.notesLabel),
      reason: 'a notes-only diff must flag the mark orange in the first place',
    );

    await container
        .read(discoveryControllerProvider.notifier)
        .updateMeal(localId, cloud);

    final after = (await db.mealsDao.getMealById(localId))!;
    expect(mealCloudDiffs(after, cloud, strings), isEmpty);
  });
}
