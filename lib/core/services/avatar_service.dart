import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gender values as persisted in `app_settings.user_gender`.
class UserGender {
  const UserGender._();

  static const String male = 'male';
  static const String female = 'female';

  static bool isValid(String? value) => value == male || value == female;
}

class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  /// Male avatars: `MO*` are the adult set, `MY*` the young set.
  static const List<String> maleAvatars = [
    'assets/avatars/MO1.png',
    'assets/avatars/MO2.png',
    'assets/avatars/MO3.png',
    'assets/avatars/MO4.png',
    'assets/avatars/MO5.png',
    'assets/avatars/MY1.png',
    'assets/avatars/MY2.png',
    'assets/avatars/MY3.png',
    'assets/avatars/MY4.png',
    'assets/avatars/MY5.png',
  ];

  /// Female avatars: `F0*` are the adult set (zero padded), `FY*` the young set.
  static const List<String> femaleAvatars = [
    'assets/avatars/F01.png',
    'assets/avatars/F02.png',
    'assets/avatars/F03.png',
    'assets/avatars/F04.png',
    'assets/avatars/F05.png',
    'assets/avatars/FY1.png',
    'assets/avatars/FY2.png',
    'assets/avatars/FY3.png',
    'assets/avatars/FY4.png',
    'assets/avatars/FY5.png',
  ];

  /// Every bundled avatar — used for copying to the file system.
  static const List<String> avatarAssets = [...maleAvatars, ...femaleAvatars];

  /// The avatar set matching [gender]. Unknown/absent gender yields an empty
  /// list so the UI can force an explicit choice instead of showing all 20.
  static List<String> avatarsForGender(String? gender) {
    switch (gender) {
      case UserGender.male:
        return maleAvatars;
      case UserGender.female:
        return femaleAvatars;
      default:
        return const <String>[];
    }
  }

  /// True when [avatar] belongs to the set of [gender].
  static bool matchesGender(String? avatar, String? gender) {
    if (avatar == null || avatar.isEmpty) return false;
    return avatarsForGender(gender).contains(avatar);
  }

  /// Picks a random avatar from the set of [gender] so the profile never ends
  /// up without a picture. Returns `null` only for an invalid gender.
  static String? randomAvatarForGender(String? gender, {Random? random}) {
    final pool = avatarsForGender(gender);
    if (pool.isEmpty) return null;
    return pool[(random ?? Random()).nextInt(pool.length)];
  }

  static const String _prefsKey = 'avatars_downloaded_v2';

  Future<String> getAvatarPath(String assetPath) async {
    final localPath = await _getLocalFilePath(assetPath);
    final file = File(localPath);
    if (await file.exists()) {
      return localPath;
    }
    return assetPath;
  }

  Future<bool> isAvatarDownloaded(String assetPath) async {
    final localPath = await _getLocalFilePath(assetPath);
    return File(localPath).exists();
  }

  Future<String> _getLocalFilePath(String assetPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${dir.path}/avatars');
    final fileName = assetPath.split('/').last;
    return '${avatarsDir.path}/$fileName';
  }

  Future<void> downloadAvatarsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyDownloaded = prefs.getBool(_prefsKey) ?? false;

      if (alreadyDownloaded) {
        var allExist = true;
        for (final asset in avatarAssets) {
          if (!await isAvatarDownloaded(asset)) {
            allExist = false;
            break;
          }
        }
        if (allExist) {
          debugPrint('AvatarService: Avatars already available');
          return;
        }
      }

      await _copyBundledAssetsToLocal();
      await prefs.setBool(_prefsKey, true);
      debugPrint('AvatarService: Bundled avatars copied');
    } catch (e) {
      debugPrint('AvatarService: Error $e - fallback to bundled');
      await _copyBundledAssetsToLocal();
    }
  }

  Future<void> _copyBundledAssetsToLocal() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${dir.path}/avatars');
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }

      for (final assetPath in avatarAssets) {
        final localPath = await _getLocalFilePath(assetPath);
        final file = File(localPath);
        if (await file.exists()) continue;

        try {
          final byteData = await rootBundle.load(assetPath);
          final buffer = byteData.buffer.asUint8List();
          await file.writeAsBytes(buffer);
        } catch (e) {
          debugPrint('AvatarService: Failed to copy $assetPath: $e');
        }
      }
    } catch (e) {
      debugPrint('AvatarService: Error copying bundled: $e');
    }
  }

  Future<List<String>> getAllLocalAvatarPaths() async {
    final List<String> paths = [];
    for (final asset in avatarAssets) {
      paths.add(await getAvatarPath(asset));
    }
    return paths;
  }

  Future<void> clearDownloadedAvatars() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${dir.path}/avatars');
      if (await avatarsDir.exists()) {
        await avatarsDir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('AvatarService: Error clearing: $e');
    }
  }
}
