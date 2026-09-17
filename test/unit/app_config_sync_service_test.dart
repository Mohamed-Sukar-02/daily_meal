import 'package:daily_meal/core/services/app_config_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SystemDefaults model', () {
    test('default values match expected application baselines', () {
      const defaults = SystemDefaults();
      expect(defaults.cooldownDays, 14);
      expect(defaults.chickenCooldownDays, 7);
      expect(defaults.beefCooldownDays, 10);
      expect(defaults.fishCooldownDays, 5);
      expect(defaults.meatlessCooldownDays, 0);
      expect(defaults.notificationHour, 12);
      expect(defaults.notificationMinute, 0);
      expect(defaults.minAppVersion, isNull);
      expect(defaults.announcement, isNull);
    });

    test('parses from Firestore map with partial or full overrides', () {
      final map = {
        'cooldownDays': 21,
        'chickenCooldownDays': 8,
        'beefCooldownDays': 12,
        'fishCooldownDays': 6,
        'meatlessCooldownDays': 2,
        'notificationHour': 13,
        'notificationMinute': 30,
        'minAppVersion': '1.1.0',
        'announcement': 'رمضان كريم',
      };

      final parsed = SystemDefaults.fromMap(map);
      expect(parsed.cooldownDays, 21);
      expect(parsed.chickenCooldownDays, 8);
      expect(parsed.beefCooldownDays, 12);
      expect(parsed.fishCooldownDays, 6);
      expect(parsed.meatlessCooldownDays, 2);
      expect(parsed.notificationHour, 13);
      expect(parsed.notificationMinute, 30);
      expect(parsed.minAppVersion, '1.1.0');
      expect(parsed.announcement, 'رمضان كريم');
    });

    test('handles missing or malformed fields safely with fallbacks', () {
      final map = <String, dynamic>{
        'cooldownDays': null,
        'invalidField': 999,
      };

      final parsed = SystemDefaults.fromMap(map);
      expect(parsed.cooldownDays, 14);
      expect(parsed.chickenCooldownDays, 7);
      expect(parsed.meatlessCooldownDays, 0);
    });
  });

  group('AppConfigSyncService cache & offline', () {
    test('getCachedDefaults returns fallback defaults when nothing cached', () async {
      final defaults = await AppConfigSyncService.instance.getCachedDefaults();
      expect(defaults.cooldownDays, 14);
      expect(defaults.chickenCooldownDays, 7);
      expect(defaults.meatlessCooldownDays, 0);
    });

    test('syncWithFirebase returns cached defaults safely during test/offline', () async {
      final result = await AppConfigSyncService.instance.syncWithFirebase();
      expect(result.cooldownDays, 14);
      expect(result.chickenCooldownDays, 7);
    });
  });
}
