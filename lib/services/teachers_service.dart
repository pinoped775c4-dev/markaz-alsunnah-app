import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import 'mutun_wird_service.dart';

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
        'تم إنشاء الحساب لكن فشل حفظ البيانات، حاول مرة أخرى',
      );
    } catch (e) {
      debugPrint('TeachersService.createTeacher error: $e');
      return const TeacherOpResult.fail(
        'حدث خطأ غير متوقع، تحقق من الإنترنت وحاول مرة أخرى',
      );
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
          final teachers = snapshot.docs
              .map((doc) => AppUser.fromFirestore(doc))
              .toList();
          // فرز في الذاكرة: الأحدث أولاً
          teachers.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return teachers;
        });
  }

  /// جلب المعلمين النشطين مرة واحدة (get بدل stream) — للاستخدام في الحوارات
  Future<List<AppUser>> fetchActiveTeachers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      final teachers = snapshot.docs
          .map((doc) => AppUser.fromFirestore(doc))
          .where((t) => t.isActive)
          .toList();
      teachers.sort((a, b) => a.name.compareTo(b.name));
      return teachers;
    } catch (e) {
      debugPrint('TeachersService.fetchActiveTeachers error: $e');
      return [];
    }
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
      return const TeacherOpResult.fail('فشل تحديث حالة المعلم، حاول مرة أخرى');
    }
  }

  // ================= حذف حساب المعلم نهائيًا =================

  /// حذف مستند المعلم من Firestore مع تنظيف كل بياناته المرتبطة:
  /// طلابه، دروسه، تسجيلات الدروس اليومية، سجلات الحضور، المتون
  /// وتسجيلاتها، وتسجيلات القرآن — كل ذلك عبر معاملات مجمّعة (Batches).
  ///
  /// ملاحظة: حذف حساب Firebase Auth نفسه يتطلب صلاحيات خادم (Admin SDK)
  /// غير متاحة من التطبيق — لكن حذف مستند users يمنع المعلم من الدخول
  /// نهائيًا لأن التطبيق يتحقق من وجود الملف الشخصي عند تسجيل الدخول.
  Future<TeacherOpResult> deleteTeacherAccount(String uid) async {
    try {
      final teacherDoc = _firestore.collection('users').doc(uid);

      // المرحلة 1: تنظيف البيانات المرتبطة (دفعات منفصلة لكل مجموعة)
      // مستندات الدروس نحتفظ بمراجعها لنستخدمها في حذف الحضور
      final lessonsSnap = await _firestore
          .collection('lessons')
          .where('teacherId', isEqualTo: uid)
          .get();
      final lessonIds = lessonsSnap.docs.map((d) => d.id).toList();

      // حذف سجلات الحضور المرتبطة بدروس المعلم (مرجعها lessonId)
      // نعالج 10 دروس في كل استعلام (حد whereIn في Firestore)
      for (var i = 0; i < lessonIds.length; i += 10) {
        final chunk = lessonIds.sublist(
          i,
          i + 10 > lessonIds.length ? lessonIds.length : i + 10,
        );
        final attendanceSnap = await _firestore
            .collection('attendance')
            .where('lessonId', whereIn: chunk)
            .get();
        if (attendanceSnap.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final doc in attendanceSnap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // باقي المجموعات تُربط مباشرة بـ teacherId
      for (final collection in const [
        'students',
        'lessons',
        'lesson_recordings',
        'mutun',
        'mutun_recordings',
        'quran_recordings',
      ]) {
        final snapshot = await _firestore
            .collection(collection)
            .where('teacherId', isEqualTo: uid)
            .get();
        // Firestore Batch يقبل 500 عملية كحد أقصى — نقسّم عند الحاجة
        for (var i = 0; i < snapshot.docs.length; i += 400) {
          final batch = _firestore.batch();
          final chunk = snapshot.docs.sublist(
            i,
            i + 400 > snapshot.docs.length ? snapshot.docs.length : i + 400,
          );
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // المرحلة 2: حذف ملف المعلم نفسه
      // إغلاق تعيين المتون والأوراد إذا كان المحذوف هو المعلم المسؤول
      // (التعيين يُفرَّغ ويُلحق بالتاريخ — والسجلات الرسمية السابقة
      // المختومة isOfficial تبقى رسمية — لا حذف لأي بيانات إطلاقاً)
      await MutunWirdService().closeDesignationForDeletedTeacher(uid);

      await teacherDoc.delete();

      return const TeacherOpResult.ok();
    } catch (e) {
      debugPrint('TeachersService.deleteTeacherAccount error: $e');
      return const TeacherOpResult.fail(
        'فشل حذف حساب المعلم، تحقق من الإنترنت وحاول مرة أخرى',
      );
    }
  }

  // ================= إعادة تعيين كلمة المرور =================

  /// إعادة تعيين كلمة المرور من قِبل المدير مباشرة:
  /// تُخزن ككلمة مرور مؤقتة في ملف المستخدم (users) — لأن حسابات
  /// Firebase Auth لا يمكن تعديل كلمة مرورها إلا من صاحبها.
  /// عند تسجيل الدخول: إذا فشل دخول Firebase Auth بنجاح، يفحص
  /// التطبيق كلمة المرور المؤقتة هذه ويمنح جلسة افتراضية.
  Future<TeacherOpResult> resetTeacherPassword({
    required String uid,
    required String newPassword,
  }) async {
    if (newPassword.trim().length < 8) {
      return const TeacherOpResult.fail(
        'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
      );
    }
    try {
      await _firestore.collection('users').doc(uid).update({
        'tempPassword': newPassword.trim(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });
      return const TeacherOpResult.ok();
    } catch (e) {
      debugPrint('TeachersService.resetTeacherPassword error: $e');
      return const TeacherOpResult.fail(
        'فشل حفظ كلمة المرور الجديدة، تحقق من الإنترنت وحاول مرة أخرى',
      );
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
