import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:daily_meal/core/database/app_database.dart';

void main() {
  group('Transactions and undo by id [6] - restored', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('rapid 2 logs + undo by id - only deletes specific id', () async {
      final mealId1 = await db.mealsDao.insertMeal(
        MealsCompanion(
          name: const Value('Rapid Meal 1'),
          proteinType: const Value(ProteinType.beef),
          carbsType: const Value(CarbsType.pasta),
          category: const Value(MealCategory.ovenBaked),
          prepTime: const Value(40),
        ),
      );

      final mealId2 = await db.mealsDao.insertMeal(
        MealsCompanion(
          name: const Value('Rapid Meal 2'),
          proteinType: const Value(ProteinType.chicken),
          carbsType: const Value(CarbsType.rice),
          category: const Value(MealCategory.egyptianTraditional),
          prepTime: const Value(30),
        ),
      );

      final id1 = await db.mealHistoryDao.logMeal(
        mealId: mealId1,
        mealName: 'Rapid Meal 1',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.pasta,
        cookedAt: DateTime.now(),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final id2 = await db.mealHistoryDao.logMeal(
        mealId: mealId2,
        mealName: 'Rapid Meal 2',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        cookedAt: DateTime.now(),
      );

      var history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, greaterThanOrEqualTo(2));
      expect(history.any((h) => h.id == id1), true);
      expect(history.any((h) => h.id == id2), true);

      await db.mealHistoryDao.deleteHistoryEntry(id1);

      history = await db.mealHistoryDao.getAllHistory();
      expect(history.any((h) => h.id == id1), false, reason: 'id1 should be deleted');
      expect(history.any((h) => h.id == id2), true, reason: 'id2 should still exist - undo must delete by id not last row');

      await db.mealHistoryDao.deleteHistoryEntry(id2);
      history = await db.mealHistoryDao.getAllHistory();
      expect(history.any((h) => h.id == id2), false);
    });

    test('transaction logMeal + update preserves both', () async {
      final mealId = await db.mealsDao.insertMeal(
        MealsCompanion(
          name: const Value('Transaction Test Meal'),
          proteinType: const Value(ProteinType.chicken),
          carbsType: const Value(CarbsType.rice),
          category: const Value(MealCategory.egyptianTraditional),
          prepTime: const Value(30),
        ),
      );

      final historyId = await db.transaction(() async {
        final id = await db.mealHistoryDao.logMeal(
          mealId: mealId,
          mealName: 'Transaction Test Meal',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedAt: DateTime.now(),
        );
        await db.mealsDao.updateMealCompanion(
          mealId,
          const MealsCompanion(updatedAt: Value.absent()),
        );
        return id;
      });

      final history = await db.mealHistoryDao.getAllHistory();
      expect(history.any((h) => h.id == historyId), true);
    });
  });
}
