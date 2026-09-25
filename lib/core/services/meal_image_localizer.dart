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
/// Hardening (every rejected download keeps the original URL, so the UI still
/// works online and [backfillVaultImages] retries later):
///  * HTTPS-only — plain `http://` is refused outright;
///  * host allow-list — only trusted image origins may write into app storage
///    (extendable at runtime via [customTrustedHosts] / [hostValidator]);
///  * [maxFileSizeBytes] ceiling enforced on the declared `Content-Length`
///    *and* while streaming, so an oversized body can never exhaust memory;
///  * `Content-Type` must be `image/*` — HTML error pages or binaries are
///    never persisted as `.jpg`;
///  * bytes land in a `.tmp` sibling and are only renamed onto the final path
///    after a complete, successful stream, so an interrupted download can not
///    leave a truncated file that the idempotency check would trust.
///
/// Every entry point is best-effort and idempotent:
///  * same URL ⇒ same file name, so repeat runs never duplicate a download;
///  * on failure the original URL is kept and the startup backfill retries
///    later;
///  * the `OrphanImageSweeper` is unaffected: rows reference these files, and
///    an obsolete file (image changed upstream) is swept after its 1h grace.
class MealImageLocalizer {
  MealImageLocalizer._();
  static final MealImageLocalizer instance = MealImageLocalizer._();

  static const Duration _downloadTimeout = Duration(seconds: 12);

  /// Hard ceiling for a single downloaded image (5 MB). Enforced both from the
  /// response's declared `Content-Length` and cumulatively while streaming.
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  /// Origins the app is willing to write bytes from. Anything else is refused.
  static const Set<String> _defaultTrustedHosts = {
    'firebasestorage.googleapis.com',
    'storage.googleapis.com',
    'res.cloudinary.com',
    'images.unsplash.com',
    'i.imgur.com',
  };

  /// Firebase App Hosting serves from arbitrary project subdomains, so any
  /// `<project>.firebasestorage.app` host is trusted.
  static const String _trustedHostSuffix = '.firebasestorage.app';

  /// Extra hosts trusted at runtime (e.g. a host added by remote config).
  static Set<String> customTrustedHosts = {};

  /// Full override of host trust — used by tests, or to widen the rule beyond
  /// exact-host / suffix matching at runtime.
  static bool Function(Uri uri)? hostValidator;

  /// Injected HTTP client (test seam). `null` ⇒ a throwaway [http.Client] is
  /// created and closed per download.
  http.Client? client;

  /// Injected documents-directory resolver (test seam). `null` ⇒
  /// `path_provider`'s real application documents directory.
  Future<Directory> Function()? documentsDirectoryResolver;

  /// URLs currently being downloaded — prevents two sync paths from fetching
  /// the same photo concurrently.
  final Set<String> _inFlight = {};

  /// Same classification rule as `MealImageResolver.isRemote`, duplicated here
  /// so this service layer stays free of widget imports.
  static bool isRemoteUrl(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  /// Whether [uri]'s host may be downloaded from: the built-in allow-list,
  /// [customTrustedHosts], or [hostValidator] when installed.
  static bool isTrustedHost(Uri uri) {
    final host = uri.host.toLowerCase();
    if (_defaultTrustedHosts.contains(host) ||
        host.endsWith(_trustedHostSuffix) ||
        customTrustedHosts.contains(host)) {
      return true;
    }
    return hostValidator?.call(uri) ?? false;
  }

  /// Localises a single photo reference:
  ///  * local path / asset / null / empty  → returned unchanged;
  ///  * remote URL refused by the hardening rules above → returned unchanged;
  ///  * remote URL already downloaded      → the existing file's path;
  ///  * remote URL                         → downloaded, then the file's path;
  ///  * download failure (offline, 404…)   → the original URL (retry happens
  ///    via [backfillVaultImages] on a later launch).
  Future<String?> localize(String? photoPath) async {
    final url = photoPath?.trim() ?? '';
    if (url.isEmpty || !isRemoteUrl(url)) return photoPath;

    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException catch (e) {
      debugPrint('[MealImageLocalizer] malformed URL "$url": $e');
      return photoPath;
    }
    if (!uri.isScheme('https')) {
      debugPrint('[MealImageLocalizer] refused non-HTTPS URL: $url');
      return photoPath;
    }
    if (!isTrustedHost(uri)) {
      debugPrint('[MealImageLocalizer] refused untrusted host '
          '"${uri.host}": $url');
      return photoPath;
    }

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
        final downloaded = await _downloadToFile(uri, target);
        if (downloaded) return target.path;
      } finally {
        _inFlight.remove(url);
      }
    } catch (e) {
      debugPrint('[MealImageLocalizer] localize failed for $url: $e');
    }
    return photoPath;
  }

  /// Streams the image at [uri] into a `.tmp` sibling of [target] and only
  /// renames it onto the final path once the whole body has arrived within
  /// [maxFileSizeBytes]. Returns `true` only on a fully staged file.
  Future<bool> _downloadToFile(Uri uri, File target) async {
    final injected = client;
    final httpClient = injected ?? http.Client();
    final ownsClient = injected == null;
    final tmp = File('${target.path}.tmp');
    IOSink? sink;
    var bytes = 0;
    var staged = false;
    try {
      final response = await httpClient
          .send(http.Request('GET', uri))
          .timeout(_downloadTimeout);

      if (response.statusCode != 200) {
        debugPrint('[MealImageLocalizer] HTTP ${response.statusCode} '
            'for $uri');
        return false;
      }
      final contentType =
          response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.startsWith('image/')) {
        debugPrint('[MealImageLocalizer] refused non-image content-type '
            '"${response.headers['content-type']}" for $uri');
        return false;
      }
      // A null / -1 contentLength ⇒ not declared; the running stream total
      // still enforces the cap byte-for-byte.
      final declared = response.contentLength;
      if (declared != null && declared > maxFileSizeBytes) {
        debugPrint('[MealImageLocalizer] refused $declared '
            'byte body (cap $maxFileSizeBytes) for $uri');
        return false;
      }

      await tmp.create(recursive: true);
      sink = tmp.openWrite();
      var exceededCap = false;
      await for (final chunk in response.stream) {
        bytes += chunk.length;
        if (bytes > maxFileSizeBytes) {
          exceededCap = true;
          break;
        }
        sink.add(chunk);
      }
      if (exceededCap) {
        debugPrint('[MealImageLocalizer] aborted $uri after exceeding '
            '$maxFileSizeBytes bytes mid-stream.');
        return false;
      }
      if (bytes == 0) {
        debugPrint('[MealImageLocalizer] empty image body for $uri');
        return false;
      }

      await sink.flush();
      await sink.close();
      sink = null;
      await tmp.rename(target.path);
      staged = true;
      return true;
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (!staged) {
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (e) {
          debugPrint('[MealImageLocalizer] tmp cleanup failed for $uri: $e');
        }
      }
      if (ownsClient) httpClient.close();
    }
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
    final docs = await (documentsDirectoryResolver ??
        getApplicationDocumentsDirectory)();
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
