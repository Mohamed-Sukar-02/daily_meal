import '../../../core/navigation/notification_route.dart';
import '../../../core/services/device_profile.dart';

enum NotificationType { meal, reminder, update }

/// Which day band a broadcast falls into in the feed.
enum NotificationAge { today, yesterday, earlier }

/// The band [time] belongs to, counted in calendar days rather than elapsed
/// hours, so a broadcast from 11 pm yesterday sits under "Yesterday" beside its
/// siblings instead of splitting the "Today" band. A timestamp in the future —
/// a device clock that drifted — is treated as today.
NotificationAge notificationAgeOf(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final days = DateTime(
    reference.year,
    reference.month,
    reference.day,
  ).difference(DateTime(time.year, time.month, time.day)).inDays;
  if (days <= 0) return NotificationAge.today;
  if (days == 1) return NotificationAge.yesterday;
  return NotificationAge.earlier;
}

/// Which lifecycle slice a broadcast was addressed to, as the admin panel
/// writes it: `segment: { v: 1, kind: 'all' | 'new' | 'returning', days: int }`.
class NotificationSegment {
  const NotificationSegment({
    required this.version,
    required this.kind,
    required this.days,
  });

  /// The shape every document that carries no segment gets.
  const NotificationSegment.all()
    : this(version: _supportedVersion, kind: 'all', days: 0);

  /// Highest segment layout this build knows how to evaluate.
  static const int _supportedVersion = 1;

  final int version;
  final String kind;
  final int days;

  /// Lenient by design: a missing field, or one that is not a map, means "for
  /// everyone" — the state every document written before segmentation existed
  /// was in. A map is carried through exactly as written, with values of the
  /// wrong type landing on the fail-closed side (`version` 0, blank `kind`,
  /// `days` 0) so [matchesDevice] can still judge them.
  static NotificationSegment parse(Object? raw) {
    if (raw is! Map) return const NotificationSegment.all();
    return NotificationSegment(
      version: raw['v'] is int ? raw['v'] as int : 0,
      kind: raw['kind'] is String ? raw['kind'] as String : '',
      days: raw['days'] is int ? raw['days'] as int : 0,
    );
  }

  /// The closed-world order the wire contract specifies: everyone-destined
  /// first, then anything this build cannot interpret, then the device's own
  /// lifecycle. A rule that cannot be read stays silent rather than leak to the
  /// wrong audience — including [profile] being unreadable, which costs a
  /// lifecycle broadcast its verdict but never an everyone-destined one.
  bool matchesDevice(DeviceProfile? profile, {DateTime? now}) {
    if (kind == 'all') return true;
    if (version < 1 || version > _supportedVersion) return false;
    if (kind != 'new' && kind != 'returning') return false;
    if (profile == null || days < 1) return false;
    return (kind == 'new') == profile.isNewWithin(days, now: now);
  }
}

class NotificationItem {
  final String id;
  final Map<String, String> title;
  final Map<String, String> subtitle;
  final DateTime time;
  final bool isRead;
  final NotificationType type;
  final String? route;

  /// Who the broadcast was addressed to.
  final NotificationSegment segment;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isRead = false,
    required this.type,
    this.route,
    this.segment = const NotificationSegment.all(),
  });

  /// Whether this device is inside the broadcast's lifecycle slice. Unlike a
  /// translated field, a rule this build cannot read has no safe fallback:
  /// showing it to the wrong device is the failure that matters here.
  bool matchesDevice(DeviceProfile? profile, {DateTime? now}) =>
      segment.matchesDevice(profile, now: now);

  NotificationItem copyWith({
    String? id,
    Map<String, String>? title,
    Map<String, String>? subtitle,
    DateTime? time,
    bool? isRead,
    NotificationType? type,
    String? route,
    NotificationSegment? segment,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      route: route ?? this.route,
      segment: segment ?? this.segment,
    );
  }

  String getLocalizedTitle(bool isEn) => title[isEn ? 'en' : 'ar'] ?? '';
  String getLocalizedSubtitle(bool isEn) => subtitle[isEn ? 'en' : 'ar'] ?? '';

  /// The vault row this broadcast is about, if it is about one at all.
  MealTarget? get mealTarget => mealTargetFromRoute(route);

  /// The day band this broadcast is grouped under.
  NotificationAge get age => notificationAgeOf(time);
}
