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
