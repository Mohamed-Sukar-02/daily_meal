// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daily_meal/features/admin/data/admin_security_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDocumentSnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  @override
  final bool exists;
  @override
  final String id;

  FakeDocumentSnapshot({required this.exists, required this.id});
}

class FakeDocumentReference<T extends Object?> extends Fake
    implements DocumentReference<T> {
  final String docId;
  final Map<String, Map<String, dynamic>> store;
  final bool shouldThrow;

  FakeDocumentReference(this.docId, this.store, {this.shouldThrow = false});

  @override
  String get id => docId;

  @override
  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    if (shouldThrow) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Permission denied',
      );
    }
    final exists = store.containsKey(docId);
    return FakeDocumentSnapshot<T>(exists: exists, id: docId);
  }

  @override
  Future<void> set(T data, [SetOptions? options]) async {
    if (shouldThrow) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Permission denied',
      );
    }
    if (data is Map<String, dynamic>) {
      store[docId] = data;
    }
  }
}

class FakeCollectionReference<T extends Object?> extends Fake
    implements CollectionReference<T> {
  final String collectionPath;
  final Map<String, Map<String, dynamic>> store;
  bool shouldThrowOnDocGet;

  FakeCollectionReference(
    this.collectionPath,
    this.store, {
    this.shouldThrowOnDocGet = false,
  });

  @override
  DocumentReference<T> doc([String? path]) {
    return FakeDocumentReference<T>(
      path ?? 'auto_id',
      store,
      shouldThrow: shouldThrowOnDocGet,
    );
  }
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, Map<String, dynamic>>> collections = {};
  bool throwOnDocGet = false;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    collections.putIfAbsent(collectionPath, () => {});
    return FakeCollectionReference<Map<String, dynamic>>(
      collectionPath,
      collections[collectionPath]!,
      shouldThrowOnDocGet: throwOnDocGet,
    );
  }
}

void main() {
  group('AdminSecurityService Empirical Challenger Probe', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AdminSecurityService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = AdminSecurityService(fakeFirestore);
    });

    test('Null, empty, and whitespace inputs return false without querying Firestore', () async {
      expect(await service.isEmailAdmin(null), isFalse);
      expect(await service.isEmailAdmin(''), isFalse);
      expect(await service.isEmailAdmin('   '), isFalse);
      expect(await service.isEmailAdmin('\t\n\r  '), isFalse);
      expect(fakeFirestore.collections.containsKey('admins'), isFalse);
    });

    test('Case-insensitivity and whitespace trimming correctly resolve existing admin doc', () async {
      // Seed admin into collection with normalized id
      fakeFirestore.collections.putIfAbsent('admins', () => {})['mohamedsukar88@gmail.com'] = {
        'email': 'mohamedsukar88@gmail.com',
        'role': 'admin',
      };

      // Exact match
      expect(await service.isEmailAdmin('mohamedsukar88@gmail.com'), isTrue);

      // Mixed case
      expect(await service.isEmailAdmin('MohamedSukar88@Gmail.com'), isTrue);
      expect(await service.isEmailAdmin('MOHAMEDSUKAR88@GMAIL.COM'), isTrue);

      // Surrounding whitespace
      expect(await service.isEmailAdmin('  mohamedsukar88@gmail.com  '), isTrue);
      expect(await service.isEmailAdmin('\t MohamedSukar88@Gmail.com \n'), isTrue);

      // Unauthorized or partial emails
      expect(await service.isEmailAdmin('mohamedsukar88@gmail.com.attacker.com'), isFalse);
      expect(await service.isEmailAdmin('attacker@mohamedsukar88@gmail.com'), isFalse);
      expect(await service.isEmailAdmin('mohamedsukar88'), isFalse);
      expect(await service.isEmailAdmin('random_user@gmail.com'), isFalse);
    });

    test('Fail-closed: Firestore exceptions safely return false instead of propagating', () async {
      fakeFirestore.throwOnDocGet = true;

      // Even if the email is otherwise valid, service must fail-closed and return false
      final result = await service.isEmailAdmin('mohamedsukar88@gmail.com');
      expect(result, isFalse);
    });

    test('seedAdmin normalizes email and stores lowercase doc ID', () async {
      await service.seedAdmin(email: '  NEW_SUPER_ADMIN@DAILYMEAL.APP  ');

      final admins = fakeFirestore.collections['admins'];
      expect(admins, isNotNull);
      expect(admins!.containsKey('new_super_admin@dailymeal.app'), isTrue);
      expect(admins['new_super_admin@dailymeal.app']!['email'], equals('  NEW_SUPER_ADMIN@DAILYMEAL.APP  '));
      expect(admins['new_super_admin@dailymeal.app']!['role'], equals('admin'));

      // Now query with different casing and whitespace
      expect(await service.isEmailAdmin('new_super_admin@dailymeal.app'), isTrue);
      expect(await service.isEmailAdmin('  NEW_SUPER_ADMIN@DAILYMEAL.APP  '), isTrue);
    });
  });
}
