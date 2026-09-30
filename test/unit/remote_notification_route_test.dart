import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daily_meal/core/services/device_profile.dart';
import 'package:daily_meal/features/notifications/data/remote_notification_service.dart';
import 'package:daily_meal/features/notifications/domain/notification_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NotificationItem map(Map<String, dynamic> data) =>
      RemoteNotificationService.fromData('doc-id', data);

  group('admin notification route field', () {
    test('carries the route the admin panel attached', () {
      expect(map({'route': '/vault?tab=explore'}).route, '/vault?tab=explore');
      expect(map({'route': '/meal/cloud/abc123'}).route, '/meal/cloud/abc123');
    });

    test('permits every route the router registers', () {
      for (final route in [
        '/',
        '/history',
        '/notifications',
        '/vault',
        '/vault?tab=explore',
        '/settings',
        '/settings?section=notifications',
        '/meal/7',
        '/meal/cloud/abc123',
      ]) {
        expect(map({'route': route}).route, route, reason: route);
      }
    });

    test('sanitizes external schemes, script injections, and unknown paths back to Home', () {
      expect(map({'route': 'javascript:alert(1)'}).route, '/');
      expect(map({'route': 'https://malicious-site.com'}).route, '/');
      expect(map({'route': '/unknown/unregistered/route'}).route, '/');
      expect(map({'route': '/vault?tab=evil'}).route, '/');
      expect(map({'route': '/meal/invalid_id'}).route, '/');
      expect(map({'route': '/meal/cloud/../../../traversal'}).route, '/');
      expect(map({'route': '   /history   '}).route, '/history');
    });

    test('falls back to Home when the route is absent, blank or not a string', () {
      expect(map({}).route, '/');
      expect(map({'route': ''}).route, '/');
      expect(map({'route': 42}).route, '/');
      expect(map({'route': null}).route, '/');
      expect(map({'route': ['/', '/vault']}).route, '/');
    });

    test('leaves the other fields alone', () {
      final sentAt = DateTime(2026, 1, 2, 3, 4);
      final item = map({
        'titleAr': 'عنوان',
        'titleEn': 'title',
        'messageAr': 'رسالة',
        'messageEn': 'body',
        'type': 'reminder',
        'sentAt': Timestamp.fromDate(sentAt),
        'route': '/settings',
      });

      expect(item.id, 'doc-id');
      expect(item.title, {'ar': 'عنوان', 'en': 'title'});
      expect(item.subtitle, {'ar': 'رسالة', 'en': 'body'});
      expect(item.type, NotificationType.reminder);
      expect(item.time, sentAt);
      expect(item.route, '/settings');
    });
  });

  group('admin notification audience field', () {
    test('keeps the language broadcasts the admin panel can write', () {
      expect(map({'audience': 'ar'}).audience, 'ar');
      expect(map({'audience': 'en'}).audience, 'en');
      expect(map({'audience': 'all'}).audience, 'all');
    });

    test('reads missing, blank, unknown or non-string values as everyone', () {
      for (final value in <Map<String, dynamic>>[
        {'audience': 'anyone'},
        {'audience': ''},
        {},
        {'audience': 42},
        {'audience': null},
      ]) {
        expect(map(value).audience, 'all', reason: '$value');
      }
    });

    test('hides a single-language broadcast from the other language', () {
      expect(map({'audience': 'ar'}).matchesLanguage(isEn: false), isTrue);
      expect(map({'audience': 'ar'}).matchesLanguage(isEn: true), isFalse);
      expect(map({'audience': 'en'}).matchesLanguage(isEn: true), isTrue);
      expect(map({'audience': 'en'}).matchesLanguage(isEn: false), isFalse);
      expect(map({'audience': 'all'}).matchesLanguage(isEn: true), isTrue);
    });
  });

  group('admin notification segment field', () {
    // Read at 2026-01-05, so a device first opened on 2026-01-01 is four days
    // old and one opened a year earlier is out of every window in the app.
    final now = DateTime(2026, 1, 5);
    final fresh = DeviceProfile(firstOpenedAt: DateTime(2026, 1, 1), hasCooked: false);
    final veteran = DeviceProfile(firstOpenedAt: DateTime(2025, 1, 1), hasCooked: false);
    final cookied = DeviceProfile(firstOpenedAt: DateTime(2026, 1, 1), hasCooked: true);

    bool showsFor(Map<String, Object?> segment, DeviceProfile? profile) =>
        map({'segment': segment}).matchesDevice(profile, now: now);

    test('carries the segment the admin panel wrote', () {
      final segment = map({'segment': {'v': 1, 'kind': 'new', 'days': 7}}).segment;
      expect(segment.version, 1);
      expect(segment.kind, 'new');
      expect(segment.days, 7);
    });

    test('reads a missing or non-map segment as a broadcast to everyone', () {
      for (final value in <Object?>[null, 'new', 7, ['new', 7]]) {
        final item = map({'segment': value});
        expect(item.segment.kind, 'all', reason: '$value');
        expect(item.matchesDevice(fresh, now: now), isTrue, reason: '$value');
      }
      expect(map({}).matchesDevice(fresh, now: now), isTrue);
    });

    test('kind all reaches every device, profile or no profile', () {
      expect(showsFor({'v': 1, 'kind': 'all', 'days': 7}, fresh), isTrue);
      expect(showsFor({'kind': 'all'}, null), isTrue);
      // `all` is read before the version gate, so a future layout that still
      // means "everyone" keeps working instead of going dark on old builds.
      expect(showsFor({'v': 2, 'kind': 'all'}, null), isTrue);
    });

    test('new covers the window, returning everything after it', () {
      const newIn7 = {'v': 1, 'kind': 'new', 'days': 7};
      const returningIn7 = {'v': 1, 'kind': 'returning', 'days': 7};

      expect(showsFor(newIn7, fresh), isTrue);
      expect(showsFor(returningIn7, fresh), isFalse);

      expect(showsFor(newIn7, veteran), isFalse);
      expect(showsFor(returningIn7, veteran), isTrue);

      // The window is inclusive: a four-day device is new inside four days.
      expect(showsFor({'v': 1, 'kind': 'new', 'days': 4}, fresh), isTrue);
      expect(showsFor({'v': 1, 'kind': 'new', 'days': 3}, fresh), isFalse);
    });

    test('a device that has cooked is returning from its first day', () {
      expect(showsFor({'v': 1, 'kind': 'new', 'days': 7}, cookied), isFalse);
      expect(showsFor({'v': 1, 'kind': 'returning', 'days': 7}, cookied), isTrue);
    });

    test('new and returning together cover every device', () {
      final devices = {
        'four days old, nothing cooked': fresh,
        'a year old, nothing cooked': veteran,
        'four days old, something cooked': cookied,
      };
      for (final device in devices.entries) {
        expect(
          showsFor({'v': 1, 'kind': 'new', 'days': 7}, device.value),
          isNot(showsFor({'v': 1, 'kind': 'returning', 'days': 7}, device.value)),
          reason: device.key,
        );
      }
    });

    test('stays silent on a rule this build cannot interpret', () {
      for (final segment in <Map<String, Object?>>[
        {'v': 2, 'kind': 'new', 'days': 7},
        {'v': 0, 'kind': 'new', 'days': 7},
        {'v': '1', 'kind': 'new', 'days': 7},
        {'kind': 'new', 'days': 7},
        {'v': 1, 'kind': 'anyone', 'days': 7},
        {'v': 1, 'kind': 7, 'days': 7},
        {'v': 1, 'days': 7},
        {'v': 1, 'kind': 'new'},
        {'v': 1, 'kind': 'new', 'days': '7'},
        {'v': 1, 'kind': 'new', 'days': 0},
      ]) {
        expect(
          map({'segment': segment}).matchesDevice(fresh, now: now),
          isFalse,
          reason: '$segment',
        );
      }
    });

    test('hides lifecycle broadcasts when the device profile is unreadable', () {
      expect(showsFor({'v': 1, 'kind': 'new', 'days': 7}, null), isFalse);
      expect(showsFor({'v': 1, 'kind': 'returning', 'days': 7}, null), isFalse);
    });

    test('survives copyWith and stays orthogonal to the audience field', () {
      final read = map({
        'segment': {'v': 1, 'kind': 'new', 'days': 7},
        'audience': 'ar',
      }).copyWith(isRead: true);

      expect(read.segment.kind, 'new');
      expect(read.segment.days, 7);
      expect(read.audience, 'ar');
      expect(read.matchesDevice(fresh, now: now), isTrue);
    });
  });
}
