import 'dart:io';

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/services/orphan_image_sweeper.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

// Regression guard for the data-loss bug: when the DB photo-path query fails,
// the sweep must abort instead of treating every photo on disk as an orphan.

Future<Directory> _createImagesDir(Directory docs) async {
  final images = Directory(p.join(docs.path, 'meal_images'));
  await images.create(recursive: true);
  return images;
}

Future<File> _createFile(
  Directory dir,
  String name, {
  required Duration age,
}) async {
  final file = File(p.join(dir.path, name));
  await file.writeAsString('fake-jpeg-bytes-$name');
  file.setLastModifiedSync(DateTime.now().subtract(age));
  return file;
}

Future<void> _insertMealWithPhoto(AppDatabase db, String? photoPath) async {
  await db.mealsDao.insertMeal(
    MealsCompanion.insert(
      name: 'sweep-test-meal-${DateTime.now().microsecondsSinceEpoch}',
      proteinType: ProteinType.chicken,
      carbsType: CarbsType.rice,
      category: MealCategory.egyptianTraditional,
      prepTime: 30,
      photoPath:
          photoPath == null ? const drift.Value(null) : drift.Value(photoPath),
    ),
  );
}

/// An [AppDatabase] whose underlying SQLite handle is destroyed after
/// construction, so every query throws like a locked/corrupt database.
/// Closing may itself fail (the handle is gone), so the teardown is guarded.
AppDatabase _failingDatabase() {
  final raw = sqlite3.openInMemory();
  final db = AppDatabase(NativeDatabase.opened(raw));
  raw.dispose();
  addTearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });
  return db;
}

void main() {
  late Directory docsDir;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('orphan_sweep_docs');
  });

  tearDown(() async {
    if (await docsDir.exists()) {
      await docsDir.delete(recursive: true);
    }
  });

  group('DB failure aborts the sweep', () {
    test('getDbPhotoPaths returns null when the database query fails',
        () async {
      final db = _failingDatabase();

      final paths = await OrphanImageSweeper.getDbPhotoPaths(db);
      expect(paths, isNull,
          reason: 'a failed DB query must surface as null, never an empty set');
    });

    test('runSweep aborts and deletes nothing when DB resolution returns null',
        () async {
      final images = await _createImagesDir(docsDir);
      final oldOrphan = await _createFile(
        images,
        'old_orphan.jpg',
        age: const Duration(hours: 2),
      );
      final recent = await _createFile(
        images,
        'recent.jpg',
        age: const Duration(minutes: 5),
      );

      await OrphanImageSweeper.runSweep(
        docsPath: docsDir.path,
        resolveDbPaths: () async => null,
      );

      expect(await File(oldOrphan.path).exists(), isTrue,
          reason: 'DB failure must never delete files');
      expect(await File(recent.path).exists(), isTrue);
    });

    test('end-to-end: failing DB leaves every photo on disk untouched',
        () async {
      final images = await _createImagesDir(docsDir);
      final files = <File>[];
      for (var i = 0; i < 5; i++) {
        files.add(await _createFile(images, 'meal_$i.jpg',
            age: const Duration(hours: 3)));
      }

      final db = _failingDatabase();

      await OrphanImageSweeper.runSweep(
        docsPath: docsDir.path,
        resolveDbPaths: () => OrphanImageSweeper.getDbPhotoPaths(db),
      );

      for (final f in files) {
        expect(await File(f.path).exists(), isTrue,
            reason: 'sweep must abort when the DB cannot be read');
      }
    });
  });

  group('successful DB query drives a correct sweep', () {
    test(
        'old unreferenced files are deleted; '
        'referenced and recent files survive', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final images = await _createImagesDir(docsDir);
      final referencedByFullPath = await _createFile(
        images,
        'referenced_full.jpg',
        age: const Duration(hours: 2),
      );
      final referencedByBasename = await _createFile(
        images,
        'referenced_basename.jpg',
        age: const Duration(hours: 2),
      );
      final oldOrphan = await _createFile(
        images,
        'old_orphan.jpg',
        age: const Duration(hours: 2),
      );
      final youngOrphan = await _createFile(
        images,
        'young_orphan.jpg',
        age: const Duration(minutes: 10),
      );

      await _insertMealWithPhoto(db, referencedByFullPath.path);
      // A DB row pointing at another directory whose basename matches the
      // on-disk file must protect it via the basename fallback.
      await _insertMealWithPhoto(
        db,
        p.join(p.dirname(p.dirname(images.path)), 'elsewhere',
            'referenced_basename.jpg'),
      );

      await OrphanImageSweeper.runSweep(
        docsPath: docsDir.path,
        resolveDbPaths: () => OrphanImageSweeper.getDbPhotoPaths(db),
      );

      expect(await File(oldOrphan.path).exists(), isFalse,
          reason: 'unreferenced file older than 1h must be deleted');
      expect(await File(youngOrphan.path).exists(), isTrue,
          reason: 'unreferenced file newer than 1h must survive');
      expect(await File(referencedByFullPath.path).exists(), isTrue,
          reason: 'file referenced by full path must survive');
      expect(await File(referencedByBasename.path).exists(), isTrue,
          reason: 'file referenced by basename must survive');
    });

    test('getDbPhotoPaths collects photo paths from the DB', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await _insertMealWithPhoto(db, '/data/user/0/app/files/x.jpg');
      await _insertMealWithPhoto(db, null); // meal without photo
      await _insertMealWithPhoto(db, ''); // empty photo ignored

      final paths = await OrphanImageSweeper.getDbPhotoPaths(db);
      expect(paths, isNotNull);
      expect(paths, contains('/data/user/0/app/files/x.jpg'));
      expect(paths!.where((e) => e.isEmpty), isEmpty);
    });
  });

  group('blast-radius safeguards in the sweeper itself', () {
    test('empty DB reference set with files on disk aborts mass deletion',
        () async {
      final images = await _createImagesDir(docsDir);
      final oldOrphan = await _createFile(
        images,
        'old_orphan.jpg',
        age: const Duration(hours: 2),
      );

      await OrphanImageSweeper.sweepInIsolate(docsDir.path, <String>{});

      expect(await File(oldOrphan.path).exists(), isTrue,
          reason: 'zero DB references must never wipe an existing library');
    });

    test('deletion batch above maxDeletionsPerSweep aborts the whole sweep',
        () async {
      final images = await _createImagesDir(docsDir);
      final files = <File>[];
      final count = OrphanImageSweeper.maxDeletionsPerSweep + 1;
      for (var i = 0; i < count; i++) {
        files.add(await _createFile(images, 'orphan_$i.jpg',
            age: const Duration(hours: 2)));
      }

      await OrphanImageSweeper.sweepInIsolate(
        docsDir.path,
        {'/somewhere/kept.jpg'},
      );

      for (final f in files) {
        expect(await File(f.path).exists(), isTrue,
            reason: 'oversized orphan batch must trigger abort, not a wipe');
      }
    });

    test('sweep is a no-op when the images directory does not exist',
        () async {
      await expectLater(
        OrphanImageSweeper.sweepInIsolate(docsDir.path, {'a.jpg'}),
        completes,
      );
    });
  });
}
