import 'dart:ui';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/app_settings_table.dart';
import '../../services/app_config_sync_service.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase> with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  static const int settingsRowId = 1;

  static AppSettingsCompanion get defaultSettings => AppSettingsCompanion(
    id: const Value(settingsRowId),
    cooldownDays: const Value(14),
    chickenCooldownDays: const Value(7),
    beefCooldownDays: const Value(10),
    fishCooldownDays: const Value(5),
    meatlessCooldownDays: const Value(0),
    notificationHour: const Value(12),
    notificationMinute: const Value(0),
    notificationsEnabled: const Value(false),
    themeMode: const Value(AppThemeModePreference.system),
    language: Value(
      PlatformDispatcher.instance.locale.languageCode == 'en'
          ? AppLanguagePreference.en
          : AppLanguagePreference.ar,
    ),
    isFirstRun: const Value(true),
  );

  /// Watch singleton AppSettings row with resilient fallback
  Stream<AppSettingsData> watchSettings() {
    return (select(appSettings)..where((t) => t.id.equals(settingsRowId)))
        .watchSingleOrNull()
        .asyncMap((setting) async {
      if (setting != null) return setting;
      return await ensureSettings();
    });
  }

  /// Get current AppSettings snapshot; guarantees fallback if missing
  Future<AppSettingsData> getSettings() async {
    final existing = await (select(appSettings)
          ..where((t) => t.id.equals(settingsRowId)))
        .getSingleOrNull();

    if (existing != null) return existing;
    return await ensureSettings();
  }

  /// Ensures singleton settings row exists
  Future<AppSettingsData> ensureSettings() async {
    final existing = await (select(appSettings)
          ..where((t) => t.id.equals(settingsRowId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    await into(appSettings).insert(
      defaultSettings,
      mode: InsertMode.insertOrIgnore,
    );
    return (select(appSettings)..where((t) => t.id.equals(settingsRowId))).getSingle();
  }

  /// Update singleton settings row
  Future<void> updateSettings(AppSettingsCompanion companion) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(companion);
  }

  /// Update cooldown duration in days (clamped between 0 and 60 days, 0 = disabled)
  Future<void> updateCooldownDays(int days) async {
    final clamped = days.clamp(0, 60);
    await updateSettings(AppSettingsCompanion(cooldownDays: Value(clamped)));
  }

  Future<void> updateChickenCooldownDays(int days) async {
    final clamped = days.clamp(0, 60);
    await updateSettings(AppSettingsCompanion(chickenCooldownDays: Value(clamped)));
  }

  Future<void> updateBeefCooldownDays(int days) async {
    final clamped = days.clamp(0, 60);
    await updateSettings(AppSettingsCompanion(beefCooldownDays: Value(clamped)));
  }

  Future<void> updateFishCooldownDays(int days) async {
    final clamped = days.clamp(0, 60);
    await updateSettings(AppSettingsCompanion(fishCooldownDays: Value(clamped)));
  }

  Future<void> updateMeatlessCooldownDays(int days) async {
    final clamped = days.clamp(0, 60);
    await updateSettings(AppSettingsCompanion(meatlessCooldownDays: Value(clamped)));
  }

  /// Update theme mode preference
  Future<void> updateThemeMode(AppThemeModePreference mode) async {
    await updateSettings(AppSettingsCompanion(themeMode: Value(mode)));
  }

  /// Update language preference
  Future<void> updateLanguage(AppLanguagePreference lang) async {
    await updateSettings(AppSettingsCompanion(language: Value(lang)));
  }

  /// Update daily notification time
  Future<void> updateNotificationTime(int hour, int minute) async {
    await updateSettings(
      AppSettingsCompanion(
        notificationHour: Value(hour),
        notificationMinute: Value(minute),
      ),
    );
  }

  /// Toggle notification enabled status
  Future<void> toggleNotifications(bool enabled) async {
    await updateSettings(AppSettingsCompanion(notificationsEnabled: Value(enabled)));
  }

  /// Alias for toggleNotifications
  Future<void> updateNotificationsEnabled(bool enabled) async {
    await toggleNotifications(enabled);
  }

  /// Update first run flag
  Future<void> updateFirstRun(bool isFirstRun) async {
    await updateSettings(AppSettingsCompanion(isFirstRun: Value(isFirstRun)));
  }

  /// Update welcome data (name, email, gender, avatar) and set isFirstRun to false
  Future<void> updateWelcomeData({
    required String userName, 
    String? userEmail,
    String? userGender,
    String? userAvatar,
  }) async {
    await updateSettings(
      AppSettingsCompanion(
        userName: Value(userName),
        userEmail: Value(userEmail),
        userGender: Value(userGender),
        userAvatar: Value(userAvatar),
        isFirstRun: const Value(false),
      ),
    );
  }

  /// Reset settings to defaults (using cached Firebase defaults if available)
  Future<void> resetToDefaults() async {
    final cached = await AppConfigSyncService.instance.getCachedDefaults();
    final companion = AppSettingsCompanion(
      id: const Value(settingsRowId),
      cooldownDays: Value(cached.cooldownDays),
      chickenCooldownDays: Value(cached.chickenCooldownDays),
      beefCooldownDays: Value(cached.beefCooldownDays),
      fishCooldownDays: Value(cached.fishCooldownDays),
      meatlessCooldownDays: Value(cached.meatlessCooldownDays),
      notificationHour: Value(cached.notificationHour),
      notificationMinute: Value(cached.notificationMinute),
      notificationsEnabled: const Value(false),
      themeMode: const Value(AppThemeModePreference.system),
      language: Value(
        PlatformDispatcher.instance.locale.languageCode == 'en'
            ? AppLanguagePreference.en
            : AppLanguagePreference.ar,
      ),
      isFirstRun: const Value(true),
    );
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(companion);
  }
}
