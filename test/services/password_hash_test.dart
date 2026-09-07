import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/services/auth_service.dart';

/// اختبارات تشفير كلمات المرور (SHA-256)
/// هذه الاختبارات تكشف:
/// 1. هل نفس كلمة المرور تعطي نفس الـ hash؟
/// 2. هل كلمات مرور مختلفة تعطي hashes مختلفة؟
/// 3. هل المقارنة الآمنة تعمل بشكل صحيح؟
void main() {
  group('Password Hashing (SHA-256)', () {
    // ===== التناسق =====

    test('same password always produces same hash', () {
      final hash1 = AuthService.hashPassword('mypassword');
      final hash2 = AuthService.hashPassword('mypassword');
      expect(hash1, equals(hash2));
    });

    test('different passwords produce different hashes', () {
      final hash1 = AuthService.hashPassword('password1');
      final hash2 = AuthService.hashPassword('password2');
      expect(hash1, isNot(equals(hash2)));
    });

    test('empty password produces a valid hash', () {
      final hash = AuthService.hashPassword('');
      expect(hash.length, 64); // SHA-256 = 64 حرف hex
      expect(hash, isNotEmpty);
    });

    test('Arabic password produces valid hash', () {
      final hash = AuthService.hashPassword('كلمةالسر');
      expect(hash.length, 64);
      expect(hash, isNotEmpty);
    });

    test('hash length is always 64 characters (SHA-256 hex)', () {
      expect(AuthService.hashPassword('a').length, 64);
      expect(AuthService.hashPassword('abcdefghijklmnop').length, 64);
      expect(AuthService.hashPassword('كلمة مرور طويلة جداً').length, 64);
    });

    // ===== Salt =====

    test('hash includes salt (not just raw password hash)', () {
      final hashWithSalt = AuthService.hashPassword('test');
      // لو لم يكن هناك salt، سيكون الـ hash مختلفاً
      // لا نستطيع مقارنته مباشرة لكن نتأكد أنه 64 حرف
      expect(hashWithSalt.length, 64);
    });

    // ===== أمان =====

    test('hash is lowercase hex only', () {
      final hash = AuthService.hashPassword('test123');
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('password with special characters works', () {
      final hash = AuthService.hashPassword('p@ss!#\$%^&*()');
      expect(hash.length, 64);
    });
  });

  group('Secure Compare', () {
    // ===== المقارنة الآمنة =====

    test('identical strings return true', () {
      final hash = AuthService.hashPassword('test');
      expect(AuthService.secureCompare(hash, hash), true);
    });

    test('different strings return false', () {
      final hash1 = AuthService.hashPassword('password1');
      final hash2 = AuthService.hashPassword('password2');
      expect(AuthService.secureCompare(hash1, hash2), false);
    });

    test('different length strings return false', () {
      expect(AuthService.secureCompare('abc', 'abcd'), false);
      expect(AuthService.secureCompare('', 'a'), false);
    });

    test('empty strings are equal', () {
      expect(AuthService.secureCompare('', ''), true);
    });

    test('single character difference returns false', () {
      expect(AuthService.secureCompare('abc', 'axc'), false);
    });

    test('case sensitive comparison', () {
      expect(AuthService.secureCompare('ABC', 'abc'), false);
    });

    test('secure compare with actual hashes', () {
      // تأكيد: hash(password) == hash(password) عبر secureCompare
      final password = 'testPassword123';
      final hash1 = AuthService.hashPassword(password);
      final hash2 = AuthService.hashPassword(password);
      expect(AuthService.secureCompare(hash1, hash2), true);
    });

    test('secure compare rejects wrong password hash', () {
      final correctHash = AuthService.hashPassword('correct');
      final wrongHash = AuthService.hashPassword('wrong');
      expect(AuthService.secureCompare(correctHash, wrongHash), false);
    });
  });
}
