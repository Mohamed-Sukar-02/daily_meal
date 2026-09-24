import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'reachability_service.dart';

/// Downloads cloud-vault meal photos onto device storage so the vault works
/// fully offline.
///
/// Why this exists: cloud-sourced meals used to store only the Firebase
/// Storage URL in `Meals.photoPath`, and `Image.network` caches in memory
/// only — so every photo vanished the moment the device went offline. Now the
/// bytes live next to the user's own picked photos in
/// `<documents>/meal_images/` and the row points at the local file.
///
/// Every entry point is best-effort and idempotent:
///  * same URL ⇒ same file name, so repeat runs never duplicate a download;
///  * on failure the original URL is kept (the UI still works online) and the
///    startup backfill retries later;
///  * the `OrphanImageSweeper` is unaffected: rows reference these files, and
///    an obsolete file (image changed upstream) is swept after its 1h grace.
class MealImageLocalizer {
  MealImageLocalizer._();
  static final MealImageLocalizer instance = MealImageLocalizer._();

  static const Duration _downloadTimeout = Duration(seconds: 12);

  /// URLs currently being downloaded — prevents two sync paths from fetching
  /// the same photo concurrently.
  final Set<String> _inFlight = {};

  /// Same classification rule as `MealImageResolver.isRemote`, duplicated here
  /// so this service layer stays free of widget imports.
  static bool isRemoteUrl(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  /// Localises a single photo reference:
  ///  * local path / asset / null / empty  → returned unchanged;
  ///  * remote URL already downloaded      → the existing file's path;
  ///  * remote URL                         → downloaded, then the file's path;
  ///  * download failure (offline, 404…)   → the original URL (retry happens
  ///    via [backfillVaultImages] on a later launch).
  Future<String?> localize(String? photoPath) async {
    final url = photoPath?.trim() ?? '';
    if (url.isEmpty || !isRemoteUrl(url)) return photoPath;

    try {
      final target = await _targetFile(url);
      if (await target.exists() && await target.length() > 0) {
        return target.path;
      }
      if (!_inFlight.add(url)) {
        // Another sync path is fetching this URL right now; keep the URL and
        // let backfill pick it up once the file lands.
        return photoPath;
      }
      try {
        final response = await http.get(Uri.parse(url)).timeout(_downloadTimeout);
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await target.create(recursive: true);
          await target.writeAsBytes(response.bodyBytes, flush: true);
          return target.path;
        }
        debugPrint('[MealImageLocalizer] HTTP ${response.statusCode} for $url');
      } finally {
        _inFlight.remove(url);
      }
    } catch (e) {
      debugPrint('[MealImageLocalizer] localize failed for $url: $e');
    }
    return photoPath;
  }

  /// One-shot startup pass: any meal still holding a remote `photoPath` gets
  /// its photo downloaded and the row rewritten to the local file. Skips
  /// silently when offline — launches are cheap and this is idempotent.
  Future<void> backfillVaultImages(AppDatabase db) async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;

      final meals = await db.mealsDao.getAllMeals();
      final remoteMeals = meals
          .where((m) => m.photoPath != null && isRemoteUrl(m.photoPath!))
          .toList();
      if (remoteMeals.isEmpty) return;

      final reachable = await ReachabilityService.instance
          .isInternetReachable(timeout: const Duration(seconds: 2));
      if (!reachable) {
        debugPrint('[MealImageLocalizer] offline — backfill skipped '
            '(${remoteMeals.length} remote photo(s) pending).');
        return;
      }

      debugPrint('[MealImageLocalizer] backfilling ${remoteMeals.length} remote photo(s)…');
      for (final meal in remoteMeals) {
        try {
          final localPath = await localize(meal.photoPath);
          final stillRemote = localPath == null || isRemoteUrl(localPath);
          if (!stillRemote && localPath != meal.photoPath) {
            await db.mealsDao.updateMealCompanion(
              meal.id,
              MealsCompanion(photoPath: Value(localPath)),
            );
            debugPrint('[MealImageLocalizer] "${meal.name}" → local photo.');
          }
        } catch (e) {
          debugPrint('[MealImageLocalizer] backfill failed for meal ${meal.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('[MealImageLocalizer] backfill sweep failed: $e');
    }
  }

  /// Deterministic target file for a URL: same URL always maps to the same
  /// name (content-hash key), inside the same directory the quick-add sheet
  /// uses for user-picked photos.
  Future<File> _targetFile(String url) async {
    final docs = await getApplicationDocumentsDirectory();
    final hash = sha1.convert(url.codeUnits).toString();
    return File('${docs.path}/meal_images/img_$hash${_extensionOf(url)}');
  }

  /// Firebase URLs carry query strings (`?alt=media&token=…`), so the
  /// extension must come from the URL path, not the raw string.
  static String _extensionOf(String url) {
    try {
      final path = Uri.parse(url).path.toLowerCase();
      final dot = path.lastIndexOf('.');
      if (dot != -1) {
        final ext = path.substring(dot);
        const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
        if (allowed.contains(ext)) return ext;
      }
    } catch (_) {}
    return '.jpg';
  }
}
