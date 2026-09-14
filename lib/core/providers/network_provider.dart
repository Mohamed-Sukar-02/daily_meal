import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kWifiOnlyKey = 'wifi_only_cloud_access';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final wifiOnlyCloudProvider = StateNotifierProvider<WifiOnlyCloudNotifier, bool>((ref) {
  return WifiOnlyCloudNotifier(ref);
});

class WifiOnlyCloudNotifier extends StateNotifier<bool> {
  final Ref ref;

  WifiOnlyCloudNotifier(this.ref) : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    state = prefs.getBool(_kWifiOnlyKey) ?? true; // Default to true as requested
  }

  Future<void> setWifiOnly(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kWifiOnlyKey, value);
    state = value;
  }
}

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// A provider that checks if the user has access to cloud features based on their current connection and settings
final cloudAccessStatusProvider = FutureProvider.autoDispose<CloudAccessStatus>((ref) async {
  final connectivity = await Connectivity().checkConnectivity();
  final wifiOnly = ref.watch(wifiOnlyCloudProvider);

  if (connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty) {
    return CloudAccessStatus.noConnection;
  }

  if (wifiOnly && !connectivity.contains(ConnectivityResult.wifi)) {
    return CloudAccessStatus.requiresWifi;
  }

  return CloudAccessStatus.allowed;
});

enum CloudAccessStatus {
  allowed,
  noConnection,
  requiresWifi,
}
