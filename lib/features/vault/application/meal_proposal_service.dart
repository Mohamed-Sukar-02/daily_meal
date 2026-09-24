import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/network_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/models/cloud_meal.dart';
import '../providers/discovery_providers.dart';
import 'meal_sync_diff.dart';

// ---------------------------------------------------------------------------
// MealProposalService — Cloud Staging Export
//
// Sends a local vault meal to the `staging_meals` Firestore collection for
// admin review (see `firestore.rules::isValidStagingMeal`). Design rules:
//
//   • The payload builder is PURE (no Firebase, no I/O) so unit tests can
//     assert byte-for-byte parity with the security rules.
//   • Only keys the rules allow are ever written — notably `shortName` is
//     NOT in the allow-list and must never be sent.
//   • Photos: the picker already compresses at capture time
//     (`maxWidth: 1080`, `imageQuality: 85`), so staging simply gates on the
//     on-disk size (≤ 500 KB) and uploads via Cloudinary Unsigned Direct Upload.
//     NOTE TO AI AGENTS: We DO NOT use Firebase Storage. Firebase recently
//     began enforcing the Blaze plan for new buckets, breaking free Spark
//     accounts. Therefore, all images are uploaded directly to Cloudinary
//     (cloudName: bzd1vjrs, preset: daily meal). Oversized or
//     unreadable photos are skipped — the proposal still goes through.
//     No new compression dependency is introduced (per the implementation plan).
//   • Auth: staging creates require `request.auth != null`; the app has no
//     user accounts, so we sign in anonymously via firebase_auth (already a
//     project dependency) exactly when a proposal is made.
//   • Failure reporting: every stage (ledger, sign-in, write) is caught
//     separately and classified into a [ProposalFailureReason], because a
//     disabled anonymous provider, rejected security rules and a dead network
//     all look identical to the user otherwise.
//   • Duplicate guard: `staging_meals` is admin-read-only, so the client
//     cannot query its own proposals. A SharedPreferences ledger
//     (mealId → updatedAt-ms at submit time) blocks accidental re-sends and
//     automatically re-opens the door once the meal is edited.
//   • This layer carries no display text: it returns
//     a stable [ProposalOutcomeCode] and the UI maps it through [AppStrings].
// ---------------------------------------------------------------------------

/// Stable result codes for a staging proposal. The UI localises these via
/// [AppStrings] (`proposal*` strings) — no copy lives in this layer.
enum ProposalOutcomeCode {
  /// Document created in `staging_meals` (awaiting admin review).
  submitted,

  /// This exact meal version was already proposed (edit it to re-propose).
  alreadyProposed,

  /// Cloud unreachable, or the user is on mobile data with Wi-Fi-only mode on.
  blockedNoConnection,
  blockedRequiresWifi,

  /// Name shorter than the 2-character minimum enforced by the rules —
  /// detected locally to avoid a pointless rejected round-trip.
  invalidName,

  /// Today's allowance is spent. Also detected locally, before any network
  /// call, so a refused proposal costs no Firestore write.
  dailyLimitReached,

  /// A cloud-linked meal still identical to its cloud copy: the vault already
  /// has this exact meal, so proposing it again would only buy the reviewer a
  /// second look at something they approved once.
  cloudUnchanged,

  /// Auth / Firestore / Storage failure. [ProposalOutcome.reason] says which
  /// stage broke and [ProposalOutcome.cause] keeps the raw provider error.
  failed,
}

/// Which known failure could be identified behind [ProposalOutcomeCode.failed].
///
/// The app used to report every rejection with one generic message, which made
/// a misconfigured Firebase project indistinguishable from a dead network. Each
/// reason maps to a short localised line in [AppStrings]; the raw provider
/// error is appended only when nothing matched ([unknown]).
enum ProposalFailureReason {
  /// `Firebase.initializeApp` never completed, or the client API key is wrong,
  /// so no Firebase singleton exists to call.
  firebaseNotReady,

  /// Anonymous sign-in is switched off in Firebase Console → Authentication →
  /// Sign-in method. Staging writes demand `request.auth != null`.
  anonymousProviderDisabled,

  /// Anonymous sign-in exists but rejected the caller for another reason.
  anonymousSignInRejected,

  /// Firestore refused the `staging_meals` create — deployed security rules do
  /// not accept this payload, or the caller is not the `proposedBy` uid.
  writePermissionDenied,

  /// Firestore was unreachable at write time (no route, DNS failure, timeout).
  writeUnreachable,

  /// The meal carries a local photo that could not be shipped (missing file,
  /// unreadable, or over the size the staging document allows). The proposal
  /// is aborted rather than filed photoless behind the user's back.
  photoRejected,

  /// The photo host refused or failed the upload.
  photoUploadFailed,

  /// Anything else — the UI shows the raw error instead of a guess.
  unknown,
}

/// Maps a raw provider error onto a [ProposalFailureReason]. Pure: no Firebase
/// singletons, so tests can feed it hand-built exceptions.
class ProposalFailureDiagnoser {
  const ProposalFailureDiagnoser._();

  static ProposalFailureReason classify(Object error) {
    final code = errorCode(error);
    final haystack = '$code ${error.toString()}'.toLowerCase();

    // Auth never initialised: `FirebaseAuth.instance` / `FirebaseFirestore
    // .instance` throw a plain StateError before any network call happens.
    if (haystack.contains('no firebase app') ||
        haystack.contains('firebase apps were not initialised') ||
        haystack.contains('invalid-api-key') ||
        haystack.contains('api-key-not-valid')) {
      return ProposalFailureReason.firebaseNotReady;
    }

    // `operation-not-allowed` / `unsupported-operation` / `configuration-
    // not-found` are the shapes Firebase Auth uses for a disabled provider.
    if (haystack.contains('operation-not-allowed') ||
        haystack.contains('unsupported-operation') ||
        haystack.contains('configuration-not-found') ||
        haystack.contains('provider is disabled')) {
      return ProposalFailureReason.anonymousProviderDisabled;
    }

    // FirebaseAuthException codes are bare (`Too-Many-Requests`, `user-disabled`)
    // and are not prefixed with `auth/`, so the class is the reliable signal
    // that the sign-in stage — not the write — is what answered.
    if (error is FirebaseAuthException) {
      return ProposalFailureReason.anonymousSignInRejected;
    }

    if (code == 'permission-denied' ||
        haystack.contains('permission-denied') ||
        haystack.contains('permission denied')) {
      return ProposalFailureReason.writePermissionDenied;
    }

    if (code == 'unavailable' ||
        haystack.contains('failed host lookup') ||
        haystack.contains('socketexception') ||
        haystack.contains('timeout')) {
      return ProposalFailureReason.writeUnreachable;
    }

    return ProposalFailureReason.unknown;
  }

  /// The `code` member that `FirebaseAuthException`, `FirebaseException` and
  /// `FirebaseFirestoreException` all carry, read structurally so this layer
  /// does not have to depend on their exact class hierarchies.
  static String? errorCode(Object error) {
    try {
      final dynamic code = (error as dynamic).code;
      return code is String ? code : null;
    } catch (_) {
      return null;
    }
  }

  /// One-line raw error for the debug-only suffix: code plus message, collapsed
  /// to a single line and capped so it cannot blow out the toast.
  static String describe(Object error) {
    final code = errorCode(error);
    final text = error
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final joined = code == null ? text : '$code · $text';
    return joined.length <= 180 ? joined : '${joined.substring(0, 177)}…';
  }
}

class ProposalOutcome {
  final ProposalOutcomeCode code;

  /// Raw error for [ProposalOutcomeCode.failed] (logged verbatim, shown only
  /// when [reason] is [ProposalFailureReason.unknown]).
  final Object? cause;

  /// Which stage failed, for [ProposalOutcomeCode.failed].
  final ProposalFailureReason reason;

  /// True when a photo made it into the payload (uploaded or remote URL).
  final bool imageAttached;

  const ProposalOutcome._(this.code,
      {this.cause, this.reason = ProposalFailureReason.unknown, this.imageAttached = false});

  factory ProposalOutcome.submitted({bool imageAttached = false}) =>
      ProposalOutcome._(ProposalOutcomeCode.submitted,
          imageAttached: imageAttached);

  factory ProposalOutcome.alreadyProposed() =>
      const ProposalOutcome._(ProposalOutcomeCode.alreadyProposed);

  factory ProposalOutcome.blocked(CloudAccessStatus status) => ProposalOutcome._(
        status == CloudAccessStatus.requiresWifi
            ? ProposalOutcomeCode.blockedRequiresWifi
            : ProposalOutcomeCode.blockedNoConnection,
      );

  factory ProposalOutcome.invalidName() =>
      const ProposalOutcome._(ProposalOutcomeCode.invalidName);

  factory ProposalOutcome.dailyLimitReached() =>
      const ProposalOutcome._(ProposalOutcomeCode.dailyLimitReached);

  factory ProposalOutcome.cloudUnchanged() =>
      const ProposalOutcome._(ProposalOutcomeCode.cloudUnchanged);

  /// Builds a [ProposalOutcomeCode.failed] outcome and classifies [error] in
  /// one step, so no call site can forget to say *why* it failed.
  static ProposalOutcome failed(
    Object error, {
    String? stage,
    ProposalFailureReason? reason,
  }) {
    final classified = reason ?? ProposalFailureDiagnoser.classify(error);
    debugPrint(
      'Proposal failure${stage == null ? '' : ' at $stage'}: '
      '${ProposalFailureDiagnoser.errorCode(error) ?? '-'} '
      '(${classified.name}) — $error',
    );
    return ProposalOutcome._(ProposalOutcomeCode.failed,
        cause: error, reason: classified);
  }

  bool get isSuccess => code == ProposalOutcomeCode.submitted;
}

/// Pure local→cloud vocabulary bridges. The cloud schema (see `CloudMeal` and
/// the Firestore rules) is narrower than the local Drift enums, so every value
/// must map into the allowed set:
///   protein: chicken | beef | fish | meatless | other
///   carbs:   rice | pasta | bread | none
///   category: tabeekh | casserole | dry_sandwich | popular | seafood
class MealCloudVocabulary {
  const MealCloudVocabulary._();

  /// Reverse of `DiscoveryNotifier._mapProtein` wherever a round-trip exists:
  /// chicken/beef/fish are identities and legume ↔ meatless. `dairy` and
  /// `none` have no cloud counterpart and fold into `other` (which downloads
  /// back as `none`, matching the discovery default branch).
  static String proteinToCloud(ProteinType protein) {
    switch (protein) {
      case ProteinType.chicken:
        return 'chicken';
      case ProteinType.beef:
        return 'beef';
      case ProteinType.fish:
        return 'fish';
      case ProteinType.legume:
        return 'meatless';
      case ProteinType.dairy:
      case ProteinType.none:
        return 'other';
    }
  }

  /// The cloud knows only rice/pasta/bread; potato & grains fold into `none`
  /// (the honest fallback — claiming bread/rice would mislabel the meal).
  static String carbsToCloud(CarbsType carbs) {
    switch (carbs) {
      case CarbsType.rice:
        return 'rice';
      case CarbsType.pasta:
        return 'pasta';
      case CarbsType.bread:
        return 'bread';
      case CarbsType.potato:
      case CarbsType.grains:
      case CarbsType.none:
        return 'none';
    }
  }

  /// Reverse of `DiscoveryNotifier._mapCategory`: tabeekh/casserole/
  /// dry_sandwich/seafood round-trip; stews are طبيخ-family → tabeekh, and
  /// vegetarian has no cloud slot → popular (the cloud catch-all).
  static String categoryToCloud(MealCategory category) {
    switch (category) {
      case MealCategory.egyptianTraditional:
        return 'tabeekh';
      case MealCategory.ovenBaked:
        return 'casserole';
      case MealCategory.fastFood:
        return 'dry_sandwich';
      case MealCategory.seafood:
        return 'seafood';
      case MealCategory.soupStew:
        return 'tabeekh';
      case MealCategory.vegetarian:
        return 'popular';
    }
  }
}

/// Pure builder + validator helpers for the staging payload.
/// Every constant here mirrors `firestore.rules::isValidStagingMeal`.
class MealProposalPayload {
  const MealProposalPayload._();

  static const int minNameLength = 2;
  static const int maxNameLength = 100;
  static const int minPrepTimeMinutes = 5;
  static const int maxPrepTimeMinutes = 720;
  static const int maxNotesLength = 500;
  static const int maxImageUrlLength = 2048;

  /// Upload gate for locally-picked photos (rules cap staging images at
  /// 500 KB — see `storage.rules::staging_meal_images`).
  static const int maxImageBytes = 500 * 1024;

  /// Clamps into the rule-enforced window; kept explicit (rather than
  /// `num.clamp`) so the static type stays `int` for Firestore.
  static int clampPrepTime(int minutes) {
    if (minutes < minPrepTimeMinutes) return minPrepTimeMinutes;
    if (minutes > maxPrepTimeMinutes) return maxPrepTimeMinutes;
    return minutes;
  }

  /// Builds the exact document written to `staging_meals`.
  ///
  /// Returns `null` when the meal can never satisfy the rules (name shorter
  /// than [minNameLength] after trimming) so callers fail fast with a
  /// localised message instead of a rejected write.
  ///
  /// Key-set discipline (rules use `hasOnly`):
  ///   name, proteinType, carbsType, category, prepTimeMinutes,
  ///   isFridaySpecial, isBudgetFriendly, isStarterMeal(false),
  ///   createdAt(ISO-8601 string), proposedBy(uid), status('pending'),
  ///   + imageUrl / notes only when meaningful.
  /// `shortName` and `id` are deliberately never sent.
  static Map<String, dynamic>? build({
    required Meal meal,
    required String proposedByUid,
    String? imageUrl,
    DateTime? now,
  }) {
    final name = meal.name.trim();
    if (name.length < minNameLength) return null;

    final notes = meal.notes?.trim() ?? '';
    final createdAt = (now ?? DateTime.now()).toUtc().toIso8601String();
    final url = imageUrl?.trim() ?? '';

    return <String, dynamic>{
      'name': name.length > maxNameLength
          ? name.substring(0, maxNameLength)
          : name,
      'proteinType': MealCloudVocabulary.proteinToCloud(meal.proteinType),
      'carbsType': MealCloudVocabulary.carbsToCloud(meal.carbsType),
      'category': MealCloudVocabulary.categoryToCloud(meal.category),
      'prepTimeMinutes': clampPrepTime(meal.prepTime),
      'isFridaySpecial': meal.isFridaySpecial,
      'isBudgetFriendly': meal.isBudgetFriendly,
      // Rules: when present it MUST be false — only admins may flag starters.
      'isStarterMeal': false,
      if (url.isNotEmpty && url.length <= maxImageUrlLength) 'imageUrl': url,
      if (notes.isNotEmpty)
        'notes': notes.length > maxNotesLength
            ? notes.substring(0, maxNotesLength)
            : notes,
      // Rules require a 10..40-char ISO string (UTC, millisecond precision
      // → 24 chars). `CloudMeal.fromMap` parses it back with DateTime.tryParse.
      'createdAt': createdAt,
      'proposedBy': proposedByUid,
      'status': 'pending',
    };
  }

  /// Classifies a `photoPath` the same way `MealImageResolver` does, without
  /// touching the filesystem (pure, unit-testable).
  static bool isRemoteUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  /// Returns the local photo file when it exists and fits the 500 KB staging
  /// budget; `null` otherwise (proposal proceeds without an image).
  /// The image_picker parameters (`maxWidth: 1080`, `imageQuality: 85`) keep
  /// normal captures well under the cap — this gate only rejects legacy or
  /// externally-imported oversized files. `existsSync/lengthSync` failures
  /// (missing file, bad path) are swallowed by design.
  static File? eligibleImageFile(String? photoPath, {int? maxBytes}) {
    final path = photoPath?.trim() ?? '';
    if (path.isEmpty) return null;
    if (isRemoteUrl(path)) return null;
    if (path.startsWith('assets/') || path.startsWith('asset:')) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final length = file.lengthSync();
      if (length <= 0) return null;
      if (length > (maxBytes ?? maxImageBytes)) return null;
      return file;
    } catch (_) {
      return null;
    }
  }
}

/// SharedPreferences-backed duplicate guard (see header comment).
class ProposalGuard {
  static const String prefsKey = 'staging_proposed_meals_v1';

  final SharedPreferences _prefs;

  ProposalGuard(this._prefs);

  Map<String, int> _read() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
        );
      }
    } catch (_) {
      // Corrupt ledger → treat as empty; a re-proposal is harmless (admin
      // reviews everything anyway).
    }
    return <String, int>{};
  }

  /// True when this exact meal version (same `updatedAt`) was already sent.
  /// Editing the meal bumps `updatedAt` and re-opens proposals.
  bool alreadyProposed(Meal meal) {
    final recorded = _read()['${meal.id}'];
    if (recorded == null) return false;
    return meal.updatedAt.millisecondsSinceEpoch <= recorded;
  }

  Future<void> markProposed(Meal meal) async {
    final ledger = _read();
    ledger['${meal.id}'] = meal.updatedAt.millisecondsSinceEpoch;
    await _prefs.setString(prefsKey, jsonEncode(ledger));
  }
}

/// Proposals filed per calendar day on this device.
///
/// A cap this belongs in the security rules, but Firestore rules cannot count
/// documents: enforcing "N per uid per day" server-side means a counter row
/// written in the same transaction as every proposal, or a Cloud Function.
/// Until one of those exists this is the only thing between the anonymous
/// sign-in the flow performs and an unbounded number of `staging_meals`
/// documents — so it is persisted, and checked before any network work.
class ProposalQuota {
  static const int dailyLimit = 5;
  static const String prefsKey = 'staging_proposal_quota_v1';

  final SharedPreferences _prefs;

  ProposalQuota(this._prefs);

  /// The user's own calendar day, not UTC: "tomorrow" is the day they wait for.
  static String _dayOf(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  /// Proposals already filed today. Rolling into a new day resets to zero, and
  /// a corrupt stored value is treated as an empty counter rather than thrown.
  int usedToday([DateTime? now]) {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return 0;
    final parts = raw.split('|');
    if (parts.length != 2) return 0;
    if (parts[0] != _dayOf(now ?? DateTime.now())) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  bool hasAllowance([DateTime? now]) => usedToday(now) < dailyLimit;

  int remainingToday([DateTime? now]) {
    final left = dailyLimit - usedToday(now);
    return left < 0 ? 0 : left;
  }

  /// Called only once the document really exists, so a rejected or failed
  /// attempt never costs the user one of their slots.
  Future<void> recordProposal([DateTime? now]) async {
    final day = _dayOf(now ?? DateTime.now());
    await _prefs.setString(prefsKey, '$day|${usedToday(now) + 1}');
  }
}

/// Unsigned-direct-upload settings for the photo host.
///
/// Firebase Storage is deliberately unused: the project is on the plan that no
/// longer provisions new buckets. The preset name below is public by design —
/// an unsigned preset is an identifier, not a credential — which is exactly why
/// its server-side configuration has to stay scoped to the staging folder:
/// whatever the preset permits, any client can do.
class CloudinaryConfig {
  const CloudinaryConfig._();

  static const String cloudName = 'bzd1vjrs';
  static const String uploadPreset = 'daily meal';

  static Uri get uploadEndpoint => Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
}

/// Result of trying to ship a meal's photo alongside its proposal.
///
/// [url] stays null when the meal simply has no photo to ship. [error] is set
/// only when a photo *did* exist and could not be shipped — a case the user is
/// told about rather than having a photoless proposal presented as success.
class StagedPhoto {
  final String? url;
  final Object? error;

  /// Whether the photo host was actually contacted, so a file that never made
  /// it off the device reports as rejected rather than as a failed upload.
  final bool uploadAttempted;

  const StagedPhoto._(this.url, this.error, this.uploadAttempted);

  const StagedPhoto.none() : this._(null, null, false);
  const StagedPhoto.withUrl(String url) : this._(url, null, false);
  const StagedPhoto.rejected(Object why) : this._(null, why, false);
  const StagedPhoto.uploadFailed(Object why) : this._(null, why, true);
}

/// Executes the export: daily quota → duplicate guard → anonymous auth →
/// optional photo upload → Firestore create. All dependencies are injectable
/// for tests; defaults are the live Firebase singletons (the app initialises
/// Firebase in `main()`).
class MealProposalService {
  MealProposalService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SharedPreferences? prefs,
  })  : _firestore = firestore,
        _auth = auth,
        _prefs = prefs;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  SharedPreferences? _prefs;

  FirebaseFirestore get _fs => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _au => _auth ?? FirebaseAuth.instance;

  Future<SharedPreferences> _preferences() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const String stagingCollection = 'staging_meals';

  /// Upper bounds for the network stages. Firestore's `add()` only completes
  /// on a server ack, so on a flaky connection the flow used to hang and leave
  /// the propose button spinning forever with no message at all; the failure
  /// now surfaces through the normal `blockedNoConnection` / `failed` paths.
  static const Duration signInTimeout = Duration(seconds: 15);
  static const Duration writeTimeout = Duration(seconds: 20);
  static const Duration imageUploadTimeout = Duration(seconds: 25);

  /// One try/catch per stage, because the three of them fail for completely
  /// different reasons and the user needs to be told which one to go fix.
  Future<ProposalOutcome> proposeMeal(Meal meal) async {
    final ProposalGuard guard;
    final ProposalQuota quota;
    try {
      final prefs = await _preferences();
      guard = ProposalGuard(prefs);
      quota = ProposalQuota(prefs);
      if (!quota.hasAllowance()) {
        return ProposalOutcome.dailyLimitReached();
      }
      if (guard.alreadyProposed(meal)) {
        return ProposalOutcome.alreadyProposed();
      }
    } catch (error) {
      return ProposalOutcome.failed(error, stage: 'proposal ledger');
    }

    // Firestore rules demand an authenticated caller for staging creates.
    final String uid;
    try {
      var user = _au.currentUser;
      user ??= (await _au.signInAnonymously().timeout(signInTimeout)).user;
      final signedInUid = user?.uid;
      if (signedInUid == null || signedInUid.isEmpty) {
        return ProposalOutcome.failed(
          'anonymous sign-in returned no uid',
          stage: 'anonymous sign-in',
        );
      }
      uid = signedInUid;
    } catch (error) {
      return ProposalOutcome.failed(error, stage: 'anonymous sign-in');
    }

    final photo = await _resolvePhoto(meal);
    if (photo.error != null) {
      return ProposalOutcome.failed(
        photo.error!,
        stage: 'photo',
        reason: photo.uploadAttempted
            ? ProposalFailureReason.photoUploadFailed
            : ProposalFailureReason.photoRejected,
      );
    }
    final imageUrl = photo.url;

    final payload = MealProposalPayload.build(
      meal: meal,
      proposedByUid: uid,
      imageUrl: imageUrl,
    );
    if (payload == null) return ProposalOutcome.invalidName();

    try {
      await _fs.collection(stagingCollection).add(payload).timeout(writeTimeout);
    } catch (error) {
      return ProposalOutcome.failed(error, stage: 'staging_meals write');
    }

    try {
      await guard.markProposed(meal);
      await quota.recordProposal();
    } catch (error) {
      // The proposal is filed; losing the duplicate guard afterwards is not a
      // reason to tell the user it failed.
      debugPrint('Proposal ledger not updated: $error');
    }
    return ProposalOutcome.submitted(imageAttached: imageUrl != null);
  }

  /// Remote photos (meals downloaded from the cloud vault) pass straight
  /// through as `imageUrl`; a local photo is uploaded within the 500 KB
  /// budget. When a photo exists and cannot be shipped the proposal is
  /// aborted with the reason — filing it photoless would quietly drop the
  /// half of the meal the user picked it for.
  Future<StagedPhoto> _resolvePhoto(Meal meal) async {
    final photo = meal.photoPath?.trim() ?? '';
    if (photo.isEmpty) return const StagedPhoto.none();

    if (MealProposalPayload.isRemoteUrl(photo)) {
      return photo.length <= MealProposalPayload.maxImageUrlLength
          ? StagedPhoto.withUrl(photo)
          : const StagedPhoto.rejected('the stored photo link is too long');
    }

    final file = MealProposalPayload.eligibleImageFile(photo);
    if (file == null) {
      return StagedPhoto.rejected(
        'the local photo is missing or over '
        '${MealProposalPayload.maxImageBytes ~/ 1024} KB',
      );
    }

    try {
      final fileBytes = await file.readAsBytes();

      final request = http.MultipartRequest('POST', CloudinaryConfig.uploadEndpoint)
        ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );

      final streamedResponse =
          await request.send().timeout(imageUploadTimeout);
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(imageUploadTimeout);

      if (response.statusCode != 200) {
        return StagedPhoto.uploadFailed(
          'photo host returned HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        return const StagedPhoto.uploadFailed('photo host returned no URL');
      }

      return StagedPhoto.withUrl(
        secureUrl.contains('/upload/')
            ? secureUrl.replaceFirst('/upload/', '/upload/f_auto,q_auto/')
            : secureUrl,
      );
    } catch (error) {
      return StagedPhoto.uploadFailed(error);
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod wiring + shared UI flow
// ---------------------------------------------------------------------------

final mealProposalServiceProvider = Provider<MealProposalService>((ref) {
  return MealProposalService();
});

/// Id of the meal whose proposal is in flight (drives exactly one button
/// spinner across sheet/screen surfaces).
final activeProposalMealIdProvider = StateProvider<int?>((ref) => null);

/// Whether a local row is worth proposing to the cloud vault.
///
/// A meal with no [Meal.cloudId] was invented on the device and is always
/// proposable. A meal that came from the cloud is only worth proposing once the
/// local copy has actually diverged from it — re-sending an identical row would
/// just put the admin back through a review they already finished. The same
/// [mealCloudDiffs] the meal screen's sync mark uses decides this, so the mark
/// and the proposal button can never disagree about what "changed" means.
///
/// [cloud] is null when there is no cloud copy to compare against (purely local,
/// or the cloud row has since been deleted) — which for a local-only meal is the
/// proposable case.
bool isProposableAgainstCloud({
  required Meal meal,
  required CloudMeal? cloud,
  required AppStrings strings,
}) {
  if (meal.cloudId == null) return true;
  if (cloud == null) {
    // Vaulted locally, but the cloud row is gone: this is effectively new again.
    return true;
  }
  return mealCloudDiffs(meal, cloud, strings).isNotEmpty;
}

/// One-stop Cloud Staging Export flow shared by `MealDetailsSheet` and
/// `MealScreen`: connectivity/Wi-Fi gate (same policy as discovery, including
/// the real reachability probe) → service call → localised toast.
///
/// In widget tests `ReachabilityService` reports offline (FLUTTER_TEST), so
/// this flow terminates at the gate toast without ever touching Firebase.
Future<ProposalOutcome> runProposalFlow(
  BuildContext context,
  WidgetRef ref,
  Meal meal,
) async {
  final strings = AppStrings.of(context);

  CloudAccessStatus status;
  try {
    status = await ref.read(cloudAccessStatusFutureProvider.future);
  } catch (_) {
    status = CloudAccessStatus.noConnection;
  }
  if (status != CloudAccessStatus.allowed) {
    final blocked = ProposalOutcome.blocked(status);
    if (context.mounted) showProposalOutcomeToast(context, strings, blocked);
    return blocked;
  }

  // Checked before the quota so a meal with nothing new to contribute does not
  // spend one of the day's proposals.
  final cloudId = meal.cloudId;
  if (cloudId != null) {
    CloudMeal? cloud;
    try {
      cloud = await ref.read(cloudMealByIdProvider(cloudId).future);
    } catch (_) {
      // Unreadable cloud copy: cannot prove the meal is unchanged, so let it
      // through rather than punishing an edit the user really did make.
      cloud = null;
    }
    if (!isProposableAgainstCloud(meal: meal, cloud: cloud, strings: strings)) {
      final unchanged = ProposalOutcome.cloudUnchanged();
      if (context.mounted) showProposalOutcomeToast(context, strings, unchanged);
      return unchanged;
    }
  }

  ref.read(activeProposalMealIdProvider.notifier).state = meal.id;
  final ProposalOutcome outcome;
  try {
    outcome = await ref.read(mealProposalServiceProvider).proposeMeal(meal);
  } finally {
    ref.read(activeProposalMealIdProvider.notifier).state = null;
  }
  if (context.mounted) {
    showProposalOutcomeToast(context, strings, outcome);
  }
  return outcome;
}

/// Maps a [ProposalOutcome] to the localised toast. Kept next to the flow so
/// every surface reports identically.
void showProposalOutcomeToast(
  BuildContext context,
  AppStrings strings,
  ProposalOutcome outcome,
) {
  switch (outcome.code) {
    case ProposalOutcomeCode.submitted:
      AppToast.showSuccess(context, strings.proposalSuccess);
      break;
    case ProposalOutcomeCode.alreadyProposed:
      AppToast.showInfo(context, strings.proposalAlready);
      break;
    case ProposalOutcomeCode.blockedNoConnection:
      AppToast.showError(context, strings.proposalOffline);
      break;
    case ProposalOutcomeCode.blockedRequiresWifi:
      AppToast.showInfo(context, strings.proposalWifiOnly);
      break;
    case ProposalOutcomeCode.invalidName:
      AppToast.showError(context, strings.proposalInvalidName);
      break;
    case ProposalOutcomeCode.dailyLimitReached:
      AppToast.showInfo(context, strings.proposalDailyLimit(ProposalQuota.dailyLimit));
      break;
    case ProposalOutcomeCode.cloudUnchanged:
      AppToast.showInfo(context, strings.proposalUnchangedFromCloud);
      break;
    case ProposalOutcomeCode.failed:
      AppToast.showError(
        context,
        strings.proposalFailedReason(_proposalFailureDetail(strings, outcome)),
      );
      break;
  }
}

/// The suffix that tells the user *which* stage rejected them. Unrecognised
/// errors surface their raw provider text, because a guess would be worse than
/// an ugly string; known ones stay clean outside debug builds.
String _proposalFailureDetail(AppStrings strings, ProposalOutcome outcome) {
  final label = switch (outcome.reason) {
    ProposalFailureReason.firebaseNotReady =>
      strings.proposalFailFirebaseNotReady,
    ProposalFailureReason.anonymousProviderDisabled =>
      strings.proposalFailAnonymousDisabled,
    ProposalFailureReason.anonymousSignInRejected =>
      strings.proposalFailAnonymousRejected,
    ProposalFailureReason.writePermissionDenied =>
      strings.proposalFailPermissionDenied,
    ProposalFailureReason.writeUnreachable => strings.proposalFailUnreachable,
    ProposalFailureReason.photoRejected => strings.proposalFailPhotoRejected,
    ProposalFailureReason.photoUploadFailed =>
      strings.proposalFailPhotoUploadFailed,
    ProposalFailureReason.unknown =>
      ProposalFailureDiagnoser.describe(outcome.cause ?? ''),
  };
  if (outcome.reason == ProposalFailureReason.unknown || !kDebugMode) {
    return label;
  }
  return '$label · ${ProposalFailureDiagnoser.describe(outcome.cause ?? '')}';
}
