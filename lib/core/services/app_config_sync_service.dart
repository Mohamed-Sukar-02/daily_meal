import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'meal_image_localizer.dart';
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

    // Quick reachability check
    final reachable = await ReachabilityService.instance.isInternetReachable(
      timeout: const Duration(seconds: 2),
    );
    if (!reachable) {
      debugPrint('[AppConfigSyncService] Device is offline, keeping local defaults.');
      return getCachedDefaults();
    }

    _isSyncing = true;

    try {
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
        bool isFirstRun = false;
        if (db != null) {
          final settings = await db.appSettingsDao.getSettings();
          isFirstRun = settings.isFirstRun;
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

        if (db != null && isFirstRun) {
          _syncStarterMeals(db, isManual: false).catchError((e) {
            debugPrint('[AppConfigSyncService] Starter meals auto sync error: ');
          });
        }

        debugPrint('[AppConfigSyncService] Successfully synced system defaults from Firebase.');
        return remoteDefaults;
      } else {
        debugPrint('[AppConfigSyncService] admin_config/system_defaults not found on Firebase. Using local defaults.');
      }
    } catch (e) {
      debugPrint('[AppConfigSyncService] Sync failed or offline: ');
    } finally {
      _isSyncing = false;
    }

    return getCachedDefaults();
  }

  Future<void> _syncStarterMeals(AppDatabase db, {bool isManual = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blacklistedIds = prefs.getStringList('deleted_starter_meals') ?? [];

      final snapshot = await FirebaseFirestore.instance
          .collection('vault_meals')
          .where('status', isEqualTo: 'approved')
          .where('isStarterMeal', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 8));

      final remoteMap = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in snapshot.docs) {
        if (blacklistedIds.contains(doc.id)) continue; // Respect user deletions

        final name = (doc.data()['name'] as String? ?? '').trim();
        if (name.isNotEmpty) {
          remoteMap[name] = doc;
        }
      }

      final localMeals = await db.mealsDao.getStarterMeals();
      final localMap = <String, Meal>{};
      for (final l in localMeals) {
        if (l.name.isNotEmpty) {
          localMap[l.name.trim()] = l;
        }
      }

      // Update or delete local starter meals
      for (final l in localMeals) {
        final lName = l.name.trim();
        if (remoteMap.containsKey(lName)) {
          // Exists in both, update it with cloud properties (preserving local isFavorite, etc)
          final rDoc = remoteMap[lName]!;
          final rData = rDoc.data();
          // Store the photo FILE, not the bare URL, so the vault renders
          // offline (URL falls back through if the download fails).
          final localPhoto = await MealImageLocalizer.instance
              .localize(rData['imageUrl'] as String?);
          await db.mealsDao.updateMealCompanion(
            l.id,
            MealsCompanion(
              cloudId: Value(rDoc.id),
              photoPath: Value(localPhoto),
              shortName: Value(rData['shortName'] as String?),
              proteinType: Value(_mapProtein(rData['proteinType'] as String? ?? 'other')),
              carbsType: Value(_mapCarbs(rData['carbsType'] as String? ?? 'none')),
              category: Value(_mapCategory(rData['category'] as String? ?? 'popular')),
              prepTime: Value((rData['prepTimeMinutes'] as num?)?.toInt() ?? 30),
              isFridaySpecial: Value(rData['isFridaySpecial'] as bool? ?? false),
              isBudgetFriendly: Value(rData['isBudgetFriendly'] as bool? ?? false),
            ),
          );
        } else {
          // Exists locally as starter meal, but removed from cloud (or blacklisted)
          if (!isManual) {
             // Only auto-sync deletes meals. Manual sync never force-deletes user's meals.
             await db.mealsDao.deleteMeal(l.id);
          }
        }
      }

      // Insert new starter meals from cloud
      for (final rName in remoteMap.keys) {
        if (!localMap.containsKey(rName)) {
          final rDoc = remoteMap[rName]!;
          final rData = rDoc.data();
          // Same offline-first rule as the update branch above.
          final localPhoto = await MealImageLocalizer.instance
              .localize(rData['imageUrl'] as String?);
          await db.mealsDao.insertMeal(
            MealsCompanion(
              name: Value(rName),
              cloudId: Value(rDoc.id),
              photoPath: Value(localPhoto),
              shortName: Value(rData['shortName'] as String?),
              proteinType: Value(_mapProtein(rData['proteinType'] as String? ?? 'other')),
              carbsType: Value(_mapCarbs(rData['carbsType'] as String? ?? 'none')),
              category: Value(_mapCategory(rData['category'] as String? ?? 'popular')),
              prepTime: Value((rData['prepTimeMinutes'] as num?)?.toInt() ?? 30),
              isFridaySpecial: Value(rData['isFridaySpecial'] as bool? ?? false),
              isBudgetFriendly: Value(rData['isBudgetFriendly'] as bool? ?? false),
              isStarterMeal: const Value(true),
            ),
          );
        }
      }
      debugPrint('[AppConfigSyncService] Starter meals sync (manual=) completed successfully.');
    } catch (e) {
      debugPrint('[AppConfigSyncService] Starter meals sync failed: ');
      if (isManual) rethrow; // Let the UI handle the error
    }
  }

  /// Triggered manually by the user from the Vault screen
  Future<void> manualSyncStarterMeals(AppDatabase db) async {
    await _syncStarterMeals(db, isManual: true);
  }

  ProteinType _mapProtein(String p) {
    switch (p) {
      case 'chicken': return ProteinType.chicken;
      case 'beef': return ProteinType.beef;
      case 'fish': return ProteinType.fish;
      case 'meatless': return ProteinType.legume;
      default: return ProteinType.none;
    }
  }

  CarbsType _mapCarbs(String c) {
    switch (c) {
      case 'rice': return CarbsType.rice;
      case 'pasta': return CarbsType.pasta;
      case 'bread': return CarbsType.bread;
      default: return CarbsType.none;
    }
  }

  MealCategory _mapCategory(String c) {
    switch (c) {
      case 'tabeekh': return MealCategory.egyptianTraditional;
      case 'casserole': return MealCategory.ovenBaked;
      case 'dry_sandwich': return MealCategory.fastFood;
      case 'seafood': return MealCategory.seafood;
      case 'soup_stew': return MealCategory.soupStew;
      case 'vegetarian': return MealCategory.vegetarian;
      default: return MealCategory.egyptianTraditional;
    }
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
