import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/services/device_profile.dart';
import 'package:daily_meal/features/notifications/providers/notifications_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<int?> storedFirstOpenedAt() async =>
      (await SharedPreferences.getInstance()).getInt('first_opened_at_millis');

  group('DeviceProfile.load seeding', () {
    test('stores the first-open date once and never rewrites it', () async {
      final openedAt = DateTime(2026, 3, 4, 8, 30);

      final first = await DeviceProfile.load(
        existingInstall: false,
        hasCooked: false,
        now: openedAt,
      );
      expect(first.firstOpenedAt, openedAt);
      expect(await storedFirstOpenedAt(), openedAt.millisecondsSinceEpoch);

      // A later launch on a device that has since onboarded and cooked keeps
      // the date recorded on the very first one.
      final later = await DeviceProfile.load(
        existingInstall: true,
        hasCooked: true,
        now: DateTime(2027, 1, 1),
      );
      expect(later.firstOpenedAt, openedAt);
      expect(later.hasCooked, isTrue);
      expect(await storedFirstOpenedAt(), openedAt.millisecondsSinceEpoch);
    });

    test('seeds a pre-existing install as a veteran, never as new', () async {
      final profile = await DeviceProfile.load(existingInstall: true, hasCooked: false);

      expect(profile.hasCooked, isFalse);
      expect(await storedFirstOpenedAt(), DateTime(2000, 1, 1).millisecondsSinceEpoch);
      expect(
        profile.isNewWithin(365),
        isFalse,
        reason: 'updating the app must not put a long-time user back inside '
            'the new window',
      );
    });
  });

  group('DeviceProfile.isNewWithin', () {
    final now = DateTime(2026, 6, 10);

    DeviceProfile openedDaysAgo(int days, {bool hasCooked = false}) => DeviceProfile(
          firstOpenedAt: now.subtract(Duration(days: days)),
          hasCooked: hasCooked,
        );

    test('the window is inclusive, measured in whole days', () {
      expect(openedDaysAgo(7).isNewWithin(7, now: now), isTrue);
      expect(openedDaysAgo(8).isNewWithin(7, now: now), isFalse);
    });

    test('a cooked meal makes the device returning whatever its tenure', () {
      expect(openedDaysAgo(0, hasCooked: true).isNewWithin(365, now: now), isFalse);
    });

    test('a device first opened today is new inside any window', () {
      expect(openedDaysAgo(0).isNewWithin(1, now: now), isTrue);
    });
  });

  group('deviceProfileProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('treats a first launch with nothing recorded as a new device', () async {
      final profile = await container.read(deviceProfileProvider.future);

      expect(profile.hasCooked, isFalse);
      expect(profile.isNewWithin(7), isTrue);
    });

    test('counts a completed onboarding as a pre-existing install', () async {
      await db.appSettingsDao.updateFirstRun(false);

      final profile = await container.read(deviceProfileProvider.future);

      expect(await storedFirstOpenedAt(), DateTime(2000, 1, 1).millisecondsSinceEpoch);
      expect(profile.isNewWithin(7), isFalse);
    });

    test('counts a logged meal as a pre-existing install and as cooked', () async {
      await db.mealHistoryDao.logMeal(
        mealName: 'takeout',
        proteinType: ProteinType.none,
        carbsType: CarbsType.none,
        cookedAt: DateTime(2026, 2, 2),
      );

      final profile = await container.read(deviceProfileProvider.future);

      expect(profile.hasCooked, isTrue);
      expect(await storedFirstOpenedAt(), DateTime(2000, 1, 1).millisecondsSinceEpoch);
    });
  });
}
