import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../localization/app_strings.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Invoked when the user taps a system notification. The payload is the
  /// route the notification was created for, and the app's root wires this to
  /// the GoRouter (see `main.dart`).
  void Function(String route)? onNotificationTapped;

  Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZone.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTapped?.call(payload);
        }
      },
    );
  }

  /// The notification the app was cold-started from, if any. Its payload is
  /// the route to open once the first frame exists.
  Future<String?> getColdStartNotificationPayload() async {
    if (kIsWeb) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }

  /// Requests notification permission and returns true if granted.
  /// On pre-Android 13 or web, returns true (no runtime permission needed).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      // Exact alarms is a separate scheduling permission; prompt for it but don't
      // block on the result. Scheduling re-checks it live via
      // canScheduleExactNotifications(), so no value is cached here.
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (_) {}
      // granted == null => platform < Android 13, permission is implicitly granted
      if (granted == null) return true;
      return granted;
    }
    return true;
  }

  /// Schedules the daily reminder.
  ///
  /// [strings] carries the user's language so the notification copy and the
  /// channel labels shown in Android OS settings match the app UI. Channels are
  /// created once by the OS, so the first language after install is what
  /// survives in the settings screen until the channel is recreated.
  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
    AppStrings strings = const AppStrings(Locale('ar')),
  }) async {
    if (kIsWeb) return;
    await cancelNotification();

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_meal_channel',
      strings.localNotificationChannelName,
      channelDescription: strings.localNotificationDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    bool canExact = false;
    if (Platform.isAndroid) {
      try {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        canExact = await androidImpl?.canScheduleExactNotifications() ?? false;
      } catch (_) {
        canExact = false;
      }
    }

    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        0,
        strings.localNotificationTitle,
        strings.localNotificationBody,
        scheduledDate,
        platformDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/',
      );
    } catch (e) {
      if (canExact) {
        // Exact scheduling can still throw when the OS revokes the permission
        // or on battery saver. Gracefully fall back to inexact repeating reminder.
        try {
          await _plugin.zonedSchedule(
            0,
            strings.localNotificationTitle,
            strings.localNotificationBody,
            scheduledDate,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: '/',
          );
        } catch (_) {}
      }
    }
  }

  Future<void> cancelNotification() async {
    if (kIsWeb) return;
    await _plugin.cancel(0);
  }

  Future<void> showAdminNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    AppStrings strings = const AppStrings(Locale('ar')),
  }) async {
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      'admin_announcements_channel',
      strings.adminChannelName,
      channelDescription: strings.adminChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
