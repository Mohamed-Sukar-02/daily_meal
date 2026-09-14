import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daily_meal/features/admin/data/admin_auth_service.dart';
import 'package:daily_meal/features/admin/data/admin_security_service.dart';
import 'package:daily_meal/features/admin/data/vault_admin_repository.dart';
import 'package:daily_meal/features/admin/presentation/admin_auth_screen.dart';
import 'package:daily_meal/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:daily_meal/features/admin/presentation/admin_root_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockUser extends Fake implements User {
  @override
  final String? email;

  MockUser({this.email});
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  FakeUserCredential({this.user});
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  bool signOutCalled = false;
  final User? userToReturn;

  FakeFirebaseAuth({this.userToReturn});

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return FakeUserCredential(user: userToReturn ?? MockUser(email: email));
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    return FakeUserCredential(
        user: userToReturn ?? MockUser(email: 'google-user@test.com'));
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class FakeAdminAuthService extends Fake implements AdminAuthService {
  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class FakeAdminSecurityService implements AdminSecurityService {
  final Set<String> authorizedAdmins;
  final List<String> seededAdmins = [];

  FakeAdminSecurityService({Set<String>? authorizedAdmins})
      : authorizedAdmins = authorizedAdmins ?? {'mohamedsukar88@gmail.com'};

  @override
  Future<bool> isEmailAdmin(String? email) async {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return authorizedAdmins.contains(normalized);
  }

  @override
  Future<void> seedAdmin({
    required String email,
    FirebaseFirestore? firestore,
  }) async {
    final normalized = email.trim().toLowerCase();
    seededAdmins.add(normalized);
    authorizedAdmins.add(normalized);
  }
}

Widget createRootApp({
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: AdminRootScreen(),
    ),
  );
}

void main() {
  group('AdminSecurityService — Normalization & Whitelist Logic Unit Tests', () {
    late FakeAdminSecurityService securityService;

    setUp(() {
      securityService = FakeAdminSecurityService(
        authorizedAdmins: {'mohamedsukar88@gmail.com'},
      );
    });

    test('isEmailAdmin returns false for null or empty input', () async {
      expect(await securityService.isEmailAdmin(null), isFalse);
      expect(await securityService.isEmailAdmin(''), isFalse);
      expect(await securityService.isEmailAdmin('   '), isFalse);
    });

    test('isEmailAdmin verifies case-insensitively with trimming', () async {
      expect(await securityService.isEmailAdmin('mohamedsukar88@gmail.com'), isTrue);
      expect(await securityService.isEmailAdmin('  MOHAMEDSUKAR88@GMAIL.COM  '), isTrue);
      expect(await securityService.isEmailAdmin('unauthorized@test.com'), isFalse);
    });

    test('seedAdmin normalizes email and authorizes new admin', () async {
      await securityService.seedAdmin(email: '  NEW_ADMIN@DAILYMEAL.APP  ');

      expect(securityService.seededAdmins, contains('new_admin@dailymeal.app'));
      expect(await securityService.isEmailAdmin('new_admin@dailymeal.app'), isTrue);
    });
  });

  group('AdminAuthService — Service Guard Unit Tests', () {
    late FakeAdminSecurityService securityService;

    setUp(() {
      securityService = FakeAdminSecurityService(
        authorizedAdmins: {'mohamedsukar88@gmail.com'},
      );
    });

    test('signInWithEmail succeeds for authorized admin', () async {
      final fakeAuth = FakeFirebaseAuth(
        userToReturn: MockUser(email: 'mohamedsukar88@gmail.com'),
      );
      final authService = AdminAuthService(
        fakeAuth,
        adminSecurityService: securityService,
      );

      final cred = await authService.signInWithEmail(
        'mohamedsukar88@gmail.com',
        'password123',
      );

      expect(cred.user?.email, equals('mohamedsukar88@gmail.com'));
      expect(fakeAuth.signOutCalled, isFalse);
    });

    test('signInWithEmail rejects unauthorized email, signs out, and throws AdminUnauthorizedException', () async {
      final fakeAuth = FakeFirebaseAuth(
        userToReturn: MockUser(email: 'intruder@evil.com'),
      );
      final authService = AdminAuthService(
        fakeAuth,
        adminSecurityService: securityService,
      );

      await expectLater(
        () => authService.signInWithEmail('intruder@evil.com', 'password123'),
        throwsA(isA<AdminUnauthorizedException>().having(
          (e) => e.message,
          'message',
          contains('البريد الإلكتروني غير مصرح له بالدخول كمسؤول'),
        )),
      );

      expect(fakeAuth.signOutCalled, isTrue);
    });

    test('signInWithGoogle succeeds for authorized admin', () async {
      final fakeAuth = FakeFirebaseAuth(
        userToReturn: MockUser(email: 'mohamedsukar88@gmail.com'),
      );
      final authService = AdminAuthService(
        fakeAuth,
        adminSecurityService: securityService,
      );

      final cred = await authService.signInWithGoogle();

      expect(cred.user?.email, equals('mohamedsukar88@gmail.com'));
      expect(fakeAuth.signOutCalled, isFalse);
    });

    test('signInWithGoogle rejects unauthorized email, signs out, and throws AdminUnauthorizedException', () async {
      final fakeAuth = FakeFirebaseAuth(
        userToReturn: MockUser(email: 'unauthorized-google@gmail.com'),
      );
      final authService = AdminAuthService(
        fakeAuth,
        adminSecurityService: securityService,
      );

      await expectLater(
        () => authService.signInWithGoogle(),
        throwsA(isA<AdminUnauthorizedException>().having(
          (e) => e.message,
          'message',
          contains('البريد الإلكتروني غير مصرح له بالدخول كمسؤول'),
        )),
      );

      expect(fakeAuth.signOutCalled, isTrue);
    });
  });

  group('AdminRootScreen — Root Guard Widget Tests', () {
    testWidgets('Authorized admin mounts AdminDashboardScreen and NOT AdminAuthScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminUser = MockUser(email: 'mohamedsukar88@gmail.com');
      final fakeAuthService = FakeAdminAuthService();

      await tester.pumpWidget(createRootApp(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(adminUser)),
          isAdminProvider(adminUser.email).overrideWith((ref) => Future.value(true)),
          adminAuthServiceProvider.overrideWithValue(fakeAuthService),
          vaultMealsStreamProvider.overrideWith((ref) => Stream.value([])),
          stagingMealsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      ));
      await tester.pumpAndSettle();

      // AdminDashboardScreen MUST be mounted
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      // AdminAuthScreen must NOT be mounted
      expect(find.byType(AdminAuthScreen), findsNothing);
      // signOut must NOT have been called
      expect(fakeAuthService.signOutCalled, isFalse);
    });

    testWidgets('Unauthorized email triggers signOut, shows AdminAuthScreen with error, and NEVER mounts AdminDashboardScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final unauthorizedUser = MockUser(email: 'hacker@malicious.com');
      final fakeAuthService = FakeAdminAuthService();

      await tester.pumpWidget(createRootApp(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(unauthorizedUser)),
          isAdminProvider(unauthorizedUser.email).overrideWith((ref) => Future.value(false)),
          adminAuthServiceProvider.overrideWithValue(fakeAuthService),
          vaultMealsStreamProvider.overrideWith((ref) => Stream.value([])),
          stagingMealsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      ));
      await tester.pumpAndSettle();

      // AdminDashboardScreen must NEVER be mounted
      expect(find.byType(AdminDashboardScreen), findsNothing);
      // AdminAuthScreen must be mounted
      expect(find.byType(AdminAuthScreen), findsOneWidget);
      // Unauthorized error message is displayed in error container
      expect(
        find.text('غير مصرح لك بالوصول إلى لوحة التحكم كمسؤول. تم تسجيل الخروج تلقائياً.'),
        findsOneWidget,
      );
      // signOut must have been triggered via postFrameCallback
      expect(fakeAuthService.signOutCalled, isTrue);
    });

    testWidgets('Error in isAdminProvider triggers signOut and displays unauthorized error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final user = MockUser(email: 'unknown@error.com');
      final fakeAuthService = FakeAdminAuthService();

      await tester.pumpWidget(createRootApp(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          isAdminProvider(user.email).overrideWith((ref) => Future.error(Exception('Firestore error'))),
          adminAuthServiceProvider.overrideWithValue(fakeAuthService),
          vaultMealsStreamProvider.overrideWith((ref) => Stream.value([])),
          stagingMealsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.byType(AdminAuthScreen), findsOneWidget);
      expect(
        find.text('غير مصرح لك بالوصول إلى لوحة التحكم كمسؤول. تم تسجيل الخروج تلقائياً.'),
        findsOneWidget,
      );
      expect(fakeAuthService.signOutCalled, isTrue);
    });

    testWidgets('Loading isAdminProvider displays CircularProgressIndicator and does NOT mount AdminDashboardScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final user = MockUser(email: 'loading@test.com');
      final completer = Completer<bool>();

      await tester.pumpWidget(createRootApp(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          isAdminProvider(user.email).overrideWith((ref) => completer.future),
          adminAuthServiceProvider.overrideWithValue(FakeAdminAuthService()),
        ],
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.byType(AdminAuthScreen), findsNothing);
    });

    testWidgets('Null user displays AdminAuthScreen without initial error', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createRootApp(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          adminAuthServiceProvider.overrideWithValue(FakeAdminAuthService()),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AdminAuthScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.byKey(const Key('admin_auth_error_container')), findsNothing);
    });
  });
}
