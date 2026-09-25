import 'package:cloud_firestore/cloud_firestore.dart';
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
}
