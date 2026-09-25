enum NotificationType { meal, reminder, update }

class NotificationItem {
  final String id;
  final Map<String, String> title;
  final Map<String, String> subtitle;
  final DateTime time;
  final bool isRead;
  final NotificationType type;
  final String? route;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isRead = false,
    required this.type,
    this.route,
  });

  NotificationItem copyWith({
    String? id,
    Map<String, String>? title,
    Map<String, String>? subtitle,
    DateTime? time,
    bool? isRead,
    NotificationType? type,
    String? route,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      route: route ?? this.route,
    );
  }

  String getLocalizedTitle(bool isEn) => title[isEn ? 'en' : 'ar'] ?? '';
  String getLocalizedSubtitle(bool isEn) => subtitle[isEn ? 'en' : 'ar'] ?? '';
}
