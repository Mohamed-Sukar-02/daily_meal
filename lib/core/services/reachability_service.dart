import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Answers "can this device actually reach the internet right now?".
///
/// The old probe opened a raw TCP socket to `1.1.1.1:53` (DNS). Many mobile
/// carriers, captive/corporate Wi-Fi and some home routers block outbound
/// port 53 to public resolvers, so the app reported "no connection" — and
/// refused to send proposals or open discovery — on perfectly working
/// networks. The probe now asks HTTPS endpoints the app really depends on
/// (Google's connectivity check + Firestore itself) over port 443, and keeps
/// a raw 443 socket as a last resort. Any one success means reachable.
class ReachabilityService {
  ReachabilityService._();
  static final ReachabilityService instance = ReachabilityService._();

  /// Endpoints tried in parallel. `generate_204` is Android's own captive
  /// portal check; `firestore.googleapis.com` is the host proposals write to,
  /// so reaching it is the most honest answer for cloud features.
  @visibleForTesting
  static const List<String> probeUrls = <String>[
    'https://clients3.google.com/generate_204',
    'https://firestore.googleapis.com/',
  ];

  Future<bool> isInternetReachable({Duration timeout = const Duration(seconds: 3)}) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;

    final probes = <Future<bool>>[
      for (final url in probeUrls) _httpsProbe(url, timeout),
      _socketProbe('firestore.googleapis.com', 443, timeout),
    ];

    // First `true` wins; resolve `false` only when every probe has failed.
    final completer = Completer<bool>();
    var remaining = probes.length;
    for (final probe in probes) {
      probe.then((ok) {
        if (completer.isCompleted) return;
        if (ok) {
          completer.complete(true);
        } else if (--remaining == 0) {
          completer.complete(false);
        }
      });
    }
    return completer.future;
  }

  Future<bool> _httpsProbe(String url, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.headUrl(Uri.parse(url)).timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      await response.drain<void>().catchError((_) {});
      // Any HTTP answer (204, 200, 404, 3xx…) proves a working route to the
      // host; only transport failures mean "offline".
      return true;
    } catch (e) {
      debugPrint('Reachability HTTPS probe failed ($url): $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _socketProbe(String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (e) {
      debugPrint('Reachability socket probe failed ($host:$port): $e');
      return false;
    }
  }

  Future<bool> checkReachabilityWithInterface({
    required bool hasInterface,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!hasInterface) return false;
    try {
      return await isInternetReachable(timeout: timeout).timeout(
        timeout + const Duration(seconds: 1),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }
}
