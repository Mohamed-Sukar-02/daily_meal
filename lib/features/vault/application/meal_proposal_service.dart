import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/providers/network_provider.dart';
import '../../../core/widgets/app_toast.dart';

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
//   • Duplicate guard: `staging_meals` is admin-read-only, so the client
//     cannot query its own proposals. A SharedPreferences ledger
//     (mealId → updatedAt-ms at submit time) blocks accidental re-sends and
//     automatically re-opens the door once the meal is edited.
//   • Like `AdminAuthService`, this layer carries no display text: it returns
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

  /// Auth / Firestore / Storage failure. [ProposalOutcome.cause] has details.
  failed,
}

class ProposalOutcome {
  final ProposalOutcomeCode code;

  /// Raw error for [ProposalOutcomeCode.failed] (logged, never shown as-is).
  final Object? cause;

  /// True when a photo made it into the payload (uploaded or remote URL).
  final bool imageAttached;

  const ProposalOutcome._(this.code, {this.cause, this.imageAttached = false});

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

  factory ProposalOutcome.failed(Object cause) =>
      ProposalOutcome._(ProposalOutcomeCode.failed, cause: cause);

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

/// Executes the export: guard → anonymous auth → optional photo upload →
/// Firestore create. All dependencies are injectable for tests; defaults are
/// the live Firebase singletons (the app initialises Firebase in `main()`).
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

  Future<ProposalOutcome> proposeMeal(Meal meal) async {
    try {
      final guard = ProposalGuard(await _preferences());
      if (guard.alreadyProposed(meal)) {
        return ProposalOutcome.alreadyProposed();
      }

      // Firestore rules demand an authenticated caller for staging creates.
      var user = _au.currentUser;
      user ??= (await _au.signInAnonymously()).user;
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) {
        return ProposalOutcome.failed('anonymous sign-in returned no uid');
      }

      final imageUrl = await _resolveImageUrl(meal, uid);

      final payload = MealProposalPayload.build(
        meal: meal,
        proposedByUid: uid,
        imageUrl: imageUrl,
      );
      if (payload == null) return ProposalOutcome.invalidName();

      await _fs.collection(stagingCollection).add(payload);
      await guard.markProposed(meal);
      return ProposalOutcome.submitted(imageAttached: imageUrl != null);
    } catch (error) {
      debugPrint('MealProposalService.proposeMeal failed: $error');
      return ProposalOutcome.failed(error);
    }
  }

  /// Remote photos (meals downloaded from the cloud vault) pass straight
  /// through as `imageUrl`; local files upload only within the 500 KB budget.
  /// Any photo problem degrades to "no image" — never blocks the proposal.
  Future<String?> _resolveImageUrl(Meal meal, String uid) async {
    final photo = meal.photoPath?.trim() ?? '';
    if (photo.isEmpty) return null;

    if (MealProposalPayload.isRemoteUrl(photo)) {
      return photo.length <= MealProposalPayload.maxImageUrlLength
          ? photo
          : null;
    }

    final file = MealProposalPayload.eligibleImageFile(photo);
    if (file == null) return null;

    // Firebase Storage is deliberately avoided here due to billing plan limitations.
    // Instead, we use Cloudinary Unsigned Uploads directly via the REST API.
    try {
      final fileBytes = await file.readAsBytes();
      const cloudName = 'bzd1vjrs';
      const uploadPreset = 'daily meal';

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        String secureUrl = data['secure_url'] as String;

        if (secureUrl.contains('/upload/')) {
          secureUrl = secureUrl.replaceFirst('/upload/', '/upload/f_auto,q_auto/');
        }
        return secureUrl;
      } else {
        debugPrint('Cloudinary error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (error) {
      debugPrint('Staging image upload skipped: $error');
      return null;
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
    case ProposalOutcomeCode.failed:
      AppToast.showError(context, strings.proposalFailed);
      break;
  }
}
