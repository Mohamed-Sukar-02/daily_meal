import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/avatar_service.dart';
import '../../../core/services/notification_service.dart';

/// Identifies a per-protein cooldown rule.
///
/// Used as the key for [cooldownMemoryProvider]. Keying by the protein itself
/// (instead of its display name) keeps the remembered values correct when the
/// app language changes.
enum CooldownProtein { chicken, beef, fish, meatless }

/// Remembers the day counts the user had configured before switching a protein
/// cooldown off, so turning it back on restores their choice instead of a
/// hard-coded default.
///
/// This lives in a provider (not in the settings screen widget) because the
/// cooldown details are now shown in a modal bottom sheet that is created and
/// destroyed on every open — widget state would be lost between opens.
final cooldownMemoryProvider =
    StateProvider<Map<CooldownProtein, int>>((ref) => const {});

/// Reactive stream watching the singleton AppSettings row.
final appSettingsProvider = StreamProvider<AppSettingsData>((ref) {
  final dao = ref.watch(appSettingsDaoProvider);
  return dao.watchSettings();
});

/// Derived provider mapping AppThemeModePreference to Flutter's ThemeMode.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settingsAsync = ref.watch(appSettingsProvider);
  return settingsAsync.maybeWhen(
    data: (s) {
      switch (s.themeMode) {
        case AppThemeModePreference.light:
          return ThemeMode.light;
        case AppThemeModePreference.dark:
          return ThemeMode.dark;
        case AppThemeModePreference.system:
          return ThemeMode.system;
      }
    },
    orElse: () => ThemeMode.system,
  );
});

/// Derived provider mapping AppLanguagePreference to Flutter's Locale.
final localeProvider = Provider<Locale>((ref) {
  final settingsAsync = ref.watch(appSettingsProvider);
  return settingsAsync.maybeWhen(
    data: (s) {
      return s.language == AppLanguagePreference.en
          ? const Locale('en')
          : const Locale('ar');
    },
    orElse: () => const Locale('ar'),
  );
});

/// Maps the persisted language preference onto the localisation bundle used
/// for anything rendered outside the widget tree (e.g. scheduled notifications).
AppStrings _stringsFor(AppSettingsData settings) => AppStrings(
      settings.language == AppLanguagePreference.en
          ? const Locale('en')
          : const Locale('ar'),
    );

/// Mutation controller for application settings.
class SettingsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Updates cooldown window in days (clamped 1 to 60 days).
  Future<void> updateCooldownDays(int days) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateCooldownDays(days);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> updateChickenCooldownDays(int days) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateChickenCooldownDays(days);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> updateBeefCooldownDays(int days) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateBeefCooldownDays(days);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> updateFishCooldownDays(int days) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateFishCooldownDays(days);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<void> updateMeatlessCooldownDays(int days) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateMeatlessCooldownDays(days);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Writes the per-protein cooldown for one protein, remembering the previous
  /// value in [cooldownMemoryProvider] whenever the rule is switched off.
  Future<void> setProteinCooldown(CooldownProtein protein, int days) async {
    if (days == 0) {
      final current = await ref.read(appSettingsDaoProvider).getSettings();
      final previous = switch (protein) {
        CooldownProtein.chicken => current.chickenCooldownDays,
        CooldownProtein.beef => current.beefCooldownDays,
        CooldownProtein.fish => current.fishCooldownDays,
        CooldownProtein.meatless => current.meatlessCooldownDays,
      };
      if (previous > 0) {
        final memory = ref.read(cooldownMemoryProvider);
        ref.read(cooldownMemoryProvider.notifier).state = {
          ...memory,
          protein: previous,
        };
      }
    }
    switch (protein) {
      case CooldownProtein.chicken:
        return updateChickenCooldownDays(days);
      case CooldownProtein.beef:
        return updateBeefCooldownDays(days);
      case CooldownProtein.fish:
        return updateFishCooldownDays(days);
      case CooldownProtein.meatless:
        return updateMeatlessCooldownDays(days);
    }
  }

  /// Saves the profile edited from the Settings screen.
  ///
  /// Gender is mandatory: [userGender] must be `male`/`female`, and [userAvatar]
  /// is guaranteed to belong to that gender's set (callers pick one with
  /// [AvatarService.randomAvatarForGender] whenever it does not).
  Future<void> updateProfile({
    required String userName,
    String? userEmail,
    required String userGender,
    required String userAvatar,
  }) async {
    assert(UserGender.isValid(userGender), 'userGender must be male or female');
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateWelcomeData(
        userName: userName,
        userEmail: userEmail,
        userGender: userGender,
        userAvatar: userAvatar,
      );
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Updates application theme mode (System / Light / Dark).
  Future<void> updateThemeMode(AppThemeModePreference mode) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateThemeMode(mode);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Updates application language.
  Future<void> updateLanguage(AppLanguagePreference lang) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateLanguage(lang);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Updates daily notification reminder time.
  Future<void> updateNotificationTime(int hour, int minute) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateNotificationTime(hour, minute);
      
      final settings = await dao.watchSettings().first;
      if (settings.notificationsEnabled) {
        await NotificationService.instance.scheduleDailyNotification(
          hour: hour,
          minute: minute,
          strings: _stringsFor(settings),
        );
      }
      
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Toggles daily notification reminder status.
  /// When enabling, requests OS permission first — stays OFF if denied.
  Future<void> toggleNotifications(bool enabled) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      if (enabled) {
        final granted = await NotificationService.instance.requestPermissions();
        if (!granted) {
          // Permission denied — keep switch OFF and don't schedule
          await dao.toggleNotifications(false);
          await NotificationService.instance.cancelNotification();
          state = const AsyncValue.data(null);
          return;
        }
        await dao.toggleNotifications(true);
        final settings = await dao.watchSettings().first;
        await NotificationService.instance.scheduleDailyNotification(
          hour: settings.notificationHour,
          minute: settings.notificationMinute,
          strings: _stringsFor(settings),
        );
      } else {
        await dao.toggleNotifications(false);
        await NotificationService.instance.cancelNotification();
      }
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }


  /// Save welcome data and mark first run as complete.
  Future<void> saveWelcomeData(
    String name,
    String? email,
    String? gender, [
    String? avatar,
  ]) async {
    state = const AsyncValue.loading();
    try {
      // Single source of truth for "pick an avatar that matches the gender" —
      // shared with the profile editor in the Settings screen.
      final avatarPath = avatar ?? AvatarService.randomAvatarForGender(gender);

      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateWelcomeData(
        userName: name, 
        userEmail: email,
        userGender: gender,
        userAvatar: avatarPath,
      );
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Resets settings to default values.
  Future<void> resetToDefaults() async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.resetToDefaults();
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
}

final settingsControllerProvider = AsyncNotifierProvider<SettingsController, void>(() {
  return SettingsController();
});
