import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/services/notification_service.dart';

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
        await NotificationService.instance.scheduleDailyNotification(hour: hour, minute: minute);
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

  /// Updates dietary repeat prevention rules (protein / carbs).
  Future<void> updateDietaryRules({bool? preventProtein, bool? preventCarbs}) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateDietaryRules(preventProtein: preventProtein, preventCarbs: preventCarbs);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Save welcome data and mark first run as complete.
  Future<void> saveWelcomeData(String name, String? email, String? gender) async {
    state = const AsyncValue.loading();
    try {
      String? avatarPath;
      if (gender == 'male' || gender == 'female') {
        final random = math.Random();
        final num = random.nextInt(5) + 1; // 1 to 5
        final agePrefix = random.nextBool() ? 'Y' : 'O'; // Young or Old
        final genderPrefix = gender == 'male' ? 'M' : 'F';
        avatarPath = 'assets/avatars/$genderPrefix$agePrefix$num.png';
      }

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
