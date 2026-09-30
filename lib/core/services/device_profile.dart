import 'package:shared_preferences/shared_preferences.dart';

/// The two device facts the admin panel's `segment` targeting is judged against.
class DeviceProfile {
  DeviceProfile({required this.firstOpenedAt, required this.hasCooked});

  static const String _kFirstOpenedAtKey = 'first_opened_at_millis';

  /// Stand-in first-open date for installs that predate this field. Far enough
  /// in the past that an update never reads as a fresh install, which would
  /// keep a veteran inside every `new` window for a year.
  static final DateTime _preExistingInstallSeed = DateTime(2000, 1, 1);

  /// When this device first opened the app. Written once and never rewritten,
  /// so an update never resets the install's tenure.
  final DateTime firstOpenedAt;

  /// Whether the cooking log holds anything at all.
  final bool hasCooked;

  /// Reads the persisted first-open date, seeding it on the very first launch.
  ///
  /// [existingInstall] only matters while seeding: the caller derives it from
  /// data that already outlives this field (onboarding finished, or a logged
  /// meal). [now] is the clock a test can pin.
  static Future<DeviceProfile> load({
    required bool existingInstall,
    required bool hasCooked,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final stored = prefs.getInt(_kFirstOpenedAtKey);
    if (stored != null) {
      return DeviceProfile(
        firstOpenedAt: DateTime.fromMillisecondsSinceEpoch(stored),
        hasCooked: hasCooked,
      );
    }

    final seeded = existingInstall ? _preExistingInstallSeed : (now ?? DateTime.now());
    await prefs.setInt(_kFirstOpenedAtKey, seeded.millisecondsSinceEpoch);
    return DeviceProfile(firstOpenedAt: seeded, hasCooked: hasCooked);
  }

  /// Whether this device still counts as new: inside the first [days] days and
  /// nothing cooked yet. `returning` is its exact complement, so the two
  /// together cover `all`.
  bool isNewWithin(int days, {DateTime? now}) {
    final tenureDays = (now ?? DateTime.now()).difference(firstOpenedAt).inDays;
    return !hasCooked && tenureDays <= days;
  }
}
