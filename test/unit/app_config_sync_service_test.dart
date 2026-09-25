import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/services/app_config_sync_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Starter-meal sync identity: the cloud document id (cloudId) is the primary
// key; the trimmed name is a legacy fallback only. A rename in the cloud must
// update — never delete — the local meal (deleting it orphans meal_history
// via ON DELETE SET NULL and destroys favourites). An empty cloud response is
// treated as a glitch, not as an emptied catalog. Meals genuinely removed from
// the cloud starter catalog are de-listed (isStarterMeal = false), not deleted.

RemoteStarterDoc _doc(String id, String name, [Map<String, dynamic>? extra]) =>
    RemoteStarterDoc(id: id, data: {'name': name, ...?extra});

Future<Meal> _seedStarter(
  AppDatabase db,
  String name, {
  String? cloudId,
  bool isFavorite = false,
  String? notes,
}) async {
  final now = DateTime(2026, 9, 20, 12);
  final id = await db.mealsDao.insertMeal(
    MealsCompanion.insert(
      name: name,
      proteinType: ProteinType.chicken,
      carbsType: CarbsType.rice,
      category: MealCategory.egyptianTraditional,
      prepTime: 45,
      createdAt: Value(now),
      updatedAt: Value(now),
      isFavorite: Value(isFavorite),
      isStarterMeal: const Value(true),
      cloudId: Value(cloudId),
      notes: Value(notes),
    ),
  );
  return (await db.mealsDao.getMealById(id))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppConfigSyncService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    service = AppConfigSyncService.instance;
  });

  tearDown(() async {
    service.remoteStarterDocsFetcher = null;
    await db.close();
  });

  group('SystemDefaults model', () {
    test('default values match expected application baselines', () {
      const defaults = SystemDefaults();
      expect(defaults.cooldownDays, 14);
      expect(defaults.chickenCooldownDays, 2);
      expect(defaults.beefCooldownDays, 2);
      expect(defaults.fishCooldownDays, 4);
      expect(defaults.meatlessCooldownDays, 0);
      expect(defaults.notificationHour, 12);
      expect(defaults.notificationMinute, 0);
      expect(defaults.minAppVersion, isNull);
      expect(defaults.announcement, isNull);
    });

    test('parses from Firestore map with partial or full overrides', () {
      final map = {
        'cooldownDays': 21,
        'chickenCooldownDays': 8,
        'beefCooldownDays': 12,
        'fishCooldownDays': 6,
        'meatlessCooldownDays': 2,
        'notificationHour': 13,
        'notificationMinute': 30,
        'minAppVersion': '1.1.0',
        'announcement': 'رمضان كريم',
      };

      final parsed = SystemDefaults.fromMap(map);
      expect(parsed.cooldownDays, 21);
      expect(parsed.chickenCooldownDays, 8);
      expect(parsed.beefCooldownDays, 12);
      expect(parsed.fishCooldownDays, 6);
      expect(parsed.meatlessCooldownDays, 2);
      expect(parsed.notificationHour, 13);
      expect(parsed.notificationMinute, 30);
      expect(parsed.minAppVersion, '1.1.0');
      expect(parsed.announcement, 'رمضان كريم');
    });

    test('handles missing or malformed fields safely with fallbacks', () {
      final map = <String, dynamic>{
        'cooldownDays': null,
        'invalidField': 999,
      };

      final parsed = SystemDefaults.fromMap(map);
      expect(parsed.cooldownDays, 14);
      expect(parsed.chickenCooldownDays, 2);
      expect(parsed.meatlessCooldownDays, 0);
    });
  });

  group('AppConfigSyncService cache & offline', () {
    test('getCachedDefaults returns fallback defaults when nothing cached', () async {
      final defaults = await AppConfigSyncService.instance.getCachedDefaults();
      expect(defaults.cooldownDays, 14);
      expect(defaults.chickenCooldownDays, 2);
      expect(defaults.meatlessCooldownDays, 0);
    });

    test('syncWithFirebase returns cached defaults safely during test/offline', () async {
      final result = await AppConfigSyncService.instance.syncWithFirebase();
      expect(result.cooldownDays, 14);
      expect(result.chickenCooldownDays, 2);
    });
  });

  group('Starter meals sync identity', () {
    test('cloud rename updates the local meal via cloudId and keeps history intact', () async {
      final meal = await _seedStarter(db, 'Kofta Mashwy', cloudId: 'doc-1', isFavorite: true);
      final historyId = await db.mealHistoryDao.logCookedMeal(meal);

      service.remoteStarterDocsFetcher = () async => [
            _doc('doc-1', 'Kofta bil Sinnyora', {
              'proteinType': 'beef',
              'shortName': 'كفتة',
              'prepTimeMinutes': 60,
            }),
          ];

      // Auto-sync (isManual = false) used to DELETE name-mismatched meals.
      await service.syncStarterMealsForTest(db, isManual: false);

      final after = await db.mealsDao.getMealById(meal.id);
      expect(after, isNotNull, reason: 'a cloud rename must never delete the local meal');
      expect(after!.name, 'Kofta bil Sinnyora');
      expect(after.cloudId, 'doc-1');
      expect(after.proteinType, ProteinType.beef);
      expect(after.shortName, 'كفتة');
      expect(after.prepTime, 60);
      expect(after.isStarterMeal, isTrue);
      expect(after.isFavorite, isTrue, reason: 'local favourites are preserved');

      final history = await (db.select(db.mealHistory)..where((t) => t.id.equals(historyId))).getSingle();
      expect(history.mealId, meal.id, reason: 'history must not be orphaned (SET NULL)');
    });

    test('empty cloud response does not wipe or de-list local starter meals', () async {
      // AppDatabase seeds ~20 starter meals on first open; count a baseline
      // instead of hard-coding it.
      await _seedStarter(db, 'Foul Mudammas', cloudId: 'doc-1');
      await _seedStarter(db, 'Taameya', cloudId: 'doc-2');
      final before = await db.mealsDao.getStarterMeals();

      service.remoteStarterDocsFetcher = () async => [];

      await service.syncStarterMealsForTest(db, isManual: false);

      final after = await db.mealsDao.getStarterMeals();
      expect(after, hasLength(before.length));
      expect(after.map((m) => m.name), containsAll(['Foul Mudammas', 'Taameya']));
    });

    test('meal removed from the cloud catalog is de-listed, not deleted', () async {
      final meal = await _seedStarter(db, 'Hamburger', cloudId: 'doc-9', notes: 'سر التتبيلة');
      final historyId = await db.mealHistoryDao.logCookedMeal(meal);

      service.remoteStarterDocsFetcher = () async => [
            _doc('doc-10', 'Shawarma'), // unrelated, but keeps the response non-empty
          ];

      await service.syncStarterMealsForTest(db, isManual: false);

      final after = await db.mealsDao.getMealById(meal.id);
      expect(after, isNotNull, reason: 'the row itself must survive');
      expect(after!.isStarterMeal, isFalse);
      expect(after.notes, 'سر التتبيلة');

      final history = await (db.select(db.mealHistory)..where((t) => t.id.equals(historyId))).getSingle();
      expect(history.mealId, meal.id);

      final starters = await db.mealsDao.getStarterMeals();
      expect(starters.map((m) => m.name), isNot(contains('Hamburger')));
      expect(starters.map((m) => m.name), contains('Shawarma'));
    });

    test('legacy starter without cloudId still matches by trimmed name and links the doc', () async {
      final meal = await _seedStarter(db, '  Molokheya  '); // pre-cloudId row

      service.remoteStarterDocsFetcher = () async => [
            _doc('doc-7', 'Molokheya', {'carbsType': 'bread'}),
          ];

      await service.syncStarterMealsForTest(db, isManual: false);

      final starters = await db.mealsDao.getStarterMeals();
      expect(starters, hasLength(1), reason: 'no duplicate insert for a legacy name match');
      expect(starters.single.id, meal.id);
      expect(starters.single.cloudId, 'doc-7');
      expect(starters.single.carbsType, CarbsType.bread);
    });

    test('user deletion blacklist prevents re-insertion of starter meals', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('deleted_starter_meals', ['doc-8']);

      service.remoteStarterDocsFetcher = () async => [
            _doc('doc-8', 'Removed By User'),
            _doc('doc-11', 'Still Available'),
          ];

      await service.syncStarterMealsForTest(db, isManual: false);

      final all = await db.mealsDao.getAllMeals();
      expect(all.map((m) => m.name), isNot(contains('Removed By User')));
      expect(all.map((m) => m.name), contains('Still Available'));
      expect(prefs.getStringList('deleted_starter_meals'), contains('doc-8'));
    });
  });
}
