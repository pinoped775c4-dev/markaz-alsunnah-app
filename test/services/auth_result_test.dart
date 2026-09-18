import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/models/app_user.dart';
import 'package:islamic_center_manager/services/auth_service.dart';

/// اختبارات AuthResult — نتيجة عملية المصادقة
/// هذه الاختبارات لا تحتاج Firebase (كود نقي)
void main() {
  group('AuthResult', () {
    // ===== نتائج النجاح =====

    test('success result contains user and no error', () {
      final user = AppUser(
        uid: 'uid-123',
        role: 'teacher',
        name: 'أحمد',
        email: 'ahmed@test.com',
        status: 'active',
      );
      final result = AuthResult.success(user);

      expect(result.isSuccess, true);
      expect(result.user, isNotNull);
      expect(result.user!.uid, 'uid-123');
      expect(result.user!.name, 'أحمد');
      expect(result.errorMessage, isNull);
    });

    test('success result with admin user', () {
      final admin = AppUser(
        uid: 'admin-1',
        role: 'admin',
        name: 'المدير',
        email: 'admin@test.com',
        status: 'active',
      );
      final result = AuthResult.success(admin);

      expect(result.isSuccess, true);
      expect(result.user!.isAdmin, true);
      expect(result.user!.isTeacher, false);
    });

    // ===== نتائج الفشل =====

    test('failure result contains error message and no user', () {
      final result = AuthResult.failure('كلمة المرور خاطئة');

      expect(result.isSuccess, false);
      expect(result.user, isNull);
      expect(result.errorMessage, 'كلمة المرور خاطئة');
    });

    test('failure result with Arabic error message', () {
      final result = AuthResult.failure('لا يوجد حساب مرتبط بهذا البريد');

      expect(result.isSuccess, false);
      expect(result.errorMessage, contains('لا يوجد حساب'));
    });

    test('failure result with empty error message', () {
      final result = AuthResult.failure('');

      expect(result.isSuccess, false);
      expect(result.errorMessage, '');
    });
  });

  group('AppUser', () {
    // ===== الأدوار =====

    test('admin user: isAdmin is true, isTeacher is false', () {
      final user = AppUser(
        uid: '1',
        role: 'admin',
        name: 'مدير',
        email: 'admin@test.com',
        status: 'active',
      );
      expect(user.isAdmin, true);
      expect(user.isTeacher, false);
    });

    test('teacher user: isTeacher is true, isAdmin is false', () {
      final user = AppUser(
        uid: '2',
        role: 'teacher',
        name: 'معلم',
        email: 'teacher@test.com',
        status: 'active',
      );
      expect(user.isTeacher, true);
      expect(user.isAdmin, false);
    });

    // ===== الحالات =====

    test('active user: isActive is true', () {
      final user = AppUser(
        uid: '1',
        role: 'teacher',
        name: 'معلم',
        email: 't@test.com',
        status: 'active',
      );
      expect(user.isActive, true);
    });

    test('disabled user: isActive is false', () {
      final user = AppUser(
        uid: '1',
        role: 'teacher',
        name: 'معلم',
        email: 't@test.com',
        status: 'disabled',
      );
      expect(user.isActive, false);
    });

    // ===== copyWith =====

    test('copyWith updates only specified fields', () {
      final user = AppUser(
        uid: '1',
        role: 'teacher',
        name: 'أحمد',
        email: 'ahmed@test.com',
        status: 'active',
        phone: '777123456',
      );

      final updated = user.copyWith(name: 'أحمد محمد');

      expect(updated.name, 'أحمد محمد'); // تغيّر
      expect(updated.uid, '1'); // لم يتغير
      expect(updated.email, 'ahmed@test.com'); // لم يتغير
      expect(updated.phone, '777123456'); // لم يتغير
    });

    test('copyWith with no arguments returns same values', () {
      final user = AppUser(
        uid: '1',
        role: 'teacher',
        name: 'أحمد',
        email: 'ahmed@test.com',
        status: 'active',
      );

      final copy = user.copyWith();

      expect(copy.name, user.name);
      expect(copy.email, user.email);
      expect(copy.role, user.role);
      expect(copy.status, user.status);
    });

    // ===== toMap =====

    test('toMap contains all required fields', () {
      final user = AppUser(
        uid: '1',
        role: 'teacher',
        name: 'أحمد',
        email: 'ahmed@test.com',
        status: 'active',
        specialization: 'قرآن',
        phone: '777123456',
      );

      final map = user.toMap();

      expect(map['role'], 'teacher');
      expect(map['name'], 'أحمد');
      expect(map['email'], 'ahmed@test.com');
      expect(map['status'], 'active');
      expect(map['specialization'], 'قرآن');
      expect(map['phone'], '777123456');
    });

    test('toMap does not contain uid (it is the document ID)', () {
      final user = AppUser(
        uid: '1',
        role: 'teacher',
        name: 'أحمد',
        email: 'ahmed@test.com',
        status: 'active',
      );

      final map = user.toMap();
      expect(map.containsKey('uid'), false);
    });

    test('toMap handles null optional fields', () {
      final user = AppUser(
        uid: '1',
        role: 'teacher',
        name: 'أحمد',
        email: 'ahmed@test.com',
        status: 'active',
      );

      final map = user.toMap();
      expect(map['specialization'], isNull);
      expect(map['phone'], isNull);
      expect(map['photoBase64'], isNull);
    });
  });
}
