import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/features/admin/data/admin_security_config.dart';

void main() {
  group('AdminSecurityConfig — Constants & Setup', () {
    test('constants have expected secure values', () {
      expect(AdminSecurityConfig.masterPassword, equals('Admin@2026'));
      expect(AdminSecurityConfig.totpBase32Secret, equals('JBSWY3DPEHPK3PXP'));
      expect(
        AdminSecurityConfig.allowedAdminEmails,
        containsAll([
          'mohamedsukar88@gmail.com',
          'admin@dailymeal.app',
          'admin@dailymeal.com',
        ]),
      );
    });
  });

  group('AdminSecurityConfig — Gatekeeper Verification', () {
    final fixedTime = DateTime(2026, 9, 13, 12, 0, 0).millisecondsSinceEpoch;

    test('valid master password and valid current TOTP succeed', () {
      final code = AdminSecurityConfig.generateTOTP(currentTimeMillis: fixedTime);
      final result = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: 'Admin@2026',
        totpCode: code,
        currentTimeMillis: fixedTime,
      );
      expect(result, isTrue);
    });

    test('valid master password with previous window TOTP (-30s) succeeds', () {
      // Code generated 30 seconds earlier
      final pastCode = AdminSecurityConfig.generateTOTP(
        currentTimeMillis: fixedTime - 30000,
      );
      final result = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: 'Admin@2026',
        totpCode: pastCode,
        currentTimeMillis: fixedTime,
      );
      expect(result, isTrue);
    });

    test('valid master password with next window TOTP (+30s) succeeds', () {
      // Code generated 30 seconds later
      final futureCode = AdminSecurityConfig.generateTOTP(
        currentTimeMillis: fixedTime + 30000,
      );
      final result = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: 'Admin@2026',
        totpCode: futureCode,
        currentTimeMillis: fixedTime,
      );
      expect(result, isTrue);
    });

    test('code generated outside +-30s window is rejected', () {
      // 65 seconds in the past
      final tooOldCode = AdminSecurityConfig.generateTOTP(
        currentTimeMillis: fixedTime - 65000,
      );
      final resultPast = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: 'Admin@2026',
        totpCode: tooOldCode,
        currentTimeMillis: fixedTime,
      );
      expect(resultPast, isFalse);

      // 65 seconds in the future
      final tooNewCode = AdminSecurityConfig.generateTOTP(
        currentTimeMillis: fixedTime + 65000,
      );
      final resultFuture = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: 'Admin@2026',
        totpCode: tooNewCode,
        currentTimeMillis: fixedTime,
      );
      expect(resultFuture, isFalse);
    });

    test('incorrect master password rejects even with valid TOTP', () {
      final code = AdminSecurityConfig.generateTOTP(currentTimeMillis: fixedTime);
      final result = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: 'WrongPassword',
        totpCode: code,
        currentTimeMillis: fixedTime,
      );
      expect(result, isFalse);
    });

    test('incorrect TOTP rejects even with valid master password', () {
      final result = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: 'Admin@2026',
        totpCode: '000000',
        currentTimeMillis: fixedTime,
      );
      expect(result, isFalse);
    });

    test('empty or whitespace-only inputs reject gracefully', () {
      expect(
        AdminSecurityConfig.verifyGatekeeper(
          masterPassword: '',
          totpCode: '123456',
          currentTimeMillis: fixedTime,
        ),
        isFalse,
      );
      expect(
        AdminSecurityConfig.verifyGatekeeper(
          masterPassword: '   ',
          totpCode: '123456',
          currentTimeMillis: fixedTime,
        ),
        isFalse,
      );
      expect(
        AdminSecurityConfig.verifyGatekeeper(
          masterPassword: 'Admin@2026',
          totpCode: '',
          currentTimeMillis: fixedTime,
        ),
        isFalse,
      );
      expect(
        AdminSecurityConfig.verifyGatekeeper(
          masterPassword: 'Admin@2026',
          totpCode: '   ',
          currentTimeMillis: fixedTime,
        ),
        isFalse,
      );
    });

    test('trims surrounding whitespace on both inputs', () {
      final code = AdminSecurityConfig.generateTOTP(currentTimeMillis: fixedTime);
      final result = AdminSecurityConfig.verifyGatekeeper(
        masterPassword: '  Admin@2026  ',
        totpCode: '  $code  ',
        currentTimeMillis: fixedTime,
      );
      expect(result, isTrue);
    });
  });

  group('AdminSecurityConfig — Email Whitelist Authorization', () {
    test('authorizes exact whitelisted emails', () {
      expect(
        AdminSecurityConfig.isEmailAuthorized('mohamedsukar88@gmail.com'),
        isTrue,
      );
      expect(
        AdminSecurityConfig.isEmailAuthorized('admin@dailymeal.app'),
        isTrue,
      );
      expect(
        AdminSecurityConfig.isEmailAuthorized('admin@dailymeal.com'),
        isTrue,
      );
    });

    test('handles case-insensitivity and surrounding whitespace', () {
      expect(
        AdminSecurityConfig.isEmailAuthorized('MohamedSukar88@Gmail.com'),
        isTrue,
      );
      expect(
        AdminSecurityConfig.isEmailAuthorized('  ADMIN@DAILYMEAL.APP  '),
        isTrue,
      );
      expect(
        AdminSecurityConfig.isEmailAuthorized('  admin@DailyMeal.com  '),
        isTrue,
      );
    });

    test('blocks unauthorized emails', () {
      expect(
        AdminSecurityConfig.isEmailAuthorized('hacker@evil.com'),
        isFalse,
      );
      expect(
        AdminSecurityConfig.isEmailAuthorized('user@gmail.com'),
        isFalse,
      );
      expect(
        AdminSecurityConfig.isEmailAuthorized('admin@dailymeal.org'),
        isFalse,
      );
    });

    test('blocks null, empty, and whitespace-only emails', () {
      expect(AdminSecurityConfig.isEmailAuthorized(null), isFalse);
      expect(AdminSecurityConfig.isEmailAuthorized(''), isFalse);
      expect(AdminSecurityConfig.isEmailAuthorized('   '), isFalse);
    });
  });
}
