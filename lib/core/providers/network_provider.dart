import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/reachability_service.dart';

const String _kWifiOnlyKey = 'wifi_only_cloud_access';

/// Default for "Cloud on Wi-Fi only". It used to be `true` with no switch
/// anywhere in the UI, so every user on mobile data was silently blocked from
/// proposing meals and browsing discovery, and the toast told them to "change
/// the setting" that did not exist. The switch now lives in Settings →
/// Network & Cloud, and the default lets mobile data through. Nobody could
/// have persisted `false` before (no UI wrote the key), so this only changes
/// behaviour for users who never chose anything.
const bool kWifiOnlyCloudDefault = false;

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final wifiOnlyCloudProvider = StateNotifierProvider<WifiOnlyCloudNotifier, bool>((ref) {
  return WifiOnlyCloudNotifier(ref);
});

class WifiOnlyCloudNotifier extends StateNotifier<bool> {
  final Ref ref;

  WifiOnlyCloudNotifier(this.ref) : super(kWifiOnlyCloudDefault) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    state = prefs.getBool(_kWifiOnlyKey) ?? kWifiOnlyCloudDefault;
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

final cloudAccessStatusProvider = Provider<CloudAccessStatus>((ref) {
  final connectivityAsync = ref.watch(connectivityProvider);
  final wifiOnly = ref.watch(wifiOnlyCloudProvider);

  final connectivity = connectivityAsync.valueOrNull;
  if (connectivity == null) {
    return CloudAccessStatus.allowed;
  }

  if (connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty) {
    return CloudAccessStatus.noConnection;
  }

  if (wifiOnly && !connectivity.contains(ConnectivityResult.wifi)) {
    return CloudAccessStatus.requiresWifi;
  }

  return CloudAccessStatus.allowed;
});

final _reachabilityCache = _ReachabilityCache();

class _ReachabilityCache {
  bool? lastResult;
  DateTime? lastCheck;
  static const cacheDuration = Duration(seconds: 30);

  /// A failed probe is only trusted briefly: one blip used to pin "offline"
  /// for 30 s, so tapping "propose" again right after reconnecting still
  /// failed without even trying.
  static const negativeCacheDuration = Duration(seconds: 5);

  bool? getIfValid() {
    if (lastResult == null || lastCheck == null) return null;
    final ttl = lastResult! ? cacheDuration : negativeCacheDuration;
    if (DateTime.now().difference(lastCheck!) < ttl) {
      return lastResult;
    }
    return null;
  }

  void set(bool result) {
    lastResult = result;
    lastCheck = DateTime.now();
  }
}

final reachabilityProvider = FutureProvider<bool>((ref) async {
  final connectivityAsync = ref.watch(connectivityProvider);
  final connectivity = connectivityAsync.valueOrNull;

  if (connectivity == null) {
    return true;
  }

  final hasInterface = connectivity.isNotEmpty && !connectivity.contains(ConnectivityResult.none);
  if (!hasInterface) return false;

  final cached = _reachabilityCache.getIfValid();
  if (cached != null) return cached;

  final reachable = await ReachabilityService.instance.isInternetReachable(
    timeout: const Duration(seconds: 3),
  );
  _reachabilityCache.set(reachable);
  return reachable;
});

final cloudAccessStatusFutureProvider = FutureProvider.autoDispose<CloudAccessStatus>((ref) async {
  final connectivityAsync = ref.watch(connectivityProvider);
  final wifiOnly = ref.watch(wifiOnlyCloudProvider);
  final connectivity = connectivityAsync.valueOrNull ?? await Connectivity().checkConnectivity();

  if (connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty) {
    return CloudAccessStatus.noConnection;
  }

  if (wifiOnly && !connectivity.contains(ConnectivityResult.wifi)) {
    return CloudAccessStatus.requiresWifi;
  }

  final hasInterface = connectivity.isNotEmpty && !connectivity.contains(ConnectivityResult.none);
  if (!hasInterface) return CloudAccessStatus.noConnection;

  final cached = _reachabilityCache.getIfValid();
  bool reachable;
  if (cached != null) {
    reachable = cached;
  } else {
    reachable = await ReachabilityService.instance.isInternetReachable(
      timeout: const Duration(seconds: 3),
    );
    _reachabilityCache.set(reachable);
  }

  if (!reachable) {
    return CloudAccessStatus.noConnection;
  }

  return CloudAccessStatus.allowed;
});

enum CloudAccessStatus {
  allowed,
  noConnection,
  requiresWifi,
}
