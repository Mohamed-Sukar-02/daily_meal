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
//     (cloudName: bzd1vjrs, preset: daily meal). A photo that cannot ship
//     aborts the proposal with the reason it cannot ship — a picture the user
//     picked is never dropped silently behind a "success" toast. Readable-but-
//     too-big and missing are reported as two different problems, and so are a
//     host that refused the upload and one that never answered.
//     No new compression dependency is introduced (per the implementation plan).
//   • Auth: staging creates require `request.auth != null`; the app has no
//     user accounts, so we sign in anonymously via firebase_auth (already a
//     project dependency) exactly when a proposal is made.
//   • Connectivity: [resolveProposalCloudAccess] is the single Wi-Fi/offline
//     gate, applied by the UI flow *and* by [proposeMeal] itself, so the two
//     buttons and any direct service call cannot diverge.
//   • Failure reporting: every stage (gate, ledger, sign-in, photo, write) is
//     caught separately and classified into a [ProposalFailureReason] — from
//     the provider `code` first, the message only as a fallback — because a
//     disabled anonymous provider, rejected security rules, an expired
//     deadline and a dead network all look identical to the user otherwise.
//   • Duplicate guard: `staging_meals` is admin-read-only, so the client
//     cannot query its own proposals. A SharedPreferences ledger
//     (mealId → updatedAt-ms at submit time) blocks accidental re-sends and
//     automatically re-opens the door once the meal is edited.
//   • Public-vault pre-flight: `vault_meals` IS world-readable
//     (`firestore.rules`), so before anything is uploaded the flow probes it
//     for the exact `name` the payload would write (and the meal's
//     `shortName`). A hit answers "already published" and costs no photo
//     upload, no staging write and no quota slot. Matching is on the stored
//     strings only — Firestore equality is case- and diacritic-sensitive, so
//     an approximate-name duplicate is deliberately left for the admin to
//     reject at triage rather than guessed at here. A probe that throws or
//     never answers is skipped: a broken duplicate check must never block a
//     legitimate proposal.
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

  /// The public vault already serves this meal under one of its stored names.
  /// Raised by the pre-flight read, before the photo upload and before the
  /// daily allowance is touched, so telling the user costs nothing on either
  /// side — and the next meal can be proposed straight after.
  alreadyInPublicVault,

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
/// reason maps to a short localised line in [AppStrings] (the `proposalFail*`
/// getters, named after these values); the raw provider error is appended only
/// when nothing matched ([unknown]).
///
/// Every value here is reachable: the classifier in
/// [ProposalFailureDiagnoser.classify] produces the provider-shaped ones from
/// the Firebase `code`, the flow itself produces the local-stage ones
/// ([ledgerUnavailable], [signInReturnedNoUser], the photo reasons), and
/// [proposalFailureLabel] maps all of them to a string. The unit test that
/// walks `ProposalFailureReason.values` is what keeps that promise.
enum ProposalFailureReason {
  /// `Firebase.initializeApp` never completed, or the client API key is wrong,
  /// so no Firebase singleton exists to call.
  firebaseNotReady,

  /// Anonymous sign-in is switched off in Firebase Console → Authentication →
  /// Sign-in method. Staging writes demand `request.auth != null`.
  anonymousProviderDisabled,

  /// Anonymous sign-in exists but rejected the caller for another reason.
  anonymousSignInRejected,

  /// The credentials that were valid a moment ago stopped being accepted
  /// (`unauthenticated`): the anonymous session was dropped, so the write
  /// never counted as authorised. Nothing about the meal is wrong.
  signInStateLost,

  /// Anonymous sign-in "succeeded" but handed back no uid, so there is no
  /// `proposedBy` value to write. A broken project configuration, not a
  /// network problem and not a rejection.
  signInReturnedNoUser,

  /// Firestore refused the `staging_meals` create — deployed security rules do
  /// not accept this payload, or the caller is not the `proposedBy` uid.
  writePermissionDenied,

  /// The cloud could not be reached, or did not answer before its deadline
  /// expired. Deliberately one reason for both shapes: `unavailable`, DNS
  /// failures, socket errors and `deadline-exceeded` all mean "the request
  /// never got a reply", and the user's fix is the same — check the network.
  writeUnreachable,

  /// The request was cancelled or aborted part-way (`cancelled`, `aborted`) —
  /// typically the app being backgrounded, not a broken connection and not a
  /// rejected payload.
  requestCancelled,

  /// Firestore answered but the write target does not exist (`not-found`):
  /// the database or the `staging_meals` collection is missing from the
  /// project this build points at.
  cloudTargetMissing,

  /// The cloud spent its allowance on this caller (`resource-exhausted`):
  /// rate limit or quota reached, so retrying immediately will not help.
  cloudQuotaExhausted,

  /// The on-device proposal record (SharedPreferences ledger / daily counter)
  /// could not be read or written, so the flow cannot tell whether this meal
  /// was already sent or whether today's allowance is gone.
  ledgerUnavailable,

  /// There is no readable photo to ship: the file is gone, empty, or its path
  /// cannot be opened. The proposal is aborted rather than filed photoless
  /// behind the user's back.
  photoUnreadable,

  /// The local photo is a real file but bigger than the staging cap, so the
  /// only honest advice is to pick another picture or retake it.
  photoTooLarge,

  /// The meal points at a remote photo whose stored link is too long to put in
  /// the document — re-picking the photo is what fixes it, not reconnecting.
  photoLinkInvalid,

  /// The photo host was contacted and never answered within
  /// [MealProposalService.imageUploadTimeout].
  photoUploadTimeout,

  /// The photo host answered with a refusal (non-200): the upload preset or
  /// its server-side configuration rejected the file.
  photoUploadRefused,

  /// The upload stage failed in some other way (connection dropped mid-body,
  /// an unreadable response body, no URL in it).
  photoUploadFailed,

  /// Anything else — the UI shows the raw error instead of a guess.
  unknown,
}

/// Maps a raw provider error onto a [ProposalFailureReason]. Pure: no Firebase
/// singletons, so tests can feed it hand-built exceptions.
class ProposalFailureDiagnoser {
  const ProposalFailureDiagnoser._();

  /// Firebase/Firestore status codes that mean "no reply came back".
  /// `deadline-exceeded` belongs here and NOT in a message sniff: Firestore
  /// reports an expired deadline with that code and a body that never contains
  /// the word "timeout", so the old substring test let it fall through to
  /// [ProposalFailureReason.unknown] — a timeout described as "something else".
  static const Set<String> _connectivityCodes = <String>{
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
    'connect-error',
    'timeout',
  };

  /// The session existed and stopped being accepted. Distinct from both
  /// `permission-denied` (authenticated, rules said no) and a disabled
  /// provider (nothing to authenticate against).
  static const Set<String> _signInLostCodes = <String>{
    'unauthenticated',
    'auth-expired',
    'token-expired',
  };

  /// "You may do this, but not this often / not more of this."
  static const Set<String> _quotaCodes = <String>{
    'resource-exhausted',
    'quota-exceeded',
    'rate-limit-exceeded',
  };

  /// The caller (or the OS, when the app was backgrounded) stopped the request.
  static const Set<String> _cancelledCodes = <String>{
    'cancelled',
    'aborted',
  };

  static ProposalFailureReason classify(Object error) {
    final code = errorCode(error)?.trim().toLowerCase();
    final haystack = '$code ${error.toString()}'.toLowerCase();
    bool hasCode(Set<String> codes) => code != null && codes.contains(code);

    // Auth never initialised: `FirebaseAuth.instance` / `FirebaseFirestore
    // .instance` throw a plain StateError before any network call happens.
    if (code == 'invalid-api-key' ||
        code == 'api-key-not-valid' ||
        haystack.contains('no firebase app') ||
        haystack.contains('firebase apps were not initialised') ||
        haystack.contains('invalid-api-key') ||
        haystack.contains('api-key-not-valid')) {
      return ProposalFailureReason.firebaseNotReady;
    }

    // `operation-not-allowed` / `unsupported-operation` / `configuration-
    // not-found` are the shapes Firebase Auth uses for a disabled provider.
    if (hasCode(const {
          'operation-not-allowed',
          'unsupported-operation',
          'configuration-not-found',
        }) ||
        haystack.contains('operation-not-allowed') ||
        haystack.contains('unsupported-operation') ||
        haystack.contains('configuration-not-found') ||
        haystack.contains('provider is disabled')) {
      return ProposalFailureReason.anonymousProviderDisabled;
    }

    // The connectivity family is checked BEFORE the blanket auth branch:
    // `FirebaseAuthException(code: network-request-failed)` is thrown by the
    // sign-in stage, but what it says is "the host was unreachable" — labelling
    // that "sign-in was rejected" sent users to the Firebase console to enable
    // a provider that was already enabled.
    if (hasCode(_connectivityCodes) ||
        haystack.contains('failed host lookup') ||
        haystack.contains('socketexception') ||
        haystack.contains('network-request-failed') ||
        haystack.contains('timeout')) {
      return ProposalFailureReason.writeUnreachable;
    }

    if (hasCode(_signInLostCodes) || haystack.contains('unauthenticated')) {
      return ProposalFailureReason.signInStateLost;
    }

    // FirebaseAuthException codes are bare (`Too-Many-Requests`, `user-disabled`)
    // and are not prefixed with `auth/`, so the class is the reliable signal
    // that the sign-in stage — not the write — is what answered.
    if (error is FirebaseAuthException) {
      return ProposalFailureReason.anonymousSignInRejected;
    }

    if (hasCode(_quotaCodes) ||
        haystack.contains('resource-exhausted') ||
        haystack.contains('quota-exceeded')) {
      return ProposalFailureReason.cloudQuotaExhausted;
    }

    if (code == 'permission-denied' ||
        haystack.contains('permission-denied') ||
        haystack.contains('permission denied')) {
      return ProposalFailureReason.writePermissionDenied;
    }

    if (hasCode(_cancelledCodes) || haystack.contains('cancelled')) {
      return ProposalFailureReason.requestCancelled;
    }

    if (code == 'not-found') {
      return ProposalFailureReason.cloudTargetMissing;
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

  /// The reason a local photo did not qualify, or `null` when it did.
  ///
  /// One mapping, shared by the gate and the flow, so "the file is not there"
  /// and "the file is too big" can never be folded back into a single label —
  /// they are the two causes users most often mix up, and only one of them is
  /// fixed by retaking the picture.
  static ProposalFailureReason? localPhotoReason(LocalPhotoIssue issue) =>
      switch (issue) {
        LocalPhotoIssue.none => null,
        LocalPhotoIssue.missing => ProposalFailureReason.photoUnreadable,
        LocalPhotoIssue.empty => ProposalFailureReason.photoUnreadable,
        LocalPhotoIssue.tooLarge => ProposalFailureReason.photoTooLarge,
      };

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

  /// The vault already publishes this meal: nothing was uploaded and nothing
  /// was recorded, so no quota and no ledger entry is spent on the answer.
  factory ProposalOutcome.alreadyInPublicVault() =>
      const ProposalOutcome._(ProposalOutcomeCode.alreadyInPublicVault);

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

/// Why a locally-stored photo could not be shipped, decided from facts the
/// caller reads off the filesystem. Splitting "not there" from "too big" is the
/// point: they need different advice, and merging them into one label is what
/// made users toggle Wi-Fi over a picture they simply had to retake.
enum LocalPhotoIssue {
  /// Nothing wrong — the file is there and fits the staging budget.
  none,

  /// No file at that path (deleted, moved, or never saved).
  missing,

  /// The file exists but has no bytes to upload.
  empty,

  /// The file exists but exceeds [MealProposalPayload.maxImageBytes].
  tooLarge,
}

/// Pure local→cloud vocabulary bridges. The cloud schema (see `CloudMeal` and
/// the Firestore rules) is narrower than the local Drift enums, so every value
/// must map into the allowed set:
///   protein: chicken | beef | fish | meatless | other
///   carbs:   rice | pasta | bread | none
///   category: tabeekh | casserole | dry_sandwich | popular | seafood |
///             soup_stew | vegetarian
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

  /// Reverse of `DiscoveryNotifier._mapCategory`: every local category now has
  /// its own cloud token, so uploads land back on the enum they started from.
  /// `popular` stays cloud-only — admins use it as a catch-all and it downloads
  /// as `egyptianTraditional`; the client never writes it.
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
        return 'soup_stew';
      case MealCategory.vegetarian:
        return 'vegetarian';
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

  /// Client-only size gate for locally-picked photos: `inspectLocalPhoto`
  /// reports `LocalPhotoIssue.tooLarge` for a file above this size (and
  /// `eligibleImageFile` returns null for it), so such a photo is never handed
  /// to Cloudinary. Nothing server-side enforces a byte limit —
  /// `firestore.rules::isValidStagingMeal` only bounds the stored `imageUrl`
  /// *string* (2048 chars), and the Firebase Storage path that used to host
  /// staging photos is retired (`storage.rules::staging_meal_images` is
  /// `allow write: if false`). This number is therefore a product policy, not a
  /// rules mirror; the picker settings that keep ordinary captures under it
  /// (`maxWidth: 1080`, `imageQuality: 85`) are part of the same decision.
  static const int maxImageBytes = 500 * 1024;

  /// Clamps into the rule-enforced window; kept explicit (rather than
  /// `num.clamp`) so the static type stays `int` for Firestore.
  static int clampPrepTime(int minutes) {
    if (minutes < minPrepTimeMinutes) return minPrepTimeMinutes;
    if (minutes > maxPrepTimeMinutes) return maxPrepTimeMinutes;
    return minutes;
  }

  /// The `name` exactly as [build] writes it: trimmed, then capped at
  /// [maxNameLength]; `null` when the trimmed value is below [minNameLength]
  /// (the same fast-fail [build] applies). The public-vault pre-flight probes
  /// this value rather than `meal.name`, so the query is looking for the string
  /// the cloud actually stores.
  static String? payloadName(String rawName) {
    final name = rawName.trim();
    if (name.length < minNameLength) return null;
    return name.length > maxNameLength ? name.substring(0, maxNameLength) : name;
  }

  /// Candidate names for the public-vault pre-flight: the payload name, then
  /// the meal's own [Meal.shortName] when it is a different stored string
  /// (`shortName` is never uploaded, so it can only ever match a vault row
  /// admins published under that wording). Empty when the meal has no name the
  /// rules would accept, which means "nothing to probe".
  ///
  /// Firestore string equality is case- and diacritic-sensitive, so these exact
  /// forms are all the check attempts: an approximate-name duplicate is
  /// deliberately left for the admin to reject at triage.
  static List<String> vaultProbeNames(Meal meal) {
    final candidates = <String>[];
    final name = payloadName(meal.name);
    if (name != null) candidates.add(name);
    final shortName = meal.shortName;
    if (shortName != null) {
      final short = payloadName(shortName);
      if (short != null && !candidates.contains(short)) candidates.add(short);
    }
    return candidates;
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
    final name = payloadName(meal.name);
    if (name == null) return null;

    final notes = meal.notes?.trim() ?? '';
    final createdAt = (now ?? DateTime.now()).toUtc().toIso8601String();
    final url = imageUrl?.trim() ?? '';

    return <String, dynamic>{
      'name': name,
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

  /// The same gate as [eligibleImageFile], but it reports *why* the photo did
  /// not qualify so the user gets told the truth. Pure (existence and length
  /// are passed in) so it is unit-testable without a filesystem.
  static LocalPhotoIssue localPhotoIssue({
    required bool exists,
    required int byteLength,
    int? maxBytes,
  }) {
    if (!exists) return LocalPhotoIssue.missing;
    if (byteLength <= 0) return LocalPhotoIssue.empty;
    if (byteLength > (maxBytes ?? maxImageBytes)) return LocalPhotoIssue.tooLarge;
    return LocalPhotoIssue.none;
  }

  /// Reads [localPhotoIssue] off the disk for a non-remote `photoPath`.
  /// A path that cannot be stat'ed at all reports as [LocalPhotoIssue.missing]
  /// — from the user's side a photo they cannot open is the same as one that
  /// is not there, and neither is ever reported as "too large".
  static LocalPhotoIssue inspectLocalPhoto(String photoPath, {int? maxBytes}) {
    final path = photoPath.trim();
    if (path.isEmpty) return LocalPhotoIssue.missing;
    try {
      final file = File(path);
      final exists = file.existsSync();
      if (!exists) return LocalPhotoIssue.missing;
      return localPhotoIssue(
        exists: true,
        byteLength: file.lengthSync(),
        maxBytes: maxBytes,
      );
    } catch (_) {
      return LocalPhotoIssue.missing;
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
/// [reason] says which of the photo failures it was, so "the file is gone" and
/// "the host refused it" never share a label.
class StagedPhoto {
  final String? url;
  final Object? error;

  /// Set whenever [error] is, and only then.
  final ProposalFailureReason? reason;

  const StagedPhoto._(this.url, this.error, this.reason);

  const StagedPhoto.none() : this._(null, null, null);
  const StagedPhoto.withUrl(String url) : this._(url, null, null);

  /// The photo never left the device (missing, empty, oversized, bad link).
  const StagedPhoto.rejected(Object why, ProposalFailureReason reason)
      : this._(null, why, reason);

  /// The photo host was contacted and the upload did not land.
  const StagedPhoto.uploadFailed(Object why, ProposalFailureReason reason)
      : this._(null, why, reason);

  /// Whether a photo was available to ship but could not be.
  bool get failed => error != null;
}

/// Upper bound on the connectivity precondition itself. The reachability probe
/// has its own 3-second timeout; this is the belt that keeps a proposal from
/// waiting on a gate that never answers.
const Duration proposalAccessTimeout = Duration(seconds: 8);

/// The precondition every proposal passes, in one place.
///
/// [runProposalFlow] reads it so it can toast before the spinner starts, and
/// [MealProposalService.proposeMeal] reads it again where the payload is built,
/// so the meal details sheet button, the meal screen button and any direct
/// service call are gated by the same rule instead of two copies of it.
///
/// A gate that throws or never answers means [CloudAccessStatus.noConnection]:
/// the proposal stops before any Firebase call rather than hanging on a stage
/// nothing is waiting on.
Future<CloudAccessStatus> resolveProposalCloudAccess(
  Future<CloudAccessStatus> Function() gate,
) async {
  try {
    return await gate().timeout(proposalAccessTimeout);
  } catch (_) {
    return CloudAccessStatus.noConnection;
  }
}

/// Stand-in gate for instances built without one (unit tests, direct
/// construction): there is no connectivity plumbing to ask, so it reports
/// "allowed" instead of inventing a network failure it cannot observe. The app
/// wires the real, provider-backed gate through `mealProposalServiceProvider`.
Future<CloudAccessStatus> _alwaysAllowedGate() async =>
    CloudAccessStatus.allowed;

/// Executes the export: connectivity gate → daily quota → duplicate guard →
/// public-vault pre-flight → anonymous auth → optional photo upload →
/// Firestore create. All dependencies are injectable for tests; defaults are
/// the live Firebase singletons (the app initialises Firebase in `main()`).
class MealProposalService {
  MealProposalService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SharedPreferences? prefs,
    Future<CloudAccessStatus> Function()? accessStatus,
    Future<bool> Function(List<String> vaultNames)? publicVaultDuplicateProbe,
  })  : _firestore = firestore,
        _auth = auth,
        _prefs = prefs,
        _accessStatus = accessStatus ?? _alwaysAllowedGate,
        // `vault_meals` is world-readable, so a `name` query needs no signed-in
        // user and no collection scan. Tests hand in a stand-in because
        // dev_dependencies carry no fake Firestore (`pubspec.yaml` is off-limits
        // to this task); `null` keeps the live query in [_queryPublicVault].
        _vaultDuplicateProbe = publicVaultDuplicateProbe;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  SharedPreferences? _prefs;

  /// How this instance answers "is the cloud reachable right now?" — see
  /// [resolveProposalCloudAccess].
  final Future<CloudAccessStatus> Function() _accessStatus;

  /// Injected answer for "does the public vault already serve one of these
  /// names?", or `null` to ask Firestore itself.
  final Future<bool> Function(List<String> vaultNames)? _vaultDuplicateProbe;

  FirebaseFirestore get _fs => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _au => _auth ?? FirebaseAuth.instance;

  Future<SharedPreferences> _preferences() async =>
      _prefs ??= await SharedPreferences.getInstance().timeout(prefsTimeout);

  static const String stagingCollection = 'staging_meals';

  /// The published catalogue, probed before anything is uploaded. Rules:
  /// `allow read: if true`, so this read works with (or without) the anonymous
  /// session the flow creates further down.
  static const String publicVaultCollection = 'vault_meals';

  /// Upper bounds for the blocking stages. Firestore's `add()` only completes
  /// on a server ack, so on a flaky connection the flow used to hang and leave
  /// the propose button spinning forever with no message at all; the failure
  /// now surfaces through the normal `blockedNoConnection` / `failed` paths.
  /// The plugin-backed stages (`SharedPreferences`, the photo host's response
  /// body) are bounded too, so no await in this flow can sit there indefinitely.
  static const Duration prefsTimeout = Duration(seconds: 5);
  static const Duration signInTimeout = Duration(seconds: 15);
  static const Duration writeTimeout = Duration(seconds: 20);
  static const Duration imageUploadTimeout = Duration(seconds: 25);

  /// The pre-flight's own deadline, in the same style as the stage bounds
  /// above: it caps the whole duplicate probe (one `limit(1)` query per
  /// candidate name), so a vault read that never answers cannot hold the
  /// propose button open. Exceeding it lets the proposal continue.
  static const Duration publicVaultReadTimeout = Duration(seconds: 8);

  /// One try/catch (and one bound) per stage, because the stages fail for
  /// completely different reasons and the user needs to be told which one to
  /// go fix — the gate, the on-device ledger, the vault pre-flight, sign-in,
  /// the photo and the write are different problems with different answers.
  /// The pre-flight is the one stage whose failure is *not* reported: it can
  /// only say "already published", so a broken read must fall through to the
  /// normal upload rather than refuse a legitimate proposal.
  Future<ProposalOutcome> proposeMeal(Meal meal) async {
    // Checked here, not only in the UI flow: the payload builder must never run
    // on a device that cannot deliver it, whichever button called it.
    final access = await resolveProposalCloudAccess(_accessStatus);
    if (access != CloudAccessStatus.allowed) {
      return ProposalOutcome.blocked(access);
    }

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
      // Reading (or timing out on) the on-device proposal record. Not a network
      // failure and not the cloud's doing — the plugin backing this never came
      // back, which is its own honest answer.
      return ProposalOutcome.failed(
        error,
        stage: 'proposal ledger',
        reason: ProposalFailureReason.ledgerUnavailable,
      );
    }

    // Pre-flight against the public vault, in the same precondition block as
    // the local ledger and for the same reason: it must answer before the photo
    // is uploaded, before the staging write, and before the daily allowance is
    // spent. A meal the vault already serves therefore costs zero network
    // writes and leaves the quota and the ledger untouched, so the user can
    // propose a different meal straight after being told.
    if (await _alreadyInPublicVault(
        MealProposalPayload.vaultProbeNames(meal))) {
      return ProposalOutcome.alreadyInPublicVault();
    }

    // Firestore rules demand an authenticated caller for staging creates.
    final String uid;
    try {
      var user = _au.currentUser;
      user ??= (await _au.signInAnonymously().timeout(signInTimeout)).user;
      final signedInUid = user?.uid;
      if (signedInUid == null || signedInUid.isEmpty) {
        // Sign-in resolved without a user. Nothing was rejected by the provider
        // and no write was attempted: this project's auth is answering with an
        // empty identity, which is a configuration problem, so it gets its own
        // reason instead of a bare `unknown` carrying our own sentence.
        return ProposalOutcome.failed(
          'anonymous sign-in returned no uid',
          stage: 'anonymous sign-in',
          reason: ProposalFailureReason.signInReturnedNoUser,
        );
      }
      uid = signedInUid;
    } catch (error) {
      return ProposalOutcome.failed(error, stage: 'anonymous sign-in');
    }

    final photo = await _resolvePhoto(meal);
    if (photo.failed) {
      return ProposalOutcome.failed(
        photo.error!,
        stage: 'photo',
        reason: photo.reason ?? ProposalFailureReason.photoUploadFailed,
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

  /// Ask the public vault whether it already serves any of [vaultNames].
  ///
  /// Bounded by [publicVaultReadTimeout] like every other stage, and swallowed
  /// on any error (no network, permission, an uninitialised Firebase, an
  /// expired deadline): the check can only save an upload, so when it cannot
  /// answer the proposal simply goes on as if it did not exist. A broken
  /// duplicate check must never block a legitimate proposal.
  Future<bool> _alreadyInPublicVault(List<String> vaultNames) async {
    if (vaultNames.isEmpty) return false;
    final probe = _vaultDuplicateProbe;
    try {
      final served =
          probe != null ? probe(vaultNames) : _queryPublicVault(vaultNames);
      return await served.timeout(publicVaultReadTimeout);
    } catch (error) {
      debugPrint('Public-vault duplicate check skipped: $error');
      return false;
    }
  }

  /// The live probe: one `limit(1)` equality query per candidate name against
  /// `vault_meals` (`allow read: if true`), stopping at the first hit. It never
  /// fetches the collection and never normalises beyond the candidates
  /// [MealProposalPayload] hands it: Firestore matches stored strings exactly,
  /// so folding Arabic variants in here would produce answers the vault cannot
  /// back up.
  Future<bool> _queryPublicVault(List<String> vaultNames) async {
    for (final name in vaultNames) {
      final snapshot = await _fs
          .collection(publicVaultCollection)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return true;
    }
    return false;
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
          : StagedPhoto.rejected(
              'stored photo link is longer than '
              '${MealProposalPayload.maxImageUrlLength} characters',
              ProposalFailureReason.photoLinkInvalid,
            );
    }

    // Why can this photo not ship? Missing/empty and oversized are different
    // problems with different fixes, and lumping them together told users to
    // retake a picture that was fine, or to wait for a connection that was
    // never the issue.
    final issue = MealProposalPayload.inspectLocalPhoto(photo);
    final issueReason = ProposalFailureDiagnoser.localPhotoReason(issue);
    if (issueReason != null) {
      return StagedPhoto.rejected(
        'local photo $issue ('
        '${MealProposalPayload.maxImageBytes ~/ 1024} KB cap)',
        issueReason,
      );
    }

    final file = File(photo);
    final Uint8List fileBytes;
    try {
      fileBytes = await file.readAsBytes();
    } catch (error) {
      // The size gate read it a moment ago; a read that still failed is a
      // storage problem, not an upload problem — the host was never called.
      return StagedPhoto.rejected(error, ProposalFailureReason.photoUnreadable);
    }

    try {
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
        // The host answered and said no — a preset/permission problem, not a
        // dead connection.
        return StagedPhoto.uploadFailed(
          'photo host returned HTTP ${response.statusCode}',
          ProposalFailureReason.photoUploadRefused,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        return StagedPhoto.uploadFailed(
          'photo host returned no URL',
          ProposalFailureReason.photoUploadFailed,
        );
      }

      return StagedPhoto.withUrl(
        secureUrl.contains('/upload/')
            ? secureUrl.replaceFirst('/upload/', '/upload/f_auto,q_auto/')
            : secureUrl,
      );
    } on TimeoutException catch (error) {
      // The body never arrived in time: waiting longer or retrying is the fix,
      // not re-picking the photo.
      return StagedPhoto.uploadFailed(
        error,
        ProposalFailureReason.photoUploadTimeout,
      );
    } catch (error) {
      return StagedPhoto.uploadFailed(
        error,
        ProposalFailureReason.photoUploadFailed,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod wiring + shared UI flow
// ---------------------------------------------------------------------------

final mealProposalServiceProvider = Provider<MealProposalService>((ref) {
  // The service is handed the *same* gate [runProposalFlow] reads — Wi-Fi-only
  // policy plus the real reachability probe — so its internal precondition is
  // one implementation shared by every entry point, not a second copy that can
  // drift from the first.
  return MealProposalService(
    accessStatus: () => ref.read(cloudAccessStatusFutureProvider.future),
  );
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

  // Same helper the service calls — see [resolveProposalCloudAccess]. Running
  // it here first is what lets the button stop with a reason instead of a
  // spinner, and keeps the two gates from being written twice.
  final status = await resolveProposalCloudAccess(
    () => ref.read(cloudAccessStatusFutureProvider.future),
  );
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

/// The localised line behind every [ProposalOutcomeCode], in one exhaustive
/// switch so a new outcome cannot be added without copy in both languages
/// (the unit test that walks `ProposalOutcomeCode.values` is the other half of
/// that promise). Kept free of `BuildContext` so it is testable on its own.
String proposalOutcomeLabel(AppStrings strings, ProposalOutcome outcome) =>
    switch (outcome.code) {
      ProposalOutcomeCode.submitted => strings.proposalSuccess,
      ProposalOutcomeCode.alreadyProposed => strings.proposalAlready,
      ProposalOutcomeCode.alreadyInPublicVault =>
        strings.proposalAlreadyInPublicVault,
      ProposalOutcomeCode.blockedNoConnection => strings.proposalOffline,
      ProposalOutcomeCode.blockedRequiresWifi => strings.proposalWifiOnly,
      ProposalOutcomeCode.invalidName => strings.proposalInvalidName,
      ProposalOutcomeCode.dailyLimitReached =>
        strings.proposalDailyLimit(ProposalQuota.dailyLimit),
      ProposalOutcomeCode.cloudUnchanged => strings.proposalUnchangedFromCloud,
      ProposalOutcomeCode.failed => strings.proposalFailedReason(
          proposalFailureLabel(strings, outcome.reason,
              cause: outcome.cause ?? ''),
        ),
    };

/// Maps a [ProposalOutcome] to the localised toast. Kept next to the flow so
/// every surface reports identically: [proposalOutcomeLabel] says *what* to
/// say, the switch here only says *how loudly*.
void showProposalOutcomeToast(
  BuildContext context,
  AppStrings strings,
  ProposalOutcome outcome,
) {
  final message = proposalOutcomeLabel(strings, outcome);
  switch (outcome.code) {
    case ProposalOutcomeCode.submitted:
      AppToast.showSuccess(context, message);
      break;
    case ProposalOutcomeCode.blockedNoConnection:
    case ProposalOutcomeCode.invalidName:
    case ProposalOutcomeCode.failed:
      AppToast.showError(context, message);
      break;
    case ProposalOutcomeCode.alreadyProposed:
    // Nothing went wrong and nothing was sent: the same neutral tone as the
    // local duplicate, with the spec's 👏 doing the congratulating.
    case ProposalOutcomeCode.alreadyInPublicVault:
    case ProposalOutcomeCode.blockedRequiresWifi:
    case ProposalOutcomeCode.dailyLimitReached:
    case ProposalOutcomeCode.cloudUnchanged:
      AppToast.showInfo(context, message);
      break;
  }
}

/// The suffix that tells the user *which* stage rejected them, in one place so
/// every surface reports identically. Unrecognised errors surface their raw
/// provider text, because a guess would be worse than an ugly string; known
/// ones stay clean outside debug builds.
///
/// An exhaustive switch expression (no `default`), so adding a reason to
/// [ProposalFailureReason] without giving it a string in [AppStrings] is a
/// compile error rather than a silent fall-through to the generic message.
String proposalFailureLabel(
  AppStrings strings,
  ProposalFailureReason reason, {
  Object cause = '',
}) {
  final label = switch (reason) {
    ProposalFailureReason.firebaseNotReady =>
      strings.proposalFailFirebaseNotReady,
    ProposalFailureReason.anonymousProviderDisabled =>
      strings.proposalFailAnonymousDisabled,
    ProposalFailureReason.anonymousSignInRejected =>
      strings.proposalFailAnonymousRejected,
    ProposalFailureReason.signInStateLost => strings.proposalFailSignInLost,
    ProposalFailureReason.signInReturnedNoUser =>
      strings.proposalFailSignInNoUid,
    ProposalFailureReason.writePermissionDenied =>
      strings.proposalFailPermissionDenied,
    ProposalFailureReason.writeUnreachable => strings.proposalFailUnreachable,
    ProposalFailureReason.requestCancelled => strings.proposalFailCancelled,
    ProposalFailureReason.cloudTargetMissing => strings.proposalFailTargetMissing,
    ProposalFailureReason.cloudQuotaExhausted => strings.proposalFailQuotaExhausted,
    ProposalFailureReason.ledgerUnavailable => strings.proposalFailLedger,
    ProposalFailureReason.photoUnreadable => strings.proposalFailPhotoUnreadable,
    ProposalFailureReason.photoTooLarge => strings.proposalFailPhotoTooLarge,
    ProposalFailureReason.photoLinkInvalid => strings.proposalFailPhotoLinkInvalid,
    ProposalFailureReason.photoUploadTimeout =>
      strings.proposalFailPhotoUploadTimeout,
    ProposalFailureReason.photoUploadRefused =>
      strings.proposalFailPhotoUploadRefused,
    ProposalFailureReason.photoUploadFailed =>
      strings.proposalFailPhotoUploadFailed,
    ProposalFailureReason.unknown => ProposalFailureDiagnoser.describe(cause),
  };
  if (reason == ProposalFailureReason.unknown || !kDebugMode) {
    return label;
  }
  return '$label · ${ProposalFailureDiagnoser.describe(cause)}';
}
