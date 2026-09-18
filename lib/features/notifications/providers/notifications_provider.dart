import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notification_item.dart';

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier()
      : super([
          NotificationItem(
            id: '1',
            title: {'en': 'Koshari suggestion', 'ar': 'اقتراح كشري'},
            subtitle: {'en': 'Your favorite meal is ready to be cooked.', 'ar': 'وجبتك المفضلة جاهزة للطبخ.'},
            time: DateTime.now().subtract(const Duration(hours: 1)),
            type: NotificationType.meal,
            route: '/', // route to home/meal details
          ),
          NotificationItem(
            id: '2',
            title: {'en': 'Lunch Reminder', 'ar': 'تذكير الغداء'},
            subtitle: {'en': 'Time to check today\'s meal!', 'ar': 'حان وقت تفقد وجبة اليوم!'},
            time: DateTime.now().subtract(const Duration(hours: 3)),
            type: NotificationType.reminder,
            route: '/settings',
          ),
          NotificationItem(
            id: '3',
            title: {'en': 'Smart Filter', 'ar': 'الفلتر الذكي'},
            subtitle: {'en': 'New filtering options are available.', 'ar': 'تمت إضافة خيارات تصفية جديدة.'},
            time: DateTime.now().subtract(const Duration(days: 1)),
            type: NotificationType.update,
            route: '/',
          ),
        ]);

  void markAsRead(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
  }

  void markAllAsRead() {
    state = state.map((item) => item.copyWith(isRead: true)).toList();
  }

  void deleteAll() {
    state = [];
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>((ref) {
  return NotificationsNotifier();
});

final unreadNotificationsProvider = Provider<bool>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.any((item) => !item.isRead);
});
