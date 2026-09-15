import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

class OrphanImageSweeper {
  static Future<void> sweepAtStartup(AppDatabase db) async {
    try {
      final dbPaths = await _getDbPhotoPaths(db);
      final docsPath = await _getDocsPath();

      await Isolate.run(() async {
        await _sweepInIsolate(docsPath, dbPaths);
      });
    } catch (e) {
      debugPrint('Orphan sweep failed: $e');
    }
  }

  static Future<Set<String>> _getDbPhotoPaths(AppDatabase db) async {
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
      return <String>{};
    }
  }

  static Future<String> _getDocsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<void> _sweepInIsolate(String docsPath, Set<String> dbPaths) async {
    final imagesDir = Directory('$docsPath/meal_images');
    if (!await imagesDir.exists()) return;

    final now = DateTime.now();
    const threshold = Duration(hours: 1);

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
      final files = await imagesDir.list().toList();
      for (final entity in files) {
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

          await entity.delete();
          debugPrint('Orphan image deleted: $basename (age: ${age.inMinutes}m)');
        } catch (e) {
          debugPrint('Failed to delete orphan $basename: $e');
        }
      }
    } catch (e) {
      debugPrint('Orphan sweep isolate error: $e');
    }
  }
}
