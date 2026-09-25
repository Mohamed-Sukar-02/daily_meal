import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

class OrphanImageSweeper {
  /// Blast-radius cap: a single sweep never deletes more than this many
  /// files. A mass-orphan report almost always means broken references, not
  /// a genuinely abandoned library, so we abort and leave the data intact.
  static const int maxDeletionsPerSweep = 100;

  static Future<void> sweepAtStartup(AppDatabase db) async {
    try {
      final docsPath = await _getDocsPath();
      await runSweep(
        docsPath: docsPath,
        resolveDbPaths: () => getDbPhotoPaths(db),
      );
    } catch (e) {
      debugPrint('Orphan sweep failed: $e');
    }
  }

  /// Shared entry point (production and tests): resolves the referenced
  /// photo paths and only reaches the filesystem when resolution succeeded.
  @visibleForTesting
  static Future<void> runSweep({
    required String docsPath,
    required Future<Set<String>?> Function() resolveDbPaths,
  }) async {
    final dbPaths = await resolveDbPaths();
    if (dbPaths == null) {
      debugPrint(
        'Orphan sweep aborted: DB photo paths unavailable — skipping deletion',
      );
      return;
    }
    await Isolate.run(() async {
      await sweepInIsolate(docsPath, dbPaths);
    });
  }

  /// Returns the set of DB-referenced photo paths, or `null` when the
  /// database could not be read. `null` must abort the sweep: an empty set
  /// from a failed query would make every photo on disk look like an orphan.
  @visibleForTesting
  static Future<Set<String>?> getDbPhotoPaths(AppDatabase db) async {
    try {
      final meals = await db.mealsDao.getAllMeals();
      final paths = <String>{};
      for (final m in meals) {
        final p = m.photoPath;
        if (p != null && p.isNotEmpty) {
          paths.add(p);
          try {
            paths.add(File(p).uri.pathSegments.last);
          } catch (_) {}
        }
      }
      return paths;
    } catch (e) {
      debugPrint('Failed to get DB photo paths: $e');
      return null;
    }
  }

  static Future<String> _getDocsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  @visibleForTesting
  static Future<void> sweepInIsolate(String docsPath, Set<String> dbPaths) async {
    final imagesDir = Directory('$docsPath/meal_images');
    if (!await imagesDir.exists()) return;

    final now = DateTime.now();
    const threshold = Duration(hours: 1);

    // A DB with zero photo references cannot justify wiping the library:
    // an unreadable/failed reference set is indistinguishable from a truly
    // empty one here, so refuse to delete anything while files exist.
    if (dbPaths.isEmpty) {
      if (!await imagesDir.list().isEmpty) {
        debugPrint(
          'Orphan sweep aborted: DB references zero photos but files exist '
          'in ${imagesDir.path} — refusing mass delete',
        );
        return;
      }
      return;
    }

    final referencedBasenames = <String>{};
    final referencedFullPaths = <String>{};
    for (final p in dbPaths) {
      referencedFullPaths.add(p);
      try {
        final basename = p.split('/').last.split('\\').last;
        if (basename.isNotEmpty) referencedBasenames.add(basename);
      } catch (_) {}
    }

    try {
      final candidates = <File>[];
      await for (final entity in imagesDir.list()) {
        if (entity is! File) continue;

        final filePath = entity.path;
        final basename = filePath.split('/').last.split('\\').last;

        if (referencedBasenames.contains(basename) || referencedFullPaths.contains(filePath)) {
          continue;
        }

        try {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age < threshold) continue;
          candidates.add(entity);
        } catch (e) {
          debugPrint('Failed to stat orphan candidate $basename: $e');
        }
      }

      if (candidates.length > maxDeletionsPerSweep) {
        debugPrint(
          'Orphan sweep aborted: ${candidates.length} orphan candidates '
          'exceed blast-radius limit ($maxDeletionsPerSweep) — deleting nothing',
        );
        return;
      }

      for (final file in candidates) {
        final basename = file.path.split('/').last.split('\\').last;
        try {
          await file.delete();
          debugPrint('Orphan image deleted: $basename');
        } catch (e) {
          debugPrint('Failed to delete orphan $basename: $e');
        }
      }
    } catch (e) {
      debugPrint('Orphan sweep isolate error: $e');
    }
  }
}
