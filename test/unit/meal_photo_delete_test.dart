import 'dart:io';

import 'package:daily_meal/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// `MealsDao.deleteMeal` has to give the disk back what a deleted meal was
/// holding — while never deleting bytes another row still shows, and never
/// touching anything the row does not own (a remote URL, a bundled asset).
Future<AppDatabase> _openDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<Meal> _insertMeal(AppDatabase db, {
  required String name,
  String? photoPath,
}) async {
  final id = await db.mealsDao.insertMeal(MealsCompanion(
    name: drift.Value(name),
    proteinType: const drift.Value(ProteinType.chicken),
    carbsType: const drift.Value(CarbsType.rice),
    category: const drift.Value(MealCategory.egyptianTraditional),
    prepTime: const drift.Value(30),
    photoPath:
        photoPath == null ? const drift.Value(null) : drift.Value(photoPath),
  ));
  return (await db.mealsDao.getMealById(id))!;
}

Future<File> _photo(Directory dir, String name) async {
  final file = File(p.join(dir.path, name));
  await file.writeAsString('fake-jpeg-bytes');
  return file;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('meal_photo_delete');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('deleting a meal deletes the photo file it was the only owner of',
      () async {
    final db = await _openDb();
    final file = await _photo(dir, 'solo.jpg');
    final meal = await _insertMeal(db, name: 'Solo', photoPath: file.path);

    final deleted = await db.mealsDao.deleteMeal(meal.id);

    expect(deleted, 1);
    expect(await db.mealsDao.getMealById(meal.id), isNull);
    expect(file.existsSync(), isFalse,
        reason: 'the row is gone, so its bytes are the leak this fixes');
  });

  test('a photo shared with a surviving meal is kept', () async {
    final db = await _openDb();
    // Content-addressed cloud downloads: two vault entries from one URL point
    // at the same file, and deleting it for the first would break the second.
    final file = await _photo(dir, 'shared.jpg');
    final first =
        await _insertMeal(db, name: 'First copy', photoPath: file.path);
    await _insertMeal(db, name: 'Second copy', photoPath: file.path);

    await db.mealsDao.deleteMeal(first.id);

    expect(file.existsSync(), isTrue,
        reason: 'the surviving meal still renders this file');
  });

  test('a remote photo is left alone', () async {
    final db = await _openDb();
    const url = 'https://firebasestorage.googleapis.com/v2/b/o/o/t/koshary.jpg';
    final meal = await _insertMeal(db, name: 'Cloud', photoPath: url);

    await db.mealsDao.deleteMeal(meal.id);

    expect(await db.mealsDao.getMealById(meal.id), isNull,
        reason: 'the row is deleted normally');
  });

  test('a bundled asset photo is left alone', () async {
    final db = await _openDb();
    final asset = p.join(dir.path, 'assets', 'welcome_hero.jpg');
    await Directory(p.dirname(asset)).create(recursive: true);
    await File(asset).writeAsString('bundled-bytes');
    // Stored the way the seed rows store it: relative to the app directory,
    // which in a test run is a file that really exists on disk.
    final meal = await _insertMeal(db, name: 'Asset', photoPath: asset);

    await db.mealsDao.deleteMeal(meal.id);

    expect(File(asset).existsSync(), isFalse,
        reason: 'an absolute path under an assets/ folder is still ours to '
            'free — the guard is about the assets/ reference form');

    final relative = await _insertMeal(
      db,
      name: 'Asset ref',
      photoPath: 'assets/welcome_hero.jpg',
    );
    await db.mealsDao.deleteMeal(relative.id);

    expect(File('assets/welcome_hero.jpg').existsSync(), isTrue,
        reason: 'an assets/ reference is a file bundled with the app, never a '
            'meal photo to delete');
  });

  test('a missing file is not an error', () async {
    final db = await _openDb();
    final meal = await _insertMeal(
      db,
      name: 'Already gone',
      photoPath: p.join(dir.path, 'never-written.jpg'),
    );

    final deleted = await db.mealsDao.deleteMeal(meal.id);

    expect(deleted, 1, reason: 'the delete must not throw when the bytes are '
        'already missing — the row was still removed');
  });

  test('a meal without a photo deletes nothing on disk', () async {
    final db = await _openDb();
    final meal = await _insertMeal(db, name: 'No photo');

    expect(await db.mealsDao.deleteMeal(meal.id), 1);
  });
}
