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

  /// A remote starter-meal document, decoupled from [QueryDocumentSnapshot]
  /// so the sync algorithm is unit-testable without a live Firestore.
  @visibleForTesting
  Future<List<RemoteStarterDoc>> Function()? remoteStarterDocsFetcher;

  /// Test entry point for the auto-sync path (isManual defaults to false).
  @visibleForTesting
  Future<void> syncStarterMealsForTest(AppDatabase db, {bool isManual = false}) =>
      _syncStarterMeals(db, isManual: isManual);

  Future<List<RemoteStarterDoc>> _fetchRemoteStarterDocs() async {
    final override = remoteStarterDocsFetcher;
    if (override != null) return override();

    final snapshot = await FirebaseFirestore.instance
        .collection('vault_meals')
        .where('status', isEqualTo: 'approved')
        .where('isStarterMeal', isEqualTo: true)
        .get()
        .timeout(const Duration(seconds: 8));
    return [
      for (final doc in snapshot.docs)
        RemoteStarterDoc(id: doc.id, data: doc.data()),
    ];
  }

  Future<void> _syncStarterMeals(AppDatabase db, {bool isManual = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blacklistedIds = prefs.getStringList('deleted_starter_meals') ?? [];

      final docs = await _fetchRemoteStarterDocs();

      // Safeguard: an empty response (offline snapshot hiccup, flaky network,
      // transient permission failure) must never wipe the local starter
      // catalog. Skip the whole pass and keep what the user has.
      if (docs.isEmpty) {
        debugPrint('[AppConfigSyncService] Starter meals sync: cloud returned '
            '0 documents — skipping deletions/de-listings.');
        return;
      }

      // Identity is the cloud document id; the trimmed name is only a legacy
      // fallback for starter meals that predate cloudId tracking.
      final remoteById = <String, RemoteStarterDoc>{};
      final remoteByName = <String, RemoteStarterDoc>{};
      for (final doc in docs) {
        if (blacklistedIds.contains(doc.id)) continue; // Respect user deletions

        final name = (doc.data['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        remoteById[doc.id] = doc;
        remoteByName.putIfAbsent(name, () => doc);
      }

      final localMeals = await db.mealsDao.getStarterMeals();

      final matchByLocalId = <int, RemoteStarterDoc>{};
      final claimedRemoteIds = <String>{};

      // Pass 1: match by cloudId.
      for (final l in localMeals) {
        final cid = l.cloudId;
        if (cid == null) continue;
        final r = remoteById[cid];
        if (r != null && claimedRemoteIds.add(cid)) {
          matchByLocalId[l.id] = r;
        }
      }

      // Pass 2: legacy name fallback, only for meals without a cloudId.
      for (final l in localMeals) {
        if (l.cloudId != null || matchByLocalId.containsKey(l.id)) continue;
        final r = remoteByName[l.name.trim()];
        if (r != null && claimedRemoteIds.add(r.id)) {
          matchByLocalId[l.id] = r;
        }
      }

      // Stage every SQLite mutation first: photo downloads happen outside the
      // transaction so the write itself stays fast and atomic.
      final updates = <_StarterMealUpdate>[];
      for (final l in localMeals) {
        final r = matchByLocalId[l.id];
        if (r == null) continue;
        // Exists in both — update it with cloud properties (including a
        // renamed name), preserving local isFavorite, notes, cooldown, etc.
        final localPhoto = await MealImageLocalizer.instance
            .localize(r.data['imageUrl'] as String?);
        updates.add(_StarterMealUpdate(l.id, _cloudCompanion(r, localizePhoto: localPhoto)));
      }

      // Genuinely gone from the cloud starter catalog (or user-blacklisted):
      // de-list instead of delete — keep the row so meal_history, favourites
      // and notes survive; only the starter flag drops.
      final deListedIds = [
        for (final l in localMeals)
          if (!matchByLocalId.containsKey(l.id)) l.id,
      ];

      final inserts = <MealsCompanion>[];
      for (final doc in docs) {
        if (claimedRemoteIds.contains(doc.id)) continue;
        if (blacklistedIds.contains(doc.id)) continue; // Respect user deletions
        final name = (doc.data['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final localPhoto = await MealImageLocalizer.instance
            .localize(doc.data['imageUrl'] as String?);
        final companion = _cloudCompanion(doc, localizePhoto: localPhoto);
        inserts.add(companion.copyWith(
          name: Value(name),
          isStarterMeal: const Value(true),
        ));
      }

      await db.transaction(() async {
        for (final update in updates) {
          await db.mealsDao.updateMealCompanion(update.localId, update.companion);
        }
        for (final id in deListedIds) {
          await db.mealsDao.updateMealCompanion(
            id,
            MealsCompanion(isStarterMeal: Value(false)),
          );
        }
        for (final companion in inserts) {
          await db.mealsDao.insertMeal(companion);
        }
      });
      debugPrint('[AppConfigSyncService] Starter meals sync (manual=$isManual) completed successfully: '
          '${updates.length} updated, ${deListedIds.length} de-listed, ${inserts.length} inserted.');
    } catch (e) {
      debugPrint('[AppConfigSyncService] Starter meals sync failed: ');
      if (isManual) rethrow; // Let the UI handle the error
    }
  }

  MealsCompanion _cloudCompanion(RemoteStarterDoc doc, {String? localizePhoto}) {
    final rData = doc.data;
    final name = (rData['name'] as String? ?? '').trim();
    final prepTime = (rData['prepTimeMinutes'] as num?)?.toInt() ?? 30;
    return MealsCompanion(
      name: Value(name),
      cloudId: Value(doc.id),
      photoPath: Value(localizePhoto),
      shortName: Value(rData['shortName'] as String?),
      proteinType: Value(_mapProtein(rData['proteinType'] as String? ?? 'other')),
      carbsType: Value(_mapCarbs(rData['carbsType'] as String? ?? 'none')),
      category: Value(_mapCategory(rData['category'] as String? ?? 'popular')),
      prepTime: Value(prepTime <= 0 ? 30 : prepTime),
      isFridaySpecial: Value(rData['isFridaySpecial'] as bool? ?? false),
      isBudgetFriendly: Value(rData['isBudgetFriendly'] as bool? ?? false),
    );
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

/// One approved starter-meal document from the cloud vault.
@visibleForTesting
class RemoteStarterDoc {
  const RemoteStarterDoc({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

class _StarterMealUpdate {
  const _StarterMealUpdate(this.localId, this.companion);

  final int localId;
  final MealsCompanion companion;
}
