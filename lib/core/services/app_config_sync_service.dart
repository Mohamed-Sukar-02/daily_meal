import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'reachability_service.dart';

class SystemDefaults {
  final int cooldownDays;
  final int chickenCooldownDays;
  final int beefCooldownDays;
  final int fishCooldownDays;
  final int meatlessCooldownDays;
  final int notificationHour;
  final int notificationMinute;
  final String? minAppVersion;
  final String? announcement;

  const SystemDefaults({
    this.cooldownDays = 14,
    this.chickenCooldownDays = 2,
    this.beefCooldownDays = 2,
    this.fishCooldownDays = 4,
    this.meatlessCooldownDays = 0,
    this.notificationHour = 12,
    this.notificationMinute = 0,
    this.minAppVersion,
    this.announcement,
  });

  factory SystemDefaults.fromMap(Map<String, dynamic> map) {
    return SystemDefaults(
      cooldownDays: (map['cooldownDays'] as num?)?.toInt() ?? 14,
      chickenCooldownDays: (map['chickenCooldownDays'] as num?)?.toInt() ?? 2,
      beefCooldownDays: (map['beefCooldownDays'] as num?)?.toInt() ?? 2,
      fishCooldownDays: (map['fishCooldownDays'] as num?)?.toInt() ?? 4,
      meatlessCooldownDays: (map['meatlessCooldownDays'] as num?)?.toInt() ?? 0,
      notificationHour: (map['notificationHour'] as num?)?.toInt() ?? 12,
      notificationMinute: (map['notificationMinute'] as num?)?.toInt() ?? 0,
      minAppVersion: map['minAppVersion'] as String?,
      announcement: map['announcement'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cooldownDays': cooldownDays,
      'chickenCooldownDays': chickenCooldownDays,
      'beefCooldownDays': beefCooldownDays,
      'fishCooldownDays': fishCooldownDays,
      'meatlessCooldownDays': meatlessCooldownDays,
      'notificationHour': notificationHour,
      'notificationMinute': notificationMinute,
      if (minAppVersion != null) 'minAppVersion': minAppVersion,
      if (announcement != null) 'announcement': announcement,
    };
  }
}

class AppConfigSyncService {
  AppConfigSyncService._();
  static final AppConfigSyncService instance = AppConfigSyncService._();

  static const String _collection = 'admin_config';
  static const String _doc = 'system_defaults';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  void init({AppDatabase? db}) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    // Initial sync attempt (asynchronous & non-blocking)
    syncWithFirebase(db: db).catchError((e) {
      debugPrint('[AppConfigSyncService] Initial sync error (offline): $e');
      return const SystemDefaults();
    });

    // Listen for transitions to online
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasInterface = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (hasInterface) {
        syncWithFirebase(db: db).catchError((e) {
          debugPrint('[AppConfigSyncService] Background sync error: $e');
          return const SystemDefaults();
        });
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  /// Syncs default values and system configurations from Firebase Firestore.
  /// If offline, fails gracefully without throwing or blocking UI.
  Future<SystemDefaults> syncWithFirebase({AppDatabase? db}) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return getCachedDefaults();
    if (_isSyncing) return getCachedDefaults();
    _isSyncing = true;

    try {
      // Quick reachability check
      final reachable = await ReachabilityService.instance.isInternetReachable(
        timeout: const Duration(seconds: 2),
      );
      if (!reachable) {
        debugPrint('[AppConfigSyncService] Device is offline, keeping local defaults.');
        return getCachedDefaults();
      }

      final docSnap = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_doc)
          .get()
          .timeout(const Duration(seconds: 4));

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        final remoteDefaults = SystemDefaults.fromMap(data);

        // Cache in SharedPreferences for offline access
        await _cacheDefaults(remoteDefaults);

        // If local database is provided, update first-run or unconfigured defaults
        if (db != null) {
          final settings = await db.appSettingsDao.getSettings();
          if (settings.isFirstRun) {
            await db.appSettingsDao.updateSettings(
              AppSettingsCompanion(
                cooldownDays: Value(remoteDefaults.cooldownDays),
                chickenCooldownDays: Value(remoteDefaults.chickenCooldownDays),
                beefCooldownDays: Value(remoteDefaults.beefCooldownDays),
                fishCooldownDays: Value(remoteDefaults.fishCooldownDays),
                meatlessCooldownDays: Value(remoteDefaults.meatlessCooldownDays),
                notificationHour: Value(remoteDefaults.notificationHour),
                notificationMinute: Value(remoteDefaults.notificationMinute),
              ),
            );
          }
        }

        debugPrint('[AppConfigSyncService] Successfully synced system defaults from Firebase.');
        return remoteDefaults;
      } else {
        debugPrint('[AppConfigSyncService] admin_config/system_defaults not found on Firebase. Using local defaults.');
      }
    } catch (e) {
      debugPrint('[AppConfigSyncService] Sync failed or offline: $e');
    } finally {
      _isSyncing = false;
    }

    return getCachedDefaults();
  }

  Future<void> _cacheDefaults(SystemDefaults defaults) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cfg_cooldown_days', defaults.cooldownDays);
      await prefs.setInt('cfg_chicken_cooldown_days', defaults.chickenCooldownDays);
      await prefs.setInt('cfg_beef_cooldown_days', defaults.beefCooldownDays);
      await prefs.setInt('cfg_fish_cooldown_days', defaults.fishCooldownDays);
      await prefs.setInt('cfg_meatless_cooldown_days', defaults.meatlessCooldownDays);
      await prefs.setInt('cfg_notification_hour', defaults.notificationHour);
      await prefs.setInt('cfg_notification_minute', defaults.notificationMinute);
      if (defaults.minAppVersion != null) {
        await prefs.setString('cfg_min_app_version', defaults.minAppVersion!);
      }
      if (defaults.announcement != null) {
        await prefs.setString('cfg_announcement', defaults.announcement!);
      }
    } catch (_) {}
  }

  Future<SystemDefaults> getCachedDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SystemDefaults(
        cooldownDays: prefs.getInt('cfg_cooldown_days') ?? 14,
        chickenCooldownDays: prefs.getInt('cfg_chicken_cooldown_days') ?? 2,
        beefCooldownDays: prefs.getInt('cfg_beef_cooldown_days') ?? 2,
        fishCooldownDays: prefs.getInt('cfg_fish_cooldown_days') ?? 4,
        meatlessCooldownDays: prefs.getInt('cfg_meatless_cooldown_days') ?? 0,
        notificationHour: prefs.getInt('cfg_notification_hour') ?? 12,
        notificationMinute: prefs.getInt('cfg_notification_minute') ?? 0,
        minAppVersion: prefs.getString('cfg_min_app_version'),
        announcement: prefs.getString('cfg_announcement'),
      );
    } catch (e) {
      return const SystemDefaults();
    }
  }
}
