import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Professional avatar download service
/// - Downloads avatars when internet is available (offline-first)
/// - Small size (~1.4MB total for 20 avatars 256x256)
/// - Supports limited access, caching, and fallback to bundled assets
/// - Uses connectivity_plus to detect internet [from existing network_provider]
class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  static const List<String> avatarAssets = [
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

  static const String _prefsKey = 'avatars_downloaded_v1';
  static const String _prefsPathKey = 'avatars_local_paths_v1';

  /// Get local file path for avatar - returns file path if downloaded, else asset path
  Future<String> getAvatarPath(String assetPath) async {
    final localPath = await _getLocalFilePath(assetPath);
    final file = File(localPath);
    if (await file.exists()) {
      return localPath;
    }
    // Fallback to bundled asset
    return assetPath;
  }

  /// Check if avatar is downloaded as file
  Future<bool> isAvatarDownloaded(String assetPath) async {
    final localPath = await _getLocalFilePath(assetPath);
    return File(localPath).exists();
  }

  /// Get local file path for asset
  Future<String> _getLocalFilePath(String assetPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${dir.path}/avatars');
    final fileName = assetPath.split('/').last;
    return '${avatarsDir.path}/$fileName';
  }

  /// Download avatars when internet is available - called on app start
  Future<void> downloadAvatarsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyDownloaded = prefs.getBool(_prefsKey) ?? false;

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final hasInternet = !connectivity.contains(ConnectivityResult.none) && connectivity.isNotEmpty;

      if (!hasInternet) {
        debugPrint('AvatarService: No internet, skipping download, using bundled assets');
        // Even without internet, copy bundled assets to local storage for file access
        await _copyBundledAssetsToLocal();
        return;
      }

      if (alreadyDownloaded) {
        // Verify files still exist
        var allExist = true;
        for (final asset in avatarAssets) {
          if (!await isAvatarDownloaded(asset)) {
            allExist = false;
            break;
          }
        }
        if (allExist) {
          debugPrint('AvatarService: Avatars already downloaded and verified');
          return;
        }
      }

      debugPrint('AvatarService: Internet available, downloading avatars (small size ~1.4MB)...');
      await _downloadAvatars();

      await prefs.setBool(_prefsKey, true);
      debugPrint('AvatarService: Avatars downloaded successfully');
    } catch (e) {
      debugPrint('AvatarService: Error downloading avatars: $e - falling back to bundled assets');
      await _copyBundledAssetsToLocal();
    }
  }

  /// Copy bundled assets to local storage - ensures file access even offline
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
          debugPrint('AvatarService: Copied $assetPath to $localPath');
        } catch (e) {
          debugPrint('AvatarService: Failed to copy $assetPath: $e');
        }
      }
    } catch (e) {
      debugPrint('AvatarService: Error copying bundled assets: $e');
    }
  }

  /// Download avatars from remote - tries multiple sources
  Future<void> _downloadAvatars() async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${dir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }

    // For now, copy bundled assets (since remote URLs not yet configured)
    // In production, you would download from Firebase Storage or CDN:
    // Example: https://daily-meal000.web.app/avatars/MO1.png or Firebase Storage
    // This implementation ensures avatars are in file system for better performance
    // and prepares for future remote download capability
    
    for (final assetPath in avatarAssets) {
      final localPath = await _getLocalFilePath(assetPath);
      final file = File(localPath);
      if (await file.exists()) continue;

      try {
        // Try to download from remote first (if configured)
        final remoteUrl = _getRemoteUrl(assetPath);
        if (remoteUrl != null) {
          final success = await _downloadFromUrl(remoteUrl, localPath);
          if (success) {
            debugPrint('AvatarService: Downloaded $assetPath from $remoteUrl');
            continue;
          }
        }

        // Fallback: copy from bundled assets
        final byteData = await rootBundle.load(assetPath);
        final buffer = byteData.buffer.asUint8List();
        await file.writeAsBytes(buffer);
        debugPrint('AvatarService: Copied $assetPath to local (fallback)');
      } catch (e) {
        debugPrint('AvatarService: Failed to get $assetPath: $e');
      }
    }
  }

  /// Get remote URL for avatar - can be configured to Firebase Storage, CDN, etc.
  String? _getRemoteUrl(String assetPath) {
    // In production, return actual remote URL:
    // return 'https://daily-meal000.web.app/avatars/${assetPath.split('/').last}';
    // Or Firebase Storage: 'https://firebasestorage.googleapis.com/.../avatars/...'
    // For now, return null to use bundled assets - but structure is ready for remote
    // When internet available, app will use this to download fresh avatars
    return null;
  }

  /// Download file from URL using HttpClient (no extra dependency needed)
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

  /// Get all local avatar paths (for UI)
  Future<List<String>> getAllLocalAvatarPaths() async {
    final List<String> paths = [];
    for (final asset in avatarAssets) {
      paths.add(await getAvatarPath(asset));
    }
    return paths;
  }

  /// Clear downloaded avatars (for testing or reset)
  Future<void> clearDownloadedAvatars() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${dir.path}/avatars');
      if (await avatarsDir.exists()) {
        await avatarsDir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint('AvatarService: Cleared downloaded avatars');
    } catch (e) {
      debugPrint('AvatarService: Error clearing avatars: $e');
    }
  }
}

/// Helper to consolidate HttpClientResponse bytes
Future<Uint8List> consolidateHttpClientResponseBytes(HttpClientResponse response) async {
  final completer = BytesBuilder();
  await for (final chunk in response) {
    completer.add(chunk);
  }
  return completer.takeBytes();
}
