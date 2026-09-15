import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/core/database/app_database.dart';

import 'generated_migrations/schema.dart' as generated;
import 'generated_migrations/schema_v8.dart' as v8;
import 'generated_migrations/schema_v9.dart' as v9;
import 'generated_migrations/schema_v10.dart' as v10;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('Database migrations - SchemaVerifier', () {
    test('v8 -> v9 migration preserves data and adds indexes', () async {
      final connection = await verifier.startAt(8);
      final db = AppDatabase(connection);

      await db.into(db.meals).insert(MealsCompanion.insert(
        name: 'كشري مصري',
        proteinType: ProteinType.legume,
        carbsType: CarbsType.rice,
        category: MealCategory.egyptianTraditional,
        prepTime: 30,
      ));

      await db.into(db.mealHistory).insert(MealHistoryCompanion.insert(
        mealId: const Value(1),
        mealName: 'كشري مصري',
        proteinType: ProteinType.legume,
        carbsType: CarbsType.rice,
        cookedAt: DateTime.now(),
      ));

      await verifier.migrateAndValidate(db, 9);

      final meals = await db.select(db.meals).get();
      expect(meals.length, 1);
      expect(meals.first.name, 'كشري مصري');

      final history = await db.select(db.mealHistory).get();
      expect(history.length, 1);

      await db.close();
    });

    test('v9 -> v10 migration adds name_normalized and backfills', () async {
      final connection = await verifier.startAt(9);
      final db = AppDatabase(connection);

      await db.into(db.meals).insert(MealsCompanion.insert(
        name: 'Koshari',
        proteinType: ProteinType.legume,
        carbsType: CarbsType.rice,
        category: MealCategory.egyptianTraditional,
        prepTime: 30,
      ));

      await verifier.migrateAndValidate(db, 10);

      final meals = await db.select(db.meals).get();
      expect(meals.length, 1);
      expect(meals.first.nameNormalized, isNotNull);
      expect(meals.first.nameNormalized, isNotEmpty);

      await db.close();
    });

    test('v8 -> v10 with 20 meals + 50 history preserves all and fills normalized', () async {
      final connection = await verifier.startAt(8);
      final db = AppDatabase(connection);

      for (int i = 0; i < 20; i++) {
        await db.into(db.meals).insert(MealsCompanion.insert(
          name: 'Meal $i',
          proteinType: ProteinType.values[i % ProteinType.values.length],
          carbsType: CarbsType.values[i % CarbsType.values.length],
          category: MealCategory.values[i % MealCategory.values.length],
          prepTime: 20 + i,
        ));
      }

      for (int i = 0; i < 50; i++) {
        await db.into(db.mealHistory).insert(MealHistoryCompanion.insert(
          mealId: Value((i % 20) + 1),
          mealName: 'Meal ${i % 20}',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedAt: DateTime.now().subtract(Duration(days: i)),
        ));
      }

      await verifier.migrateAndValidate(db, 10);

      final meals = await db.select(db.meals).get();
      expect(meals.length, 20);
      for (final m in meals) {
        expect(m.nameNormalized, isNotNull, reason: 'name_normalized should be filled for ${m.name}');
        expect(m.nameNormalized!.isNotEmpty, true);
      }

      final history = await db.select(db.mealHistory).get();
      expect(history.length, 50, reason: 'No history should be lost during migration');

      await db.close();
    });

    test('migration from v8 to v10 via helper', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 8,
        newVersion: 10,
        createOld: v8.DatabaseAtV8.new,
        createNew: v10.DatabaseAtV10.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) async {
          for (int i = 0; i < 5; i++) {
            batch.insert(oldDb.meals, v8.MealsCompanion.insert(
              name: 'Test $i',
              proteinType: 'chicken',
              carbsType: 'rice',
              category: 'egyptianTraditional',
              prepTime: 30,
            ));
          }
        },
        validateItems: (oldDb, newDb) async {
          final meals = await newDb.select(newDb.meals).get();
          expect(meals.length, greaterThanOrEqualTo(5));
        },
      );
    });
  });
}
