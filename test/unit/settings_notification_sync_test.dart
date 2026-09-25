import 'dart:ui' show Locale;

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/core/services/notification_service.dart';
import 'package:daily_meal/features/settings/providers/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the OS-notification side effects the SettingsController triggers,
/// so the SQLite write and the reminder bookkeeping can be asserted together
/// without touching the plugin's platform channels.
class _ScheduleFailure implements Exception {}

class _ScheduledReminder {
  _ScheduledReminder({
    required this.hour,
    required this.minute,
    required this.strings,
  });

  final int hour;
  final int minute;
  final AppStrings strings;
}

class _FakeNotificationService implements NotificationService {
  int cancelCalls = 0;
  bool permissionsGranted = true;
  bool failNextSchedule = false;
  final List<_ScheduledReminder> scheduled = [];

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<void> cancelNotification() async {
    cancelCalls++;
  }

  @override
  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
    AppStrings strings = const AppStrings(Locale('ar')),
  }) async {
    if (failNextSchedule) {
      throw _ScheduleFailure();
    }
    scheduled.add(
      _ScheduledReminder(hour: hour, minute: minute, strings: strings),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeNotificationService notifications;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    await db.appSettingsDao.ensureSettings();
    notifications = _FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SettingsController controller() =>
      container.read(settingsControllerProvider.notifier);

  group('resetToDefaults cancels the OS reminder', () {
    test('cancels the scheduled notification and clears the persisted flag',
        () async {
      await db.appSettingsDao.toggleNotifications(true);

      await controller().resetToDefaults();

      expect(notifications.cancelCalls, 1,
          reason: 'the Android alarm survives the SQLite reset unless '
              'cancelNotification() is called');
      final settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationsEnabled, isFalse);
      expect(container.read(settingsControllerProvider).hasError, isFalse);
    });

    test('still cancels when notifications were already off', () async {
      await controller().resetToDefaults();

      expect(notifications.cancelCalls, 1);
    });
  });

  group('updateLanguage re-arms the reminder with the new strings', () {
    test('reschedules with the persisted time and the new language when '
        'notifications are enabled', () async {
      await db.appSettingsDao.updateNotificationTime(13, 30);
      await db.appSettingsDao.toggleNotifications(true);

      await controller().updateLanguage(AppLanguagePreference.en);

      expect(notifications.scheduled, hasLength(1));
      final last = notifications.scheduled.last;
      expect(last.hour, 13);
      expect(last.minute, 30);
      expect(
        last.strings.localNotificationTitle,
        const AppStrings(Locale('en')).localNotificationTitle,
        reason: 'the OS reminder must carry the new language copy, not the '
            'strings frozen at schedule time',
      );

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.language, AppLanguagePreference.en);
    });

    test('leaves the OS alarm untouched when notifications are disabled',
        () async {
      await controller().updateLanguage(AppLanguagePreference.en);

      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelCalls, 0);
    });
  });

  group('toggleNotifications rolls back when scheduling fails', () {
    test('persisted flag returns to OFF and the error surfaces when '
        'scheduleDailyNotification throws', () async {
      notifications.failNextSchedule = true;

      await expectLater(
        controller().toggleNotifications(true),
        throwsA(isA<_ScheduleFailure>()),
      );

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationsEnabled, isFalse,
          reason: 'the switch must not claim a reminder that was never '
              'scheduled');
      expect(notifications.cancelCalls, greaterThanOrEqualTo(1),
          reason: 'a half-scheduled reminder must be cancelled on rollback');
      expect(container.read(settingsControllerProvider).hasError, isTrue);
    });

    test('enable happy path persists true and schedules exactly once',
        () async {
      await db.appSettingsDao.updateNotificationTime(9, 15);

      await controller().toggleNotifications(true);

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationsEnabled, isTrue);
      expect(notifications.scheduled, hasLength(1));
      expect(notifications.scheduled.single.hour, 9);
      expect(notifications.scheduled.single.minute, 15);
      expect(notifications.cancelCalls, 0);
    });

    test('permission denial keeps the flag OFF and cancels without scheduling',
        () async {
      notifications.permissionsGranted = false;

      await controller().toggleNotifications(true);

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationsEnabled, isFalse);
      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelCalls, 1);
    });

    test('disable persists OFF and cancels the reminder', () async {
      await db.appSettingsDao.toggleNotifications(true);

      await controller().toggleNotifications(false);

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationsEnabled, isFalse);
      expect(notifications.cancelCalls, 1);
      expect(notifications.scheduled, isEmpty);
    });
  });
}
