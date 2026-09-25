import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/core/providers/network_provider.dart';
import 'package:daily_meal/features/vault/application/meal_proposal_service.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';

// ---------------------------------------------------------------------------
// Cloud Staging Export — payload contract tests.
//
// The staging document must satisfy `firestore.rules::isValidStagingMeal`
// byte-for-byte, or every proposal dies as a permission-denied round-trip.
// `_rulesAccept` below is a deliberate Dart MIRROR of that rule function:
// if either side drifts (new key, wider bound, renamed enum value) a test
// here fails. No Firebase is touched — the builder/guard/vocabulary layers
// are pure by design.
// ---------------------------------------------------------------------------

const Set<String> _requiredKeys = {
  'name', 'proteinType', 'carbsType', 'category',
  'prepTimeMinutes', 'createdAt', 'status',
};

const Set<String> _allowedKeys = {
  'id', 'name', 'imageUrl', 'proteinType', 'carbsType', 'category',
  'prepTimeMinutes', 'isFridaySpecial', 'isBudgetFriendly',
  'isStarterMeal', 'notes', 'createdAt', 'proposedBy', 'status',
};

const Set<String> _cloudProteins = {'chicken', 'beef', 'fish', 'meatless', 'other'};
const Set<String> _cloudCarbs = {'rice', 'pasta', 'bread', 'none'};
const Set<String> _cloudCategories = {
  'tabeekh', 'casserole', 'dry_sandwich', 'popular', 'seafood',
};

/// Mirror of `isValidStagingMeal()` from firestore.rules.
bool _rulesAccept(Map<String, dynamic> data) {
  if (!_requiredKeys.every(data.containsKey)) return false;
  if (!data.keys.every(_allowedKeys.contains)) return false;

  final name = data['name'];
  if (name is! String || name.length < 2 || name.length > 100) return false;
  if (!_cloudProteins.contains(data['proteinType'])) return false;
  if (!_cloudCarbs.contains(data['carbsType'])) return false;
  if (!_cloudCategories.contains(data['category'])) return false;

  final prep = data['prepTimeMinutes'];
  if (prep is! num || prep < 5 || prep > 720) return false;

  if (data.containsKey('isFridaySpecial') && data['isFridaySpecial'] is! bool) {
    return false;
  }
  if (data.containsKey('isBudgetFriendly') && data['isBudgetFriendly'] is! bool) {
    return false;
  }
  if (data.containsKey('isStarterMeal') && data['isStarterMeal'] != false) {
    return false;
  }
  if (data['status'] != 'pending') return false;

  if (data.containsKey('notes')) {
    final notes = data['notes'];
    if (notes != null && (notes is! String || notes.length > 500)) return false;
  }
  if (data.containsKey('imageUrl')) {
    final url = data['imageUrl'];
    if (url != null && (url is! String || url.length > 2048)) return false;
  }

  final createdAt = data['createdAt'];
  if (createdAt is! String || createdAt.length < 10 || createdAt.length > 40) {
    return false;
  }
  if (data.containsKey('proposedBy') && data['proposedBy'] is! String) {
    return false;
  }
  return true;
}

Meal _meal({
  int id = 7,
  String name = 'كشري',
  String? photoPath,
  ProteinType proteinType = ProteinType.legume,
  CarbsType carbsType = CarbsType.rice,
  MealCategory category = MealCategory.egyptianTraditional,
  int prepTime = 45,
  bool isFridaySpecial = false,
  bool isBudgetFriendly = true,
  bool isFavorite = false,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? notes,
  String? shortName = 'كشري',
  String? cloudId,
}) {
  final now = DateTime(2026, 9, 21, 12);
  return Meal(
    id: id,
    name: name,
    nameNormalized: name,
    photoPath: photoPath,
    proteinType: proteinType,
    carbsType: carbsType,
    category: category,
    prepTime: prepTime,
    isFridaySpecial: isFridaySpecial,
    isBudgetFriendly: isBudgetFriendly,
    isFavorite: isFavorite,
    isStarterMeal: false,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    notes: notes,
    shortName: shortName,
    cloudId: cloudId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MealProposalPayload.build — rules parity', () {
    test('a fully-populated meal produces a rules-valid pending document', () {
      final payload = MealProposalPayload.build(
        meal: _meal(notes: 'بصل كتير', photoPath: 'https://x.test/a.jpg'),
        proposedByUid: 'uid-123',
        imageUrl: 'https://cdn.test/koshary.jpg',
        now: DateTime.utc(2026, 9, 21, 9, 30),
      );

      expect(payload, isNotNull);
      expect(_rulesAccept(payload!), isTrue,
          reason: 'payload must satisfy isValidStagingMeal: $payload');
      expect(payload['status'], 'pending');
      expect(payload['proposedBy'], 'uid-123');
      expect(payload['isStarterMeal'], isFalse);
      expect(payload['imageUrl'], 'https://cdn.test/koshary.jpg');
      expect(payload['notes'], 'بصل كتير');
    });

    test('never leaks shortName / id / local-only keys (rules use hasOnly)', () {
      final payload = MealProposalPayload.build(
        meal: _meal(shortName: 'كشري'),
        proposedByUid: 'uid-1',
      )!;
      expect(payload.containsKey('shortName'), isFalse);
      expect(payload.containsKey('id'), isFalse);
      expect(payload.keys.every(_allowedKeys.contains), isTrue);
    });

    test('createdAt is an ISO-8601 string within the 10..40 char window', () {
      final instant = DateTime.utc(2026, 9, 21, 9, 30);
      final payload = MealProposalPayload.build(
        meal: _meal(),
        proposedByUid: 'uid-1',
        now: instant,
      )!;
      final createdAt = payload['createdAt'] as String;
      expect(createdAt.length, inInclusiveRange(10, 40));
      expect(DateTime.tryParse(createdAt), isNotNull);
      // UTC serialisation round-trips to the exact same instant, independent
      // of the machine's local timezone.
      expect(DateTime.parse(createdAt).toUtc(), instant);
      expect(createdAt, '2026-09-21T09:30:00.000Z');
    });

    test('name shorter than 2 chars after trim fails fast (null payload)', () {
      expect(
        MealProposalPayload.build(meal: _meal(name: 'ف'), proposedByUid: 'u'),
        isNull,
      );
      expect(
        MealProposalPayload.build(meal: _meal(name: '  '), proposedByUid: 'u'),
        isNull,
      );
    });

    test('name longer than the cloud cap (100) is truncated, not rejected', () {
      final long = 'أ' * 120; // local column allows up to 120
      final payload = MealProposalPayload.build(
        meal: _meal(name: long),
        proposedByUid: 'u',
      )!;
      expect((payload['name'] as String).length, 100);
      expect(_rulesAccept(payload), isTrue);
    });

    test('prepTime is clamped into the rules window 5..720', () {
      expect(MealProposalPayload.clampPrepTime(1), 5);
      expect(MealProposalPayload.clampPrepTime(5), 5);
      expect(MealProposalPayload.clampPrepTime(45), 45);
      expect(MealProposalPayload.clampPrepTime(720), 720);
      expect(MealProposalPayload.clampPrepTime(5000), 720);

      final payload = MealProposalPayload.build(
        meal: _meal(prepTime: 5000),
        proposedByUid: 'u',
      )!;
      expect(payload['prepTimeMinutes'], 720);
      expect(_rulesAccept(payload), isTrue);
    });

    test('oversized notes are truncated to 500; blank notes are omitted', () {
      final big = MealProposalPayload.build(
        meal: _meal(notes: 'n' * 600),
        proposedByUid: 'u',
      )!;
      expect((big['notes'] as String).length, 500);
      expect(_rulesAccept(big), isTrue);

      final blank = MealProposalPayload.build(
        meal: _meal(notes: '   '),
        proposedByUid: 'u',
      )!;
      expect(blank.containsKey('notes'), isFalse);
    });

    test('imageUrl is omitted when null, blank, or over 2048 chars', () {
      final none = MealProposalPayload.build(
        meal: _meal(),
        proposedByUid: 'u',
        imageUrl: null,
      )!;
      expect(none.containsKey('imageUrl'), isFalse);

      final huge = MealProposalPayload.build(
        meal: _meal(),
        proposedByUid: 'u',
        imageUrl: 'https://x.test/${'p' * 2100}',
      )!;
      expect(huge.containsKey('imageUrl'), isFalse);
      expect(_rulesAccept(huge), isTrue);
    });
  });

  // The public-vault pre-flight can only match the string `vault_meals` really
  // holds, so it probes the payload's own `name` — not `meal.name`. These
  // tests pin that single source of truth: if the builder ever changes its
  // trimming or its cap, the probe follows automatically or this group fails.
  group('MealProposalPayload.vaultProbeNames — the strings the vault stores', () {
    test('the probe name is the payload name, not the raw local name', () {
      final meal = _meal(name: '  محشي بلدي  ', shortName: 'محشي');
      final payload = MealProposalPayload.build(
        meal: meal,
        proposedByUid: 'u',
      )!;

      // The stored payload name is the first thing the probe asks for, so the
      // two can never drift apart.
      expect(MealProposalPayload.vaultProbeNames(meal).first, payload['name']);
      expect(MealProposalPayload.vaultProbeNames(meal), ['محشي بلدي', 'محشي']);
    });

    test('a shortName equal to the name is probed once, not twice', () {
      expect(
        MealProposalPayload.vaultProbeNames(_meal(shortName: 'كشري')),
        ['كشري'],
      );
    });

    test('a missing or blank shortName adds no candidate', () {
      expect(
        MealProposalPayload.vaultProbeNames(_meal(shortName: null)),
        ['كشري'],
      );
      expect(
        MealProposalPayload.vaultProbeNames(_meal(shortName: '   ')),
        ['كشري'],
      );
    });

    test('the 100-char cloud cap applies to the probe too', () {
      final long = 'أ' * 120; // local column allows up to 120
      final candidates = MealProposalPayload.vaultProbeNames(
        _meal(name: long, shortName: long),
      );
      expect(candidates, hasLength(1));
      expect(candidates.single.length, 100);
    });

    test('a name below the rules minimum leaves nothing to probe', () {
      expect(
        MealProposalPayload.vaultProbeNames(_meal(name: 'ف', shortName: null)),
        isEmpty,
      );
      expect(
        MealProposalPayload.vaultProbeNames(_meal(name: '   ', shortName: null)),
        isEmpty,
      );
    });

    test('payloadName mirrors build exactly', () {
      expect(MealProposalPayload.payloadName('  كشري  '), 'كشري');
      expect(MealProposalPayload.payloadName('ف'), isNull);
      expect(MealProposalPayload.payloadName('  '), isNull);
      expect(MealProposalPayload.payloadName('أ' * 120), hasLength(100));
    });
  });

  group('MealCloudVocabulary — every local enum lands in the cloud set', () {
    test('proteinType maps into {chicken, beef, fish, meatless, other}', () {
      for (final protein in ProteinType.values) {
        expect(
          _cloudProteins.contains(MealCloudVocabulary.proteinToCloud(protein)),
          isTrue,
          reason: '$protein escaped the cloud vocabulary',
        );
      }
      // Round-trip identities (download side maps meatless→legume).
      expect(MealCloudVocabulary.proteinToCloud(ProteinType.chicken), 'chicken');
      expect(MealCloudVocabulary.proteinToCloud(ProteinType.beef), 'beef');
      expect(MealCloudVocabulary.proteinToCloud(ProteinType.fish), 'fish');
      expect(MealCloudVocabulary.proteinToCloud(ProteinType.legume), 'meatless');
    });

    test('carbsType maps into {rice, pasta, bread, none}', () {
      for (final carbs in CarbsType.values) {
        expect(
          _cloudCarbs.contains(MealCloudVocabulary.carbsToCloud(carbs)),
          isTrue,
          reason: '$carbs escaped the cloud vocabulary',
        );
      }
      expect(MealCloudVocabulary.carbsToCloud(CarbsType.potato), 'none');
      expect(MealCloudVocabulary.carbsToCloud(CarbsType.grains), 'none');
    });

    test('category maps into {tabeekh, casserole, dry_sandwich, popular, seafood}', () {
      for (final category in MealCategory.values) {
        expect(
          _cloudCategories
              .contains(MealCloudVocabulary.categoryToCloud(category)),
          isTrue,
          reason: '$category escaped the cloud vocabulary',
        );
      }
      // Round-trip identities (download side: tabeekh→egyptianTraditional…).
      expect(
        MealCloudVocabulary.categoryToCloud(MealCategory.ovenBaked),
        'casserole',
      );
      expect(
        MealCloudVocabulary.categoryToCloud(MealCategory.fastFood),
        'dry_sandwich',
      );
    });

    test('a payload for EVERY enum combination is rules-valid', () {
      for (final protein in ProteinType.values) {
        for (final carbs in CarbsType.values) {
          for (final category in MealCategory.values) {
            final payload = MealProposalPayload.build(
              meal: _meal(
                proteinType: protein,
                carbsType: carbs,
                category: category,
              ),
              proposedByUid: 'uid-exhaustive',
            )!;
            expect(_rulesAccept(payload), isTrue,
                reason: 'rejected combo: $protein/$carbs/$category → $payload');
          }
        }
      }
    });
  });

  group('MealProposalPayload.eligibleImageFile — 500KB staging gate', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('proposal_gate_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('rejects null / empty / remote / asset paths without touching disk', () {
      expect(MealProposalPayload.eligibleImageFile(null), isNull);
      expect(MealProposalPayload.eligibleImageFile('   '), isNull);
      expect(
        MealProposalPayload.eligibleImageFile('https://cdn.test/a.jpg'),
        isNull,
      );
      expect(
        MealProposalPayload.eligibleImageFile('http://cdn.test/a.jpg'),
        isNull,
      );
      expect(MealProposalPayload.eligibleImageFile('assets/icon.png'), isNull);
      expect(MealProposalPayload.eligibleImageFile('asset:assets/icon.png'), isNull);
    });

    test('rejects a missing file instead of throwing', () {
      expect(
        MealProposalPayload.eligibleImageFile('${tempDir.path}/ghost.jpg'),
        isNull,
      );
    });

    test('accepts a local photo within the 500KB budget', () {
      final file = File('${tempDir.path}/small.jpg')
        ..writeAsBytesSync(List<int>.filled(100 * 1024, 7));
      expect(MealProposalPayload.eligibleImageFile(file.path)?.path, file.path);
    });

    test('rejects an oversized local photo (native <500KB enforcement)', () {
      final file = File('${tempDir.path}/big.jpg')
        ..writeAsBytesSync(
          List<int>.filled(MealProposalPayload.maxImageBytes + 1, 7),
        );
      expect(MealProposalPayload.eligibleImageFile(file.path), isNull);
      // Exactly at the cap is still eligible.
      final edge = File('${tempDir.path}/edge.jpg')
        ..writeAsBytesSync(
          List<int>.filled(MealProposalPayload.maxImageBytes, 7),
        );
      expect(MealProposalPayload.eligibleImageFile(edge.path), isNotNull);
    });

    test('rejects zero-byte files', () {
      final file = File('${tempDir.path}/empty.jpg')..writeAsBytesSync(<int>[]);
      expect(MealProposalPayload.eligibleImageFile(file.path), isNull);
    });
  });

  // The proposal rule: only something new or locally diverged may be sent.
  group('isProposableAgainstCloud — the divergence rule', () {
    const strings = AppStrings(Locale('ar'));

    CloudMeal cloud({int prepTimeMinutes = 45}) => CloudMeal(
          id: 'c-1',
          name: 'كشري',
          proteinType: 'meatless',
          carbsType: 'rice',
          category: 'tabeekh',
          prepTimeMinutes: prepTimeMinutes,
          isBudgetFriendly: true,
          createdAt: DateTime(2026, 9, 20, 12),
        );

    // Matches `cloud()` field for field, including the absent short name.
    Meal downloaded({int prepTime = 45}) => _meal(
          cloudId: 'c-1',
          prepTime: prepTime,
          shortName: null,
        );

    test('a purely local meal is always proposable', () {
      expect(
        isProposableAgainstCloud(meal: _meal(), cloud: null, strings: strings),
        isTrue,
      );
    });

    test('a cloud meal still identical to its copy is not proposable', () {
      expect(
        isProposableAgainstCloud(
          meal: downloaded(), cloud: cloud(), strings: strings),
        isFalse,
      );
    });

    test('one edited field makes it proposable again', () {
      expect(
        isProposableAgainstCloud(
          meal: downloaded(prepTime: 70),
          cloud: cloud(),
          strings: strings,
        ),
        isTrue,
      );
    });

    test('a cloud-linked meal whose cloud row vanished is proposable again', () {
      expect(
        isProposableAgainstCloud(
          meal: downloaded(), cloud: null, strings: strings),
        isTrue,
      );
    });
  });

  group('ProposalQuota — daily allowance', () {
    final today = DateTime(2026, 9, 24, 12);

    test('spends the allowance and then blocks', () async {
      SharedPreferences.setMockInitialValues({});
      final quota = ProposalQuota(await SharedPreferences.getInstance());

      expect(quota.hasAllowance(today), isTrue);
      for (var i = 0; i < ProposalQuota.dailyLimit; i++) {
        await quota.recordProposal(today);
      }
      expect(quota.usedToday(today), ProposalQuota.dailyLimit);
      expect(quota.hasAllowance(today), isFalse);
      expect(quota.remainingToday(today), 0);
    });

    test('a new calendar day resets the allowance', () async {
      SharedPreferences.setMockInitialValues({
        ProposalQuota.prefsKey: '2026-09-23|${ProposalQuota.dailyLimit}',
      });
      final quota = ProposalQuota(await SharedPreferences.getInstance());

      expect(quota.usedToday(today), 0);
      expect(quota.hasAllowance(today), isTrue);
    });

    test('a corrupt counter reads as unused and never throws', () async {
      SharedPreferences.setMockInitialValues({
        ProposalQuota.prefsKey: 'no-separator-here',
      });
      final quota = ProposalQuota(await SharedPreferences.getInstance());

      expect(quota.usedToday(today), 0);
      expect(quota.hasAllowance(today), isTrue);
    });

    test('remaining never goes negative against a tampered count', () async {
      SharedPreferences.setMockInitialValues({
        ProposalQuota.prefsKey: '2026-09-24|999',
      });
      final quota = ProposalQuota(await SharedPreferences.getInstance());

      expect(quota.hasAllowance(today), isFalse);
      expect(quota.remainingToday(today), 0);
    });
  });

  group('ProposalGuard — duplicate ledger', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a fresh meal has not been proposed', () async {
      final guard = ProposalGuard(await SharedPreferences.getInstance());
      expect(guard.alreadyProposed(_meal(id: 1)), isFalse);
    });

    test('after markProposed the same meal version is blocked', () async {
      final prefs = await SharedPreferences.getInstance();
      final guard = ProposalGuard(prefs);
      final meal = _meal(id: 2, updatedAt: DateTime(2026, 9, 20, 10));

      await guard.markProposed(meal);
      expect(guard.alreadyProposed(meal), isTrue);

      // The ledger survives serialisation (fresh handle, same prefs store).
      final second = ProposalGuard(await SharedPreferences.getInstance());
      expect(second.alreadyProposed(meal), isTrue);
    });

    test('editing the meal (newer updatedAt) re-opens proposals', () async {
      final prefs = await SharedPreferences.getInstance();
      final guard = ProposalGuard(prefs);
      final before = _meal(id: 3, updatedAt: DateTime(2026, 9, 19, 8));
      await guard.markProposed(before);

      final edited = _meal(id: 3, updatedAt: DateTime(2026, 9, 21, 9));
      expect(guard.alreadyProposed(edited), isFalse);
    });

    test('a corrupt ledger is treated as empty, never throws', () async {
      SharedPreferences.setMockInitialValues({
        ProposalGuard.prefsKey: '{not json!!',
      });
      final guard = ProposalGuard(await SharedPreferences.getInstance());
      expect(guard.alreadyProposed(_meal(id: 4)), isFalse);
    });

    test('ledger entries are per-meal', () async {
      final prefs = await SharedPreferences.getInstance();
      final guard = ProposalGuard(prefs);
      await guard.markProposed(_meal(id: 5));
      expect(guard.alreadyProposed(_meal(id: 5)), isTrue);
      expect(guard.alreadyProposed(_meal(id: 6)), isFalse);
      // Ledger is valid JSON on disk.
      expect(
        jsonDecode(prefs.getString(ProposalGuard.prefsKey)!),
        isA<Map<String, dynamic>>(),
      );
    });
  });

  group('ProposalOutcome — stable codes for the UI layer', () {
    test('submitted carries the image flag and isSuccess', () {
      final withImage = ProposalOutcome.submitted(imageAttached: true);
      expect(withImage.isSuccess, isTrue);
      expect(withImage.imageAttached, isTrue);
      expect(ProposalOutcome.submitted().isSuccess, isTrue);
    });

    test('blocked maps Wi-Fi-only vs offline to distinct codes', () {
      expect(
        ProposalOutcome.blocked(CloudAccessStatus.requiresWifi).code,
        ProposalOutcomeCode.blockedRequiresWifi,
      );
      expect(
        ProposalOutcome.blocked(CloudAccessStatus.noConnection).code,
        ProposalOutcomeCode.blockedNoConnection,
      );
    });

    test('failed keeps the raw cause for logs', () {
      final outcome = ProposalOutcome.failed('boom');
      expect(outcome.code, ProposalOutcomeCode.failed);
      expect(outcome.cause, 'boom');
      expect(outcome.isSuccess, isFalse);
    });
  });

  // A proposal that dies on an invisible error is undebuggable: these are the
  // shapes Firebase actually throws for the three real-world causes.
  group('ProposalFailureDiagnoser — names the failing stage', () {
    test('an uninitialised Firebase is not reported as a network problem', () {
      expect(
        ProposalFailureDiagnoser.classify(
          StateError(
            "No Firebase App '[DEFAULT]' has been created - call "
            'Firebase.initializeApp() first',
          ),
        ),
        ProposalFailureReason.firebaseNotReady,
      );
      expect(
        ProposalFailureDiagnoser.classify(
          FirebaseAuthException(
            code: 'invalid-api-key',
            message: 'Your API key is invalid',
          ),
        ),
        ProposalFailureReason.firebaseNotReady,
      );
    });

    test('a disabled anonymous provider is called out by name', () {
      const message = 'The given sign-in provider is disabled for this '
          'Firebase project. Enable it in the Firebase console.';
      for (final code in const [
        'operation-not-allowed',
        'unsupported-operation',
        'configuration-not-found',
      ]) {
        expect(
          ProposalFailureDiagnoser.classify(
            FirebaseAuthException(code: code, message: message),
          ),
          ProposalFailureReason.anonymousProviderDisabled,
          reason: code,
        );
      }
    });

    test('a stage that never answers is reported as unreachable, not unknown',
        () {
      expect(
        ProposalFailureDiagnoser.classify(
          TimeoutException('Future not completed', const Duration(seconds: 20)),
        ),
        ProposalFailureReason.writeUnreachable,
      );
    });

    test('other auth codes stay anonymous-sign-in failures, not provider ones',
        () {
      expect(
        ProposalFailureDiagnoser.classify(
          FirebaseAuthException(code: 'Too-Many-Requests', message: 'quota'),
        ),
        ProposalFailureReason.anonymousSignInRejected,
      );
    });

    test('permission-denied means the deployed rules rejected the write', () {
      expect(
        ProposalFailureDiagnoser.classify(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing or insufficient permissions.',
          ),
        ),
        ProposalFailureReason.writePermissionDenied,
      );
    });

    test('transport failures separate from rule failures', () {
      expect(
        ProposalFailureDiagnoser.classify(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Failed to reach Firestore',
          ),
        ),
        ProposalFailureReason.writeUnreachable,
      );
      expect(
        ProposalFailureDiagnoser.classify(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'deadline-exceeded',
            message:
                'java.net.SocketException: Failed host lookup for firestore.googleapis.com',
          ),
        ),
        ProposalFailureReason.writeUnreachable,
      );
    });

    test('anything unrecognised reports unknown, and describe keeps it readable',
        () {
      expect(
        ProposalFailureDiagnoser.classify('boom'),
        ProposalFailureReason.unknown,
      );
      expect(ProposalFailureDiagnoser.describe('boom'), 'boom');

      final long = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'internal',
        message: 'x' * 400,
      );
      expect(ProposalFailureDiagnoser.describe(long).length, lessThanOrEqualTo(180));
      expect(ProposalFailureDiagnoser.describe(long), contains('internal'));
    });

    test('errorCode reads the provider code structurally', () {
      expect(
        ProposalFailureDiagnoser.errorCode(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'network-request-failed',
      );
      expect(ProposalFailureDiagnoser.errorCode('no code here'), isNull);
    });

    // --- The honesty gaps: every code Firebase can answer with gets a name ---

    test('an expired deadline is the no-connection family, not unknown', () {
      // Shaped like the real Firestore error: the code says deadline, the
      // message never contains the word "timeout", so the old substring test
      // classified a timeout as "something we cannot identify".
      final expired = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'deadline-exceeded',
        message: 'The write was acknowledged by nobody before the deadline',
      );
      expect(
        ProposalFailureDiagnoser.classify(expired),
        ProposalFailureReason.writeUnreachable,
      );
      // A locally-enforced bound belongs in the same family.
      expect(
        ProposalFailureDiagnoser.classify(
          TimeoutException(
            'Future not completed',
            MealProposalService.writeTimeout,
          ),
        ),
        ProposalFailureReason.writeUnreachable,
      );
    });

    test('an unreachable network during sign-in is not called a rejection', () {
      final unreachable = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'A network error (such as timeout, interrupted connection or '
            'unreachable host) has occurred.',
      );
      expect(
        ProposalFailureDiagnoser.classify(unreachable),
        ProposalFailureReason.writeUnreachable,
        reason: 'auth network failure must read as connectivity',
      );
      expect(
        ProposalFailureDiagnoser.classify(unreachable),
        isNot(ProposalFailureReason.anonymousSignInRejected),
      );
      // A real rejection still says so: the reorder did not swallow it.
      expect(
        ProposalFailureDiagnoser.classify(
          FirebaseAuthException(code: 'user-disabled', message: 'account disabled'),
        ),
        ProposalFailureReason.anonymousSignInRejected,
      );
    });

    test('each remaining Firestore code names its own cause', () {
      ProposalFailureReason forCode(String code) =>
          ProposalFailureDiagnoser.classify(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: code,
              message: 'provider said nothing useful',
            ),
          );

      expect(forCode('unavailable'), ProposalFailureReason.writeUnreachable);
      expect(forCode('deadline-exceeded'),
          ProposalFailureReason.writeUnreachable);
      expect(
        forCode('unauthenticated'),
        ProposalFailureReason.signInStateLost,
      );
      expect(
        forCode('resource-exhausted'),
        ProposalFailureReason.cloudQuotaExhausted,
      );
      expect(forCode('cancelled'), ProposalFailureReason.requestCancelled);
      expect(forCode('aborted'), ProposalFailureReason.requestCancelled);
      expect(forCode('not-found'), ProposalFailureReason.cloudTargetMissing);
      expect(
        forCode('permission-denied'),
        ProposalFailureReason.writePermissionDenied,
      );
      // Genuinely unidentifiable codes still fall through to the raw text.
      expect(forCode('internal'), ProposalFailureReason.unknown);
      expect(
        forCode('deadline-exceeded'),
        isNot(ProposalFailureReason.unknown),
      );
    });

    test('the flow-only reasons exist for the UI to render', () {
      // These never come from a provider error: the service attaches them at
      // the stage that produced them, so they must still be enum members.
      for (final reason in const [
        ProposalFailureReason.ledgerUnavailable,
        ProposalFailureReason.signInReturnedNoUser,
        ProposalFailureReason.photoUnreadable,
        ProposalFailureReason.photoTooLarge,
        ProposalFailureReason.photoLinkInvalid,
        ProposalFailureReason.photoUploadTimeout,
        ProposalFailureReason.photoUploadRefused,
      ]) {
        expect(ProposalFailureReason.values, contains(reason));
        expect(
          ProposalOutcome.failed('raw', reason: reason).reason,
          reason,
          reason: '$reason must survive outcome construction',
        );
      }
    });
  });

  // A photo that never ships has two very different causes. Telling them apart
  // is the whole difference between "retake the picture" and "check Wi-Fi".
  group('Local photo gate — missing and oversized split apart', () {
    test('each issue maps to its own reason, and none maps to nothing', () {
      final missing = ProposalFailureDiagnoser.localPhotoReason(
        LocalPhotoIssue.missing,
      );
      final empty =
          ProposalFailureDiagnoser.localPhotoReason(LocalPhotoIssue.empty);
      final tooLarge = ProposalFailureDiagnoser.localPhotoReason(
        LocalPhotoIssue.tooLarge,
      );

      expect(missing, ProposalFailureReason.photoUnreadable);
      expect(empty, ProposalFailureReason.photoUnreadable);
      expect(tooLarge, ProposalFailureReason.photoTooLarge);
      expect(missing, isNot(tooLarge));
      expect(
        ProposalFailureDiagnoser.localPhotoReason(LocalPhotoIssue.none),
        isNull,
      );
    });

    test('localPhotoIssue is pure at the size boundary', () {
      expect(
        MealProposalPayload.localPhotoIssue(exists: false, byteLength: 10),
        LocalPhotoIssue.missing,
      );
      expect(
        MealProposalPayload.localPhotoIssue(exists: true, byteLength: 0),
        LocalPhotoIssue.empty,
      );
      expect(
        MealProposalPayload.localPhotoIssue(
          exists: true,
          byteLength: MealProposalPayload.maxImageBytes,
        ),
        LocalPhotoIssue.none,
      );
      expect(
        MealProposalPayload.localPhotoIssue(
          exists: true,
          byteLength: MealProposalPayload.maxImageBytes + 1,
        ),
        LocalPhotoIssue.tooLarge,
      );
    });

    test('inspectLocalPhoto reads the same difference off the disk', () {
      final dir = Directory.systemTemp.createTempSync('photo_gate_reasons');
      try {
        final small = File('${dir.path}/small.jpg')
          ..writeAsBytesSync(List<int>.filled(2048, 3));
        final empty = File('${dir.path}/empty.jpg')..writeAsBytesSync(<int>[]);
        final big = File('${dir.path}/big.jpg')..writeAsBytesSync(
              List<int>.filled(MealProposalPayload.maxImageBytes + 1, 3),
            );
        final ghost = '${dir.path}/ghost.jpg';

        expect(
          MealProposalPayload.inspectLocalPhoto(ghost),
          LocalPhotoIssue.missing,
        );
        expect(
          MealProposalPayload.inspectLocalPhoto(empty.path),
          LocalPhotoIssue.empty,
        );
        expect(
          MealProposalPayload.inspectLocalPhoto(big.path),
          LocalPhotoIssue.tooLarge,
        );
        expect(
          MealProposalPayload.inspectLocalPhoto(small.path),
          LocalPhotoIssue.none,
        );

        // …and the two causes really do produce different user reasons.
        expect(
          ProposalFailureDiagnoser.localPhotoReason(
            MealProposalPayload.inspectLocalPhoto(ghost),
          ),
          ProposalFailureReason.photoUnreadable,
        );
        expect(
          ProposalFailureDiagnoser.localPhotoReason(
            MealProposalPayload.inspectLocalPhoto(big.path),
          ),
          ProposalFailureReason.photoTooLarge,
        );
      } finally {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test('inspectLocalPhoto never calls an unstatable path "too large"', () {
      expect(
        MealProposalPayload.inspectLocalPhoto(''),
        LocalPhotoIssue.missing,
      );
      expect(
        MealProposalPayload.inspectLocalPhoto('C:/definitely/not/here.jpg'),
        LocalPhotoIssue.missing,
      );
    });
  });

  // The rule the whole audit exists to enforce: a reason the service can
  // produce must always have something to say, in both languages. Iterating
  // the enum means a new reason cannot be added without a string.
  group('ProposalFailureReason → AppStrings — nothing renders blank', () {
    const arabic = AppStrings(Locale('ar'));
    const english = AppStrings(Locale('en'));
    final arabicScript = RegExp(r'[؀-ۿ]');
    // A stand-in provider error: `unknown` is allowed to print it, every other
    // reason must print its own copy instead.
    const cause = 'test-cause';

    test('every reason has a non-empty line in BOTH locales', () {
      for (final reason in ProposalFailureReason.values) {
        final ar = proposalFailureLabel(arabic, reason, cause: cause);
        final en = proposalFailureLabel(english, reason, cause: cause);
        expect(ar.trim(), isNotEmpty, reason: '$reason has no Arabic copy');
        expect(en.trim(), isNotEmpty, reason: '$reason has no English copy');
      }
    });

    test('every translated reason is actually translated', () {
      for (final reason in ProposalFailureReason.values) {
        // `unknown` deliberately shows the raw provider text in both locales.
        if (reason == ProposalFailureReason.unknown) continue;
        final ar = proposalFailureLabel(arabic, reason, cause: cause);
        final en = proposalFailureLabel(english, reason, cause: cause);
        expect(ar, isNot(en), reason: '$reason was written in one language only');
        expect(
          arabicScript.hasMatch(ar),
          isTrue,
          reason: '$reason Arabic line carries no Arabic',
        );
        expect(
          arabicScript.hasMatch(en),
          isFalse,
          reason: '$reason English line carries Arabic',
        );
      }
    });

    test('no translated reason is just the raw error dumped at the user', () {
      // A reason that fell through to the `unknown` path would print the raw
      // provider text in both locales — this catches a new reason whose value
      // was added to the enum but never wired into the rendering switch.
      for (final reason in ProposalFailureReason.values) {
        final en = proposalFailureLabel(english, reason, cause: cause);
        if (reason == ProposalFailureReason.unknown) {
          // The one deliberate exception: unknown shows the provider's own
          // text, which is exactly the cause string the label was handed.
          expect(en, contains(cause));
          continue;
        }
        expect(
          en.trim(),
          isNot(cause),
          reason: '$reason renders as raw provider text instead of a label',
        );
      }
    });

    test('the enum stays big enough to name every stage', () {
      // Every stage of the flow must be distinguishable: firebase init,
      // provider disabled, sign-in rejected, sign-in lost, sign-in with no uid,
      // rules, connectivity, cancelled, missing target, quota, ledger, the
      // three photo-causes-on-device, the three upload shapes, unknown.
      expect(ProposalFailureReason.values.length, greaterThanOrEqualTo(18));
      expect(
        ProposalFailureReason.values.toSet().length,
        ProposalFailureReason.values.length,
      );
    });

    // ---- The same rule one level up: the OUTCOME codes the UI renders ----
    //
    // `proposalOutcomeLabel` is an exhaustive switch over
    // [ProposalOutcomeCode], so a new outcome without copy is a compile error;
    // walking the enum here is what catches a code that was wired but wired to
    // the wrong string.
    ProposalOutcome outcomeFor(ProposalOutcomeCode code) => switch (code) {
          ProposalOutcomeCode.submitted => ProposalOutcome.submitted(),
          ProposalOutcomeCode.alreadyProposed =>
            ProposalOutcome.alreadyProposed(),
          ProposalOutcomeCode.alreadyInPublicVault =>
            ProposalOutcome.alreadyInPublicVault(),
          ProposalOutcomeCode.blockedNoConnection =>
            ProposalOutcome.blocked(CloudAccessStatus.noConnection),
          ProposalOutcomeCode.blockedRequiresWifi =>
            ProposalOutcome.blocked(CloudAccessStatus.requiresWifi),
          ProposalOutcomeCode.invalidName => ProposalOutcome.invalidName(),
          ProposalOutcomeCode.dailyLimitReached =>
            ProposalOutcome.dailyLimitReached(),
          ProposalOutcomeCode.cloudUnchanged => ProposalOutcome.cloudUnchanged(),
          // Rendered with a named stage rather than `unknown`, which is the one
          // reason allowed to echo the raw provider text back.
          ProposalOutcomeCode.failed => ProposalOutcome.failed(
              cause,
              reason: ProposalFailureReason.writePermissionDenied,
            ),
        };

    test('every outcome code has a non-empty line in BOTH locales', () {
      for (final code in ProposalOutcomeCode.values) {
        final outcome = outcomeFor(code);
        final ar = proposalOutcomeLabel(arabic, outcome);
        final en = proposalOutcomeLabel(english, outcome);
        expect(ar.trim(), isNotEmpty, reason: '$code has no Arabic copy');
        expect(en.trim(), isNotEmpty, reason: '$code has no English copy');
      }
    });

    test('every outcome code is actually translated', () {
      for (final code in ProposalOutcomeCode.values) {
        final outcome = outcomeFor(code);
        final ar = proposalOutcomeLabel(arabic, outcome);
        final en = proposalOutcomeLabel(english, outcome);
        expect(
          ar,
          isNot(en),
          reason: '$code was written in one language only',
        );
        expect(
          arabicScript.hasMatch(ar),
          isTrue,
          reason: '$code Arabic line carries no Arabic',
        );
        expect(
          arabicScript.hasMatch(en),
          isFalse,
          reason: '$code English line carries Arabic',
        );
      }
    });

    test('a public-vault hit is its own outcome, not the local duplicate', () {
      // Two different answers the user acts on differently: "edit it and send
      // again" versus "the vault already serves this, nothing to send".
      expect(
        ProposalOutcome.alreadyInPublicVault().code,
        isNot(ProposalOutcomeCode.alreadyProposed),
      );
      expect(ProposalOutcome.alreadyInPublicVault().isSuccess, isFalse);
    });

    test('the public-vault line keeps the backlog wording, the 👏 included', () {
      final outcome = ProposalOutcome.alreadyInPublicVault();
      expect(
        proposalOutcomeLabel(arabic, outcome),
        'هذه الأكلة متوفرة بالفعل في الخزنة العامة 👏',
      );
      expect(
        proposalOutcomeLabel(english, outcome),
        'This meal is already available in the public vault 👏',
      );
    });
  });

  // Gap 6: the gate lives where the payload is built, not only in the UI flow.
  group('proposeMeal — the shared connectivity precondition', () {
    MealProposalService gated(CloudAccessStatus status) =>
        MealProposalService(accessStatus: () async => status);

    test('a blocked network stops before Firebase, with the right code',
        () async {
      const cases = <CloudAccessStatus, ProposalOutcomeCode>{
        CloudAccessStatus.noConnection:
            ProposalOutcomeCode.blockedNoConnection,
        CloudAccessStatus.requiresWifi: ProposalOutcomeCode.blockedRequiresWifi,
      };
      for (final entry in cases.entries) {
        final outcome = await gated(entry.key).proposeMeal(_meal());
        expect(outcome.code, entry.value, reason: entry.key.name);
        expect(outcome.isSuccess, isFalse);
      }
    });

    test('a gate that throws is read as no connection', () async {
      final outcome = await MealProposalService(
        accessStatus: () async => throw StateError('connectivity plugin missing'),
      ).proposeMeal(_meal());
      expect(outcome.code, ProposalOutcomeCode.blockedNoConnection);
    });

    test('the shared helper normalises both outcomes the same way', () async {
      expect(
        await resolveProposalCloudAccess(
          () async => CloudAccessStatus.allowed,
        ),
        CloudAccessStatus.allowed,
      );
      expect(
        await resolveProposalCloudAccess(
          () async => throw Exception('boom'),
        ),
        CloudAccessStatus.noConnection,
      );
    });

    test('an allowed gate lets the flow reach the next stage', () async {
      SharedPreferences.setMockInitialValues({});
      final outcome = await MealProposalService(
        prefs: await SharedPreferences.getInstance(),
        accessStatus: () async => CloudAccessStatus.allowed,
      ).proposeMeal(_meal());

      // No Firebase exists in a unit test, so the very next stage (anonymous
      // sign-in) fails. The point is that the gate did not stop it, and the
      // reason named is the honest one rather than `unknown`.
      expect(outcome.code, ProposalOutcomeCode.failed);
      expect(outcome.reason, ProposalFailureReason.firebaseNotReady);
    });

    test('a service built without a gate does not invent a network failure',
        () async {
      final outcome = await MealProposalService().proposeMeal(_meal());
      expect(
        outcome.code,
        isNot(ProposalOutcomeCode.blockedNoConnection),
        reason: 'direct construction has no connectivity plumbing to ask',
      );
    });
  });

  // The fourth safeguard: `vault_meals` is public-read (`firestore.rules`), so
  // a meal the vault already serves is answered before the photo upload, before
  // the staging write and before the daily allowance is spent.
  //
  // HONEST SCOPE: dev_dependencies carry no fake Firestore and `pubspec.yaml` is
  // off-limits here, so the queries themselves are not executed against a stub —
  // the probe is injected. What these tests pin is the *contract around* the
  // query: which names it is handed, what a hit/miss/error/hang does to the
  // flow, and that a hit costs no quota and no ledger mark. The live query
  // (`collection('vault_meals').where('name', isEqualTo: n).limit(1)`) is
  // exercised only through the "no Firestore at all" case below, which proves it
  // cannot block a proposal when it cannot run.
  group('proposeMeal — the public-vault pre-flight', () {
    Future<SharedPreferences> freshPrefs() async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    MealProposalService probing(
      SharedPreferences prefs,
      Future<bool> Function(List<String> vaultNames) probe,
    ) =>
        MealProposalService(
          prefs: prefs,
          accessStatus: () async => CloudAccessStatus.allowed,
          publicVaultDuplicateProbe: probe,
        );

    test('a vault hit stops the proposal with its own outcome', () async {
      final prefs = await freshPrefs();
      final probed = <List<String>>[];

      final outcome = await probing(prefs, (names) async {
        probed.add(names);
        return true;
      }).proposeMeal(_meal(id: 21, name: '  محشي بلدي  ', shortName: 'محشي'));

      expect(outcome.code, ProposalOutcomeCode.alreadyInPublicVault);
      expect(outcome.isSuccess, isFalse);
      // Probed with the payload's stored name first, then the local short name.
      expect(probed, [
        ['محشي بلدي', 'محشي']
      ]);
    });

    test('a vault hit costs no quota and leaves no ledger entry', () async {
      final prefs = await freshPrefs();
      final meal = _meal(id: 22, name: 'كشري');

      final outcome = await probing(prefs, (names) async => true)
          .proposeMeal(meal);

      expect(outcome.code, ProposalOutcomeCode.alreadyInPublicVault);
      expect(ProposalQuota(prefs).usedToday(), 0);
      expect(ProposalQuota(prefs).remainingToday(), ProposalQuota.dailyLimit);
      expect(ProposalQuota(prefs).hasAllowance(), isTrue);
      expect(ProposalGuard(prefs).alreadyProposed(meal), isFalse);
      // The ledger really is untouched on disk, not just unread.
      expect(prefs.getString(ProposalGuard.prefsKey), isNull);
    });

    test('after a duplicate answer another meal still gets through', () async {
      // The point of not spending quota/ledger on a hit: the next proposal is
      // treated exactly as it would have been.
      final prefs = await freshPrefs();
      await probing(prefs, (names) async => true).proposeMeal(_meal(id: 23));

      final next = await probing(prefs, (names) async => false)
          .proposeMeal(_meal(id: 24));

      // No Firebase exists in a unit test, so the stage right after the
      // pre-flight (anonymous sign-in) is what fails — proof the duplicate
      // answer did not leave the day, or the meal, blocked.
      expect(next.code, ProposalOutcomeCode.failed);
      expect(next.reason, ProposalFailureReason.firebaseNotReady);
      expect(ProposalQuota(prefs).usedToday(), 0);
    });

    test('a vault miss continues to the upload stages', () async {
      final prefs = await freshPrefs();
      final probed = <String>[];

      final outcome = await probing(prefs, (names) async {
        probed.addAll(names);
        return false;
      }).proposeMeal(_meal(name: '  فتة  ', shortName: null));

      expect(probed, ['فتة']);
      expect(outcome.code, isNot(ProposalOutcomeCode.alreadyInPublicVault));
      expect(outcome.code, ProposalOutcomeCode.failed);
      expect(outcome.reason, ProposalFailureReason.firebaseNotReady);
    });

    test('a vault read that throws is swallowed, never reported to the user',
        () async {
      final prefs = await freshPrefs();

      for (final probe in <Future<bool> Function(List<String>)>[
        // Rules/network shaped failures…
        (names) async => throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: 'Missing or insufficient permissions.',
            ),
        (names) async => throw TimeoutException('vault never answered'),
        // …and a Firebase that was never initialised (a plain synchronous
        // throw, the shape a unit test and a misconfigured build both produce).
        (names) =>
            throw StateError("No Firebase App '[DEFAULT]' has been created"),
      ]) {
        final outcome = await probing(prefs, probe).proposeMeal(_meal());

        expect(
          outcome.code,
          isNot(ProposalOutcomeCode.alreadyInPublicVault),
          reason: 'a check that cannot answer may not claim a duplicate',
        );
        expect(outcome.code, ProposalOutcomeCode.failed);
        expect(
          outcome.reason,
          ProposalFailureReason.firebaseNotReady,
          reason: 'the proposal kept going and died at the next stage, as before',
        );
        expect(ProposalQuota(prefs).usedToday(), 0);
      }
    });

    test('a vault read that never answers is cut off by its own deadline',
        () async {
      final prefs = await freshPrefs();
      final never = Completer<bool>();
      final watch = Stopwatch()..start();

      final outcome =
          await probing(prefs, (names) => never.future).proposeMeal(_meal());
      watch.stop();

      expect(outcome.code, ProposalOutcomeCode.failed);
      expect(outcome.reason, ProposalFailureReason.firebaseNotReady);
      expect(
        watch.elapsed,
        greaterThanOrEqualTo(MealProposalService.publicVaultReadTimeout),
        reason: 'the deadline is what released the flow',
      );
      expect(
        watch.elapsed,
        lessThan(MealProposalService.publicVaultReadTimeout * 3),
        reason: 'the pre-flight must not hold the propose button open',
      );
    });

    test('nothing to probe means no network read at all', () async {
      final prefs = await freshPrefs();
      var calls = 0;

      // A name below the rules minimum can never be a vault duplicate, and the
      // payload builder rejects it anyway — so the probe is skipped and the
      // flow still reports the honest next-stage failure.
      final outcome = await probing(prefs, (names) async {
        calls++;
        return true;
      }).proposeMeal(_meal(name: 'ف', shortName: null));

      expect(calls, 0);
      expect(outcome.code, isNot(ProposalOutcomeCode.alreadyInPublicVault));
    });

    test('the default probe runs the live query path and cannot block',
        () async {
      final prefs = await freshPrefs();

      // No injected stand-in and no Firebase in this process: `_queryPublicVault`
      // fails on its very first step, is caught, and the proposal continues.
      final outcome = await MealProposalService(
        prefs: prefs,
        accessStatus: () async => CloudAccessStatus.allowed,
      ).proposeMeal(_meal());

      expect(outcome.code, isNot(ProposalOutcomeCode.alreadyInPublicVault));
      expect(outcome.reason, ProposalFailureReason.firebaseNotReady);
      expect(ProposalQuota(prefs).usedToday(), 0);
    });

    test('the pre-flight has its own bounded timeout', () {
      // Style check on the constant the flow awaits: a real, finite bound in the
      // same family as the other stage deadlines, and shorter than the stages it
      // protects.
      expect(
        MealProposalService.publicVaultReadTimeout,
        greaterThan(Duration.zero),
      );
      expect(
        MealProposalService.publicVaultReadTimeout,
        lessThan(MealProposalService.writeTimeout),
      );
    });
  });
}
