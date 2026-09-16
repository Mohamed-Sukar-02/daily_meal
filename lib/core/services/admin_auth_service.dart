import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// AdminAuthService — Mobile App
//
// Security architecture:
//   • NO secret is stored in the source code.
//   • The SHA-256 hash of the admin password is stored in Firestore at:
//       admin_config/security  { "passwordHash": "<SHA256 hex>" }
//   • The web admin panel is the ONLY place that can update this document.
//   • The mobile app reads the hash at verification time (with a short cache),
//     hashes the user's input locally, and compares using constant-time.
//   • Rate limiting prevents brute-force (5 attempts → 5 min lockout).
// ---------------------------------------------------------------------------

class AdminAuthResult {
  final bool isSuccess;
  final bool isLockedOut;
  final String? errorMessage;

  const AdminAuthResult._({
    required this.isSuccess,
    required this.isLockedOut,
    this.errorMessage,
  });

  factory AdminAuthResult.success() =>
      const AdminAuthResult._(isSuccess: true, isLockedOut: false);

  factory AdminAuthResult.failure(String msg) =>
      AdminAuthResult._(isSuccess: false, isLockedOut: false, errorMessage: msg);

  factory AdminAuthResult.lockedOut(String msg) =>
      AdminAuthResult._(isSuccess: false, isLockedOut: true, errorMessage: msg);
}

class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  // ---------- Rate limiting ----------
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  static const Duration _attemptWindow = Duration(minutes: 2);

  DateTime? _lockoutUntil;
  final List<DateTime> _attemptTimes = [];

  // ---------- Firestore hash cache ----------
  // Cached to avoid a Firestore read on every keystroke.
  String? _cachedHash;
  DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 15);

  // ---------- Rate limit helpers ----------

  bool get isLockedOut {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _lockoutUntil = null;
      _attemptTimes.clear();
      return false;
    }
    return true;
  }

  Duration? get remainingLockout {
    if (_lockoutUntil == null) return null;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  void _recordFailedAttempt() {
    final now = DateTime.now();
    _attemptTimes.add(now);
    _attemptTimes.removeWhere((t) => now.difference(t) > _attemptWindow);
    if (_attemptTimes.length >= _maxAttempts) {
      _lockoutUntil = now.add(_lockoutDuration);
    }
  }

  void _resetAttempts() {
    _attemptTimes.clear();
    _lockoutUntil = null;
  }

  // ---------- Crypto helpers ----------

  String _sha256hex(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Constant-time string comparison to prevent timing attacks.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // ---------- Firestore fetch ----------

  /// Fetches the admin password hash from Firestore `admin_config/security`.
  /// Returns null if the document doesn't exist or an error occurs.
  Future<String?> _fetchHashFromFirestore() async {
    // Use cache if still fresh.
    if (_cachedHash != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedHash;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_config')
          .doc('security')
          .get(const GetOptions(source: Source.serverAndCache));

      final hash = doc.data()?['passwordHash'] as String?;
      if (hash != null && hash.isNotEmpty) {
        _cachedHash = hash.trim().toLowerCase();
        _cacheTime = DateTime.now();
        return _cachedHash;
      }
      return null;
    } catch (e) {
      debugPrint('[AdminAuthService] Firestore fetch error: $e');
      // Try returning cached value even if stale (offline tolerance).
      return _cachedHash;
    }
  }

  // ---------- Public API ----------

  /// Verifies the admin password against the hash stored in Firestore.
  Future<AdminAuthResult> verifyPassword(String input) async {
    if (input.trim().isEmpty) {
      return AdminAuthResult.failure('كلمة المرور لا يمكن أن تكون فارغة');
    }

    if (isLockedOut) {
      final mins = remainingLockout?.inMinutes ?? 5;
      return AdminAuthResult.lockedOut(
        'تم تعليق المحاولات مؤقتاً — حاول مجدداً بعد $mins دقائق',
      );
    }

    final storedHash = await _fetchHashFromFirestore();

    if (storedHash == null || storedHash.isEmpty) {
      // No hash configured yet — deny access and guide admin.
      _recordFailedAttempt();
      return AdminAuthResult.failure(
        'لم يتم إعداد كلمة مرور الأدمن بعد.\n'
        'يرجى تعيينها من لوحة التحكم على الموقع.',
      );
    }

    final inputHash = _sha256hex(input.trim());

    if (_constantTimeEquals(inputHash, storedHash)) {
      _resetAttempts();
      return AdminAuthResult.success();
    }

    _recordFailedAttempt();
    final remaining = _maxAttempts - _attemptTimes.length;
    return AdminAuthResult.failure(
      remaining > 0
          ? 'كلمة المرور غير صحيحة — تبقى $remaining محاولة'
          : 'تم تعليق المحاولات مؤقتاً',
    );
  }

  /// Invalidates the local cache (call after the web panel updates the hash).
  void invalidateCache() {
    _cachedHash = null;
    _cacheTime = null;
  }
}
