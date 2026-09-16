import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'reachability_service.dart';

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

  /// Every bundled avatar — used for downloading/copying to the file system.
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

      final connectivity = await Connectivity().checkConnectivity();
      final hasInterface = !connectivity.contains(ConnectivityResult.none) && connectivity.isNotEmpty;

      if (!hasInterface) {
        debugPrint('AvatarService: No interface, using bundled');
        await _copyBundledAssetsToLocal();
        return;
      }

      final reachable = await ReachabilityService.instance.isInternetReachable(
        timeout: const Duration(seconds: 2),
      );
      if (!reachable) {
        debugPrint('AvatarService: No internet reachable, using bundled');
        await _copyBundledAssetsToLocal();
        return;
      }

      if (alreadyDownloaded) {
        var allExist = true;
        for (final asset in avatarAssets) {
          if (!await isAvatarDownloaded(asset)) {
            allExist = false;
            break;
          }
        }
        if (allExist) {
          debugPrint('AvatarService: Avatars already downloaded');
          return;
        }
      }

      debugPrint('AvatarService: Downloading avatars...');
      await _downloadAvatars();

      await prefs.setBool(_prefsKey, true);
      debugPrint('AvatarService: Avatars downloaded');
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

  Future<void> _downloadAvatars() async {
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
        final remoteUrl = _getRemoteUrl(assetPath);
        if (remoteUrl != null) {
          final success = await _downloadFromUrl(remoteUrl, localPath);
          if (success) continue;
        }

        final byteData = await rootBundle.load(assetPath);
        final buffer = byteData.buffer.asUint8List();
        await file.writeAsBytes(buffer);
      } catch (e) {
        debugPrint('AvatarService: Failed to get $assetPath: $e');
      }
    }
  }

  String? _getRemoteUrl(String assetPath) {
    return null;
  }

  Future<bool> _downloadFromUrl(String url, String localPath) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final file = File(localPath);
        await file.writeAsBytes(bytes);
        httpClient.close();
        return true;
      }
      httpClient.close();
      return false;
    } catch (e) {
      debugPrint('AvatarService: Download failed for $url: $e');
      return false;
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

Future<Uint8List> consolidateHttpClientResponseBytes(HttpClientResponse response) async {
  final completer = BytesBuilder();
  await for (final chunk in response) {
    completer.add(chunk);
  }
  return completer.takeBytes();
}
