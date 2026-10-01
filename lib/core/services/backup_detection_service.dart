import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Detects whether the current launch is a fresh install that received data
/// from Android Auto Backup.
///
/// **How it works:** A tiny marker file lives in the *cache* directory, which
/// Android explicitly excludes from Auto Backup. On a normal run the marker
/// exists and [isRestoredInstall] returns `false`. After a reinstall (or a
/// device transfer) the backup restores the database and SharedPreferences but
/// *not* the cache, so the marker is absent while user data is present —
/// that's the signal that says "welcome back".
class BackupDetectionService {
  static const String _markerName = '.install_marker';

  /// Returns `true` exactly once per fresh installation that was seeded by
  /// Auto Backup. The marker is written immediately so subsequent launches
  /// are normal.
  static Future<bool> isRestoredInstall() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final marker = File('${cacheDir.path}/$_markerName');

      if (await marker.exists()) return false; // normal launch

      // Write the marker for every future launch.
      await marker.create(recursive: true);

      // The marker was missing. If this is a brand-new install the database
      // is empty and isFirstRun == true, so the caller's check on isFirstRun
      // will send the user to onboarding anyway. Only when isFirstRun is
      // *false* (restored from backup) does the caller show the welcome-back
      // dialog.
      return true;
    } catch (_) {
      // If cache access fails for any reason, treat it as a normal launch
      // rather than blocking the app.
      return false;
    }
  }
}
