import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class NotificationSyncService {
  static const String _kLastCheckKey = 'last_admin_notification_check_time';

  static Future<void> checkAndNotify({bool isEn = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckMillis = prefs.getInt(_kLastCheckKey);

      // On first launch, seed with current time so we don't spam historical notifications
      if (lastCheckMillis == null || lastCheckMillis == 0) {
        await prefs.setInt(_kLastCheckKey, DateTime.now().millisecondsSinceEpoch);
        return;
      }

      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);

      final snapshot = await FirebaseFirestore.instance
          .collection('admin_notifications')
          .orderBy('sentAt', descending: true)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) return;

      DateTime newestTime = lastCheckTime;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
        if (sentAt == null) continue;

        if (sentAt.isAfter(lastCheckTime)) {
          if (sentAt.isAfter(newestTime)) {
            newestTime = sentAt;
          }
          final title = isEn ? (data['titleEn']?.toString() ?? '') : (data['titleAr']?.toString() ?? '');
          final body = isEn ? (data['messageEn']?.toString() ?? '') : (data['messageAr']?.toString() ?? '');
          if (title.isNotEmpty || body.isNotEmpty) {
            // Strictly positive ID, never 0 (0 is reserved for daily reminder)
            final notifId = (doc.id.hashCode.abs() % 100000) + 1;
            await NotificationService.instance.showAdminNotification(
              id: notifId,
              title: title.isNotEmpty ? title : 'أكلة النهاردة 🍽️',
              body: body,
              payload: data['route']?.toString() ?? '/',
            );
          }
        }
      }

      await prefs.setInt(_kLastCheckKey, newestTime.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('NotificationSyncService error: $e');
    }
  }
}
