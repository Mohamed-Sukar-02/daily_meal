import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../domain/notification_item.dart';

/// Reads the broadcasts the admin panel writes to `admin_notifications`.
///
/// The collection is world-readable in `firestore.rules`, so no sign-in step
/// is needed before listening.
class RemoteNotificationService {
  RemoteNotificationService({this._firestore});

  final FirebaseFirestore? _firestore;

  /// Resolved lazily: startup treats `Firebase.initializeApp` as best-effort,
  /// and touching `FirebaseFirestore.instance` before it succeeded throws.
  FirebaseFirestore get _fs => _firestore ?? FirebaseFirestore.instance;

  static const int maxItems = 50;

  /// Newest-first feed, kept live by Firestore.
  ///
  /// A failing read (no Firebase, rules denial) ends the stream after logging
  /// rather than pushing the error at the listener: an unreadable inbox should
  /// look empty, not crash the shell.
  Stream<List<NotificationItem>> getNotificationsStream() async* {
    try {
      final query = _fs.collection('admin_notifications').orderBy('sentAt', descending: true).limit(maxItems);

      await for (final snapshot in query.snapshots()) {
        yield snapshot.docs.map(_mapDoc).toList();
      }
    } catch (e) {
      debugPrint('RemoteNotificationService: notifications stream stopped: $e');
    }
  }

  static NotificationItem _mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      fromData(doc.id, doc.data());

  /// Public only so the field mapping can be tested without a live document.
  @visibleForTesting
  static NotificationItem fromData(String id, Map<String, dynamic> data) {
    return NotificationItem(
      id: id,
      title: {'ar': _text(data['titleAr']), 'en': _text(data['titleEn'])},
      subtitle: {'ar': _text(data['messageAr']), 'en': _text(data['messageEn'])},
      time: _time(data['sentAt']),
      type: _type(data['type']),
      route: _route(data['route']),
    );
  }

  /// Admin-authored fields are hand-typed, so anything but a String — a stray
  /// number, or a missing key — reads as empty instead of throwing.
  static String _text(Object? value) => value is String ? value : '';

  /// A missing or blank route falls back to Home: pushing an unmatched
  /// location lands the user on go_router's error page.
  static String _route(Object? value) => value is String && value.isNotEmpty ? value : '/';

  static DateTime _time(Object? value) => value is Timestamp ? value.toDate() : DateTime.now();

  static NotificationType _type(Object? value) {
    switch (value) {
      case 'meal':
        return NotificationType.meal;
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.update;
    }
  }
}
