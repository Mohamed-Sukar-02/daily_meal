import 'dart:io';
import 'package:flutter/foundation.dart';

class ReachabilityService {
  ReachabilityService._();
  static final ReachabilityService instance = ReachabilityService._();

  Future<bool> isInternetReachable({Duration timeout = const Duration(seconds: 2)}) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    try {
      final socket = await Socket.connect('1.1.1.1', 53, timeout: timeout);
      socket.destroy();
      return true;
    } catch (e) {
      debugPrint('Reachability socket failed: $e');
      return false;
    }
  }

  Future<bool> checkReachabilityWithInterface({
    required bool hasInterface,
    Duration timeout = const Duration(seconds: 2),
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
