import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared gate for the "Cloud on Wi-Fi only" user preference, callable from
/// plain service singletons that have no Riverpod [Ref].
///
/// Source of truth: the same SharedPreferences key that [WifiOnlyCloudNotifier]
/// in `lib/core/providers/network_provider.dart` writes. Read by value, not
/// through Riverpod, because these services are plain singletons.
///
/// Fail-open on any read error: the policy default is `false`
/// (cloud allowed everywhere), so a corrupt preferences read must not
/// silently disable cloud access the user never opted out of.
class CloudPolicy {
  CloudPolicy._();

  /// Must stay equal to `_kWifiOnlyKey` in `network_provider.dart`.
  static const String _wifiOnlyKey = 'wifi_only_cloud_access';

  /// Returns `true` when a cloud transfer is permitted right now:
  /// - the Wi-Fi-only switch is off (default), OR
  /// - the switch is on AND an unmetered connection is actually active.
  static Future<bool> isCloudAllowedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wifiOnly = prefs.getBool(_wifiOnlyKey) ?? false;
      if (!wifiOnly) return true;
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return true; // fail-open
    }
  }
}
