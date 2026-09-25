import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/providers/discovery_providers.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoveryNotifier.downloadAsNew atomicity', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedOldLinkedMeal() {
      return db.mealsDao.insertMeal(MealsCompanion(
        name: const Value('Old Linked Meal'),
        proteinType: const Value(ProteinType.chicken),
        carbsType: const Value(CarbsType.rice),
        category: const Value(MealCategory.egyptianTraditional),
        prepTime: const Value(30),
        cloudId: const Value('cloud-old'),
      ));
    }

    final cloudMeal = CloudMeal(
      id: 'cloud-new',
      name: 'Cloud Koshary',
      imageUrl: 'https://example.com/koshary.jpg',
      proteinType: 'meatless',
      carbsType: 'rice',
      category: 'tabeekh',
      prepTimeMinutes: 25,
      createdAt: DateTime(2026),
    );

    test('image localization failure leaves the old meal cloudId intact',
        () async {
      final oldId = await seedOldLinkedMeal();
      final baseline = (await db.mealsDao.getAllMeals()).length;
      final notifier = DiscoveryNotifier(
        db.mealsDao,
        db,
        localizeImage: (_) async => throw Exception('network down'),
      );

      await expectLater(
        notifier.downloadAsNew(oldId, cloudMeal),
        throwsA(isA<Exception>()),
      );

      final meals = await db.mealsDao.getAllMeals();
      final old = meals.firstWhere((m) => m.id == oldId);
      expect(old.cloudId, 'cloud-old',
          reason: 'failed download must not detach the old meal');
      expect(meals.length, baseline, reason: 'no new row on failure');
      expect(notifier.state, isA<AsyncError<void>>());
    });

    test('success detaches old cloudId and inserts the new meal', () async {
      final oldId = await seedOldLinkedMeal();
      final baseline = (await db.mealsDao.getAllMeals()).length;
      final notifier = DiscoveryNotifier(
        db.mealsDao,
        db,
        localizeImage: (url) async => '/local/koshary.jpg',
      );

      await notifier.downloadAsNew(oldId, cloudMeal);

      final meals = await db.mealsDao.getAllMeals();
      expect(meals.length, baseline + 1);
      final old = meals.firstWhere((m) => m.id == oldId);
      expect(old.cloudId, isNull,
          reason: 'old meal must lose its cloud link after success');
      final fresh = meals.firstWhere((m) => m.name == 'Cloud Koshary');
      expect(fresh.cloudId, 'cloud-new');
      expect(fresh.photoPath, '/local/koshary.jpg');
      expect(notifier.state, isA<AsyncData<void>>());
    });
  });
}
