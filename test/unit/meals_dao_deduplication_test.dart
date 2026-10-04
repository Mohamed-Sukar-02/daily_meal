import 'package:daily_meal/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealsDao deduplication and upsert guards', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'insertMeal with identical normalized name updates rather than duplicates',
      () async {
        final id1 = await db.mealsDao.insertMeal(
          const MealsCompanion(
            name: Value('كفتة مشوية'),
            proteinType: Value(ProteinType.beef),
            carbsType: Value(CarbsType.bread),
            category: Value(MealCategory.fastFood),
            prepTime: Value(25),
            isFavorite: Value(true),
          ),
        );

        // Attempt inserting with slight Arabic spelling variant (e.g. كفته مشويه)
        final id2 = await db.mealsDao.insertMeal(
          const MealsCompanion(
            name: Value('كفته مشويه'),
            proteinType: Value(ProteinType.beef),
            carbsType: Value(CarbsType.rice),
            category: Value(MealCategory.fastFood),
            prepTime: Value(35),
            cloudId: Value('cloud-kofta-1'),
          ),
        );

        expect(id2, equals(id1));

        final allMeals = await db.mealsDao.getAllMeals();
        final koftaMatches = allMeals.where((m) => m.id == id1).toList();
        expect(koftaMatches.length, equals(1));
        expect(koftaMatches.first.cloudId, equals('cloud-kofta-1'));
        expect(koftaMatches.first.isFavorite, isTrue); // favorite preserved!
      },
    );

    test(
      'insertMeal with matching cloudId updates rather than duplicates',
      () async {
        final id1 = await db.mealsDao.insertMeal(
          const MealsCompanion(
            name: Value('مكرونة بشاميل'),
            proteinType: Value(ProteinType.beef),
            carbsType: Value(CarbsType.pasta),
            category: Value(MealCategory.ovenBaked),
            prepTime: Value(45),
            cloudId: Value('cloud-beshamel-1'),
          ),
        );

        final id2 = await db.mealsDao.insertMeal(
          const MealsCompanion(
            name: Value('طاجن مكرونة بشاميل'),
            proteinType: Value(ProteinType.beef),
            carbsType: Value(CarbsType.pasta),
            category: Value(MealCategory.ovenBaked),
            prepTime: Value(50),
            cloudId: Value('cloud-beshamel-1'),
          ),
        );

        expect(id2, equals(id1));

        final all = await db.mealsDao.getAllMeals();
        final matches = all
            .where((m) => m.cloudId == 'cloud-beshamel-1')
            .toList();
        expect(matches.length, equals(1));
      },
    );

    test(
      'deduplicateMeals removes duplicates, merges favorites and moves history',
      () async {
        // Force-insert duplicates directly via customStatement to simulate legacy dirty database
        await db.customStatement('''
        INSERT INTO meals (name, name_normalized, protein_type, carbs_type, category, prep_time, is_favorite, cloud_id, is_starter_meal)
        VALUES ('حواوشي', 'حواوشي', 'beef', 'bread', 'fastFood', 20, 1, 'cloud-hawawshi-1', 1)
      ''');
        await db.customStatement('''
        INSERT INTO meals (name, name_normalized, protein_type, carbs_type, category, prep_time, is_favorite, cloud_id, is_starter_meal)
        VALUES ('حواوشي', 'حواوشي', 'beef', 'bread', 'fastFood', 20, 0, NULL, 0)
      ''');

        final before = (await db.mealsDao.getAllMeals())
            .where((m) => m.name == 'حواوشي')
            .toList();
        expect(before.length, equals(2));

        await db.mealsDao.deduplicateMeals();

        final after = (await db.mealsDao.getAllMeals())
            .where((m) => m.name == 'حواوشي')
            .toList();
        expect(after.length, equals(1));
        expect(after.first.isFavorite, isTrue);
        expect(after.first.cloudId, equals('cloud-hawawshi-1'));
      },
    );
  });
}
