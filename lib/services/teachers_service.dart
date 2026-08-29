import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';

/// نتيجة عملية على المعلمين
class TeacherOpResult {
  final bool success;
  final String? errorMessage;

  const TeacherOpResult.ok() : success = true, errorMessage = null;
  const TeacherOpResult.fail(this.errorMessage) : success = false;
}

/// خدمة إدارة المعلمين (للمدير فقط)
///
/// تستخدم نسخة Firebase ثانوية (Secondary App) لإنشاء حسابات المعلمين
/// حتى لا تتأثر جلسة المدير الحالية — ضروري لخطة Spark المجانية
/// التي لا تدعم Cloud Functions.
class TeachersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // نسخة Firebase ثانوية لإنشاء الحسابات دون استبدال جلسة المدير
  FirebaseApp? _secondaryApp;

  // ================= إنشاء معلم جديد =================

  Future<TeacherOpResult> createTeacher({
    required String adminUid,
    required String name,
    required String email,
    required String password,
    String? specialization,
    String? phone,
  }) async {
    try {
      // تهيئة النسخة الثانوية إن لم تكن موجودة
      _secondaryApp ??= await Firebase.initializeApp(
        name: 'teacher_creation',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: _secondaryApp!);

      // إنشاء حساب Firebase Auth عبر النسخة الثانوية
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final teacherUid = credential.user?.uid;
      if (teacherUid == null) {
        return const TeacherOpResult.fail('فشل إنشاء الحساب، حاول مرة أخرى');
      }

      // تسجيل خروج النسخة الثانوية فوراً حفاظاً على جلسة المدير
      await secondaryAuth.signOut();

      // كتابة ملف المعلم في Firestore
      await _firestore.collection('users').doc(teacherUid).set({
        'role': 'teacher',
        'name': name.trim(),
        'email': email.trim(),
        'status': 'active',
        'specialization': specialization?.trim().isEmpty == true
            ? null
            : specialization?.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return const TeacherOpResult.ok();
    } on FirebaseAuthException catch (e) {
      return TeacherOpResult.fail(_mapError(e));
    } on FirebaseException catch (e) {
      debugPrint('TeachersService.createTeacher Firestore error: $e');
      return const TeacherOpResult.fail(
          'تم إنشاء الحساب لكن فشل حفظ البيانات، حاول مرة أخرى');
    } catch (e) {
      debugPrint('TeachersService.createTeacher error: $e');
      return const TeacherOpResult.fail(
          'حدث خطأ غير متوقع، تحقق من الإنترنت وحاول مرة أخرى');
    }
  }

  // ================= قائمة المعلمين (بث مباشر) =================

  /// بث مباشر لجميع المعلمين — بدون orderBy لتفادي فهارس مركّبة
  /// (الفرز يتم في الذاكرة)
  Stream<List<AppUser>> watchTeachers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .snapshots()
        .map((snapshot) {
      final teachers =
          snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
      // فرز في الذاكرة: الأحدث أولاً
      teachers.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return teachers;
    });
  }

  // ================= تفعيل / تعطيل =================

  Future<TeacherOpResult> setTeacherStatus(String uid, bool active) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'status': active ? 'active' : 'disabled',
      });
      return const TeacherOpResult.ok();
    } catch (e) {
      debugPrint('TeachersService.setTeacherStatus error: $e');
      return const TeacherOpResult.fail(
          'فشل تحديث حالة المعلم، حاول مرة أخرى');
    }
  }

  // ================= إعادة تعيين كلمة المرور =================

  Future<TeacherOpResult> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email.trim());
      return const TeacherOpResult.ok();
    } on FirebaseAuthException catch (e) {
      return TeacherOpResult.fail(_mapError(e));
    } catch (e) {
      return const TeacherOpResult.fail(
          'فشل إرسال رابط إعادة التعيين، حاول مرة أخرى');
    }
  }

  // ================= ترجمة الأخطاء =================

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، يجب أن تكون 8 أحرف على الأقل';
      case 'user-not-found':
        return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت، تحقق من الشبكة';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، انتظر قليلاً ثم حاول مجدداً';
      default:
        return 'حدث خطأ غير متوقع، حاول مرة أخرى';
    }
  }
}
