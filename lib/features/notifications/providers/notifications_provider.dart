import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/remote_notification_service.dart';
import '../domain/notification_item.dart';

const String _kReadIdsKey = 'read_notification_ids';
const String _kDismissedIdsKey = 'dismissed_notification_ids';

/// The admin broadcast feed, with this device's read/dismissed state applied.
///
/// Firestore only says what was sent; whether the user has seen it, and what
/// they cleared away, lives in SharedPreferences and is re-applied to every
/// emission — so an item the user deleted stays deleted even though the
/// collection still holds it.
class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier([RemoteNotificationService? service])
      : _service = service ?? RemoteNotificationService(),
        super(const []) {
    _start();
  }

  final RemoteNotificationService _service;
  final Set<String> _readIds = <String>{};
  final Set<String> _dismissedIds = <String>{};

  /// Raw feed, before dismissal filtering and read-state overlay.
  List<NotificationItem> _feed = const [];
  StreamSubscription<List<NotificationItem>>? _subscription;

  Future<void> _start() async {
    await _load();
    if (!mounted) return;

    _subscription = _service.getNotificationsStream().listen(
      (items) {
        _feed = items;
        _publish();
      },
      // The service already absorbs read failures into a closed stream; this is
      // the belt-and-braces path for anything raised below it.
      onError: (Object e) => debugPrint('NotificationsNotifier: feed error: $e'),
    );
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _readIds.addAll(prefs.getStringList(_kReadIdsKey) ?? const []);
      _dismissedIds.addAll(prefs.getStringList(_kDismissedIdsKey) ?? const []);
    } catch (e) {
      debugPrint('NotificationsNotifier: persisted state unavailable: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kReadIdsKey, _readIds.toList());
      await prefs.setStringList(_kDismissedIdsKey, _dismissedIds.toList());
    } catch (e) {
      debugPrint('NotificationsNotifier: failed to persist state: $e');
    }
  }

  void _publish() {
    if (!mounted) return;
    state = [
      for (final item in _feed)
        if (!_dismissedIds.contains(item.id)) item.copyWith(isRead: _readIds.contains(item.id)),
    ];
  }

  Future<void> markAsRead(String id) async {
    _readIds.add(id);
    _publish();
    await _save();
  }

  Future<void> markAllAsRead() async {
    _readIds.addAll(state.map((item) => item.id));
    _publish();
    await _save();
  }

  Future<void> deleteAll() async {
    final ids = state.map((item) => item.id).toSet();
    _dismissedIds.addAll(ids);
    // Nothing keeps a cleared notification, so drop its read mark too rather
    // than letting the read set grow across every broadcast ever dismissed.
    _readIds.removeAll(ids);
    _publish();
    await _save();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>((ref) {
  return NotificationsNotifier();
});

final unreadNotificationsProvider = Provider<bool>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.any((item) => !item.isRead);
});
