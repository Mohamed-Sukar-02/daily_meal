import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
//   • Rate-limit state is persisted in SharedPreferences so a restart of the
//     app does NOT reset the lockout / attempt counter.
// ---------------------------------------------------------------------------

/// Why an admin login attempt failed.
///
/// This service is pure Dart with no `BuildContext`, so it reports a stable
/// code plus the numbers the message needs. The UI layer maps the code to
/// localised copy (`AppStrings.admin*`) — no display text lives here.
enum AdminAuthFailure { emptyPassword, lockedOut, notConfigured, wrongPassword }

class AdminAuthResult {
  final bool isSuccess;
  final bool isLockedOut;
  final AdminAuthFailure? failure;

  /// Attempts left before the lockout kicks in ([AdminAuthFailure.wrongPassword]).
  final int remainingAttempts;

  /// Minutes left in the lockout window ([AdminAuthFailure.lockedOut]).
  final int lockoutMinutes;

  const AdminAuthResult._({
    required this.isSuccess,
    required this.isLockedOut,
    this.failure,
    this.remainingAttempts = 0,
    this.lockoutMinutes = 0,
  });

  factory AdminAuthResult.success() =>
      const AdminAuthResult._(isSuccess: true, isLockedOut: false);

  factory AdminAuthResult.failure(
    AdminAuthFailure failure, {
    int remainingAttempts = 0,
  }) =>
      AdminAuthResult._(
        isSuccess: false,
        isLockedOut: false,
        failure: failure,
        remainingAttempts: remainingAttempts,
      );

  factory AdminAuthResult.lockedOut(int minutes) => AdminAuthResult._(
        isSuccess: false,
        isLockedOut: true,
        failure: AdminAuthFailure.lockedOut,
        lockoutMinutes: minutes,
      );
}

class AdminAuthService {
  AdminAuthService._() {
    // Best-effort early load so the sync getters are accurate ASAP.
    // verifyPassword() always awaits _ensureLoaded() for correctness.
    unawaited(_ensureLoaded());
  }
  static final AdminAuthService instance = AdminAuthService._();

  // ---------- Rate limiting ----------
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  static const Duration _attemptWindow = Duration(minutes: 2);

  // ---------- Persistence (brute-force state survives app restarts) ----------
  static const String _kLockoutUntilMs = 'admin_lockout_until_ms';
  static const String _kAttemptTimesMs = 'admin_attempt_times_ms';

  DateTime? _lockoutUntil;
  final List<DateTime> _attemptTimes = [];
  Future<void>? _loadFuture;

  /// Loads the persisted rate-limit state exactly once.
  Future<void> _ensureLoaded() {
    return _loadFuture ??= _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutMs = prefs.getInt(_kLockoutUntilMs);
      if (lockoutMs != null) {
        final lockout = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
        if (DateTime.now().isBefore(lockout)) {
          _lockoutUntil = lockout;
        } else {
          // Stale lockout left by a previous run — drop it.
          await prefs.remove(_kLockoutUntilMs);
        }
      }
      final rawAttempts =
          prefs.getStringList(_kAttemptTimesMs) ?? const <String>[];
      final now = DateTime.now();
      _attemptTimes
        ..clear()
        ..addAll(
          rawAttempts
              .map(int.tryParse)
              .whereType<int>()
              .map(DateTime.fromMillisecondsSinceEpoch)
              .where((t) => now.difference(t) <= _attemptWindow),
        );
    } catch (e) {
      debugPrint('[AdminAuthService] persisted state load error: $e');
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lockoutUntil != null) {
        await prefs.setInt(
            _kLockoutUntilMs, _lockoutUntil!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_kLockoutUntilMs);
      }
      final now = DateTime.now();
      final recent = _attemptTimes
          .where((t) => now.difference(t) <= _attemptWindow)
          .toList();
      // Bound storage: only the newest attempts matter for rate limiting.
      if (recent.length > 20) recent.removeRange(0, recent.length - 20);
      await prefs.setStringList(
        _kAttemptTimesMs,
        recent.map((t) => t.millisecondsSinceEpoch.toString()).toList(),
      );
    } catch (e) {
      debugPrint('[AdminAuthService] persisted state save error: $e');
    }
  }

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
      unawaited(_persistState());
      return false;
    }
    return true;
  }

  Duration? get remainingLockout {
    if (_lockoutUntil == null) return null;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<void> _recordFailedAttempt() async {
    final now = DateTime.now();
    _attemptTimes.add(now);
    _attemptTimes.removeWhere((t) => now.difference(t) > _attemptWindow);
    if (_attemptTimes.length >= _maxAttempts) {
      _lockoutUntil = now.add(_lockoutDuration);
    }
    await _persistState();
  }

  Future<void> _resetAttempts() async {
    _attemptTimes.clear();
    _lockoutUntil = null;
    await _persistState();
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
    // Rate-limit state must reflect previous runs before any decision.
    await _ensureLoaded();

    if (input.trim().isEmpty) {
      return AdminAuthResult.failure(AdminAuthFailure.emptyPassword);
    }

    if (isLockedOut) {
      final mins = remainingLockout?.inMinutes ?? 5;
      return AdminAuthResult.lockedOut(mins);
    }

    final storedHash = await _fetchHashFromFirestore();

    if (storedHash == null || storedHash.isEmpty) {
      // No hash configured yet — deny access and guide admin.
      await _recordFailedAttempt();
      return AdminAuthResult.failure(AdminAuthFailure.notConfigured);
    }

    final inputHash = _sha256hex(input.trim());

    if (_constantTimeEquals(inputHash, storedHash)) {
      await _resetAttempts();
      return AdminAuthResult.success();
    }

    await _recordFailedAttempt();
    final remaining = _maxAttempts - _attemptTimes.length;
    if (remaining > 0) {
      return AdminAuthResult.failure(
        AdminAuthFailure.wrongPassword,
        remainingAttempts: remaining,
      );
    }
    return AdminAuthResult.lockedOut(_lockoutDuration.inMinutes);
  }

  /// Invalidates the local cache (call after the web panel updates the hash).
  void invalidateCache() {
    _cachedHash = null;
    _cacheTime = null;
  }
}
