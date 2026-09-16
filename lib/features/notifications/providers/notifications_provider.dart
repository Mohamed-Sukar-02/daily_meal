import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether there are unread notifications.
/// Defaults to true for showcase/initial state.
final unreadNotificationsProvider = StateProvider<bool>((ref) => true);
