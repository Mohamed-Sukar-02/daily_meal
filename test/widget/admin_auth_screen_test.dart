import 'package:daily_meal/features/admin/data/admin_auth_service.dart';
import 'package:daily_meal/features/admin/presentation/admin_auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUserCredential extends Fake implements UserCredential {}

class FakeAdminAuthService extends Fake implements AdminAuthService {
  String? lastSignedInEmail;
  String? lastSignedInPassword;
  bool googleSignInCalled = false;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    lastSignedInEmail = email;
    lastSignedInPassword = password;
    return FakeUserCredential();
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    googleSignInCalled = true;
    return FakeUserCredential();
  }
}

Widget createScreen({
  String? initialErrorMessage,
  FakeAdminAuthService? authService,
}) {
  final fakeAuth = authService ?? FakeAdminAuthService();
  return ProviderScope(
    overrides: [
      adminAuthProvider.overrideWithValue(fakeAuth),
    ],
    child: MaterialApp(
      home: AdminAuthScreen(
        initialErrorMessage: initialErrorMessage,
      ),
    ),
  );
}

void main() {
  group('AdminAuthScreen — UI & Layout Verification', () {
    testWidgets('R1: Registration UI is completely absent', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createScreen());
      await tester.pump();

      // Ensure Create Account toggle and buttons do NOT exist
      expect(find.byKey(const Key('admin_auth_toggle_mode_button')), findsNothing);
      expect(find.text('Create Account'), findsNothing);
      expect(find.text('إنشاء حساب'), findsNothing);
      expect(find.text('أنشئ حساباً الآن'), findsNothing);
      expect(find.text("Don't have an account? "), findsNothing);
      expect(find.text('ليس لديك حساب؟ '), findsNothing);

      // Gatekeeper fields must NOT exist
      expect(find.byKey(const Key('gatekeeper_master_password_field')), findsNothing);
      expect(find.byKey(const Key('gatekeeper_totp_code_field')), findsNothing);
      expect(find.byKey(const Key('gatekeeper_verify_button')), findsNothing);
      expect(find.byKey(const Key('gatekeeper_back_button')), findsNothing);

      // Sign In elements MUST exist
      expect(find.byKey(const Key('admin_email_field')), findsOneWidget);
      expect(find.byKey(const Key('admin_password_field')), findsOneWidget);
      expect(find.byKey(const Key('admin_auth_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('admin_google_signin_button')), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsAtLeastNWidgets(1));
    });

    testWidgets('R2: initialErrorMessage displays properly when provided', (tester) async {
      const errorMessage = 'غير مصرح لك بالوصول إلى لوحة التحكم كمسؤول. تم تسجيل الخروج تلقائياً.';
      await tester.pumpWidget(createScreen(initialErrorMessage: errorMessage));
      await tester.pump();

      // Error container is visible and displays exact message
      expect(find.byKey(const Key('admin_auth_error_container')), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('R3: initialErrorMessage is hidden when null', (tester) async {
      await tester.pumpWidget(createScreen(initialErrorMessage: null));
      await tester.pump();

      expect(find.byKey(const Key('admin_auth_error_container')), findsNothing);
    });

    testWidgets('R4: Form validation requires valid email and minimum 6 char password', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createScreen());
      await tester.pump();

      // Submit empty
      await tester.tap(find.byKey(const Key('admin_auth_submit_button')));
      await tester.pump();

      expect(find.text('يرجى إدخال البريد'), findsOneWidget);
      expect(find.text('يجب أن لا تقل عن 6 أحرف'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(find.byKey(const Key('admin_email_field')), 'invalid-email');
      await tester.enterText(find.byKey(const Key('admin_password_field')), '123');
      await tester.tap(find.byKey(const Key('admin_auth_submit_button')));
      await tester.pump();

      expect(find.text('بريد غير صالح'), findsOneWidget);
      expect(find.text('يجب أن لا تقل عن 6 أحرف'), findsOneWidget);
    });

    testWidgets('R5: Successful form submission calls signInWithEmail', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAdminAuthService();
      await tester.pumpWidget(createScreen(authService: fakeAuth));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('admin_email_field')), 'mohamedsukar88@gmail.com');
      await tester.enterText(find.byKey(const Key('admin_password_field')), 'secret123');
      await tester.tap(find.byKey(const Key('admin_auth_submit_button')));
      await tester.pump();

      expect(fakeAuth.lastSignedInEmail, equals('mohamedsukar88@gmail.com'));
      expect(fakeAuth.lastSignedInPassword, equals('secret123'));
    });

    testWidgets('R6: Tapping Google Sign-in button triggers signInWithGoogle', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAdminAuthService();
      await tester.pumpWidget(createScreen(authService: fakeAuth));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('admin_google_signin_button')));
      await tester.tap(find.byKey(const Key('admin_google_signin_button')));
      await tester.pump();

      expect(fakeAuth.googleSignInCalled, isTrue);
    });

    testWidgets('R7: Password obscure toggle changes visibility icon', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.pump();

      expect(find.text('🙈'), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin_toggle_password')));
      await tester.pump();

      expect(find.text('👁'), findsOneWidget);
    });
  });
}
