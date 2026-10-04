/// Converts an admin-authored or external notification target into a safe route the app owns.
/// Unknown, external, malformed, or overlong values always fallback to Home ('/').
String sanitizeNotificationRoute(Object? raw) {
  if (raw is! String) return '/';
  final value = raw.trim();
  if (value.isEmpty || value.length > 256) return '/';

  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.host.isNotEmpty ||
      uri.hasFragment ||
      !uri.path.startsWith('/')) {
    return '/';
  }

  bool hasNoQuery() => uri.queryParametersAll.isEmpty;
  bool hasSingleQuery(String key, String expected) {
    final values = uri.queryParametersAll[key];
    return uri.queryParametersAll.length == 1 &&
        values != null &&
        values.length == 1 &&
        values.single == expected;
  }

  switch (uri.path) {
    case '/':
    case '/history':
    case '/notifications':
      return hasNoQuery() ? uri.path : '/';
    case '/vault':
      return hasNoQuery() || hasSingleQuery('tab', 'explore')
          ? uri.toString()
          : '/';
    case '/settings':
      return hasNoQuery() || hasSingleQuery('section', 'notifications')
          ? uri.toString()
          : '/';
  }

  final segments = uri.pathSegments;
  if (segments.length == 2 && segments.first == 'meal' && hasNoQuery()) {
    final id = int.tryParse(segments[1]);
    return id != null && id > 0 ? uri.path : '/';
  }

  if (segments.length == 3 &&
      segments[0] == 'meal' &&
      segments[1] == 'cloud' &&
      hasNoQuery()) {
    final cloudId = segments[2];
    final safeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    return safeId.hasMatch(cloudId) ? uri.path : '/';
  }

  return '/';
}

/// The vault row a notification route points at, when it points at one.
///
/// A broadcast carries no picture of its own; the admin panel sends the meal it
/// is about, and the row behind that route is what holds the photo. Both shapes
/// [sanitizeNotificationRoute] allows are covered: `/meal/<id>` for a meal that
/// lives on-device, `/meal/cloud/<id>` for one downloaded from the vault.
class MealTarget {
  const MealTarget.local(int this.localId) : cloudId = null;
  const MealTarget.cloud(String this.cloudId) : localId = null;

  final int? localId;
  final String? cloudId;

  @override
  bool operator ==(Object other) =>
      other is MealTarget &&
      other.localId == localId &&
      other.cloudId == cloudId;

  @override
  int get hashCode => Object.hash(localId, cloudId);

  @override
  String toString() => localId != null
      ? 'MealTarget.local($localId)'
      : 'MealTarget.cloud($cloudId)';
}

/// Reads the [MealTarget] out of an already-sanitized route. Anything that is
/// not a meal route — Home, Settings, or the `'/'` the sanitizer falls back to
/// — yields `null`, so a broadcast with no meal behind it never asks the
/// database for one.
MealTarget? mealTargetFromRoute(String? route) {
  final value = route?.trim() ?? '';
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  // The sanitizer already dropped anything carrying a scheme or host; the same
  // check here keeps a hand-built [NotificationItem] from pointing a photo at
  // an absolute URL that merely looks like a meal route.
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
  final segments = uri.pathSegments;

  if (segments.length == 2 && segments.first == 'meal') {
    final id = int.tryParse(segments[1]);
    if (id != null && id > 0) return MealTarget.local(id);
    return null;
  }

  if (segments.length == 3 && segments[0] == 'meal' && segments[1] == 'cloud') {
    final cloudId = segments[2];
    return cloudId.isEmpty ? null : MealTarget.cloud(cloudId);
  }

  return null;
}
