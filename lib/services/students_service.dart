import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/student.dart';

/// نتيجة عملية على الطلاب
class StudentOpResult {
  final bool success;
  final String? errorMessage;

  const StudentOpResult.ok() : success = true, errorMessage = null;
  const StudentOpResult.fail(this.errorMessage) : success = false;
}

/// خدمة إدارة الطلاب — الطلاب مشتركون بين جميع المعلمين:
/// - الإدارة (admin) وحدها تضيف/تحذف/تعدّل الطلاب.
/// - المعلمون يقرؤون طلاب مسارهم ويعملون معهم (حضور، تسميع، أوراد).
/// الاستعلامات تُرشَّح بـ pathwayId فقط (شرط واحد — لا فهارس مركبة).
class StudentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================= بث طلاب مسار معين =================

  ///
  /// الطلاب مشتركون: شرط واحد فقط (pathwayId) ثم فرز محلي —
  /// الجمع بين شرطي where يتطلب فهرسًا مركبًا مفقودًا في Firestore،
  /// وغيابه كان يعلّق قائمة الطلاب بلا رد (loading إلى الأبد).
  Stream<List<Student>> watchPathwayStudents({
    String? teacherId, // مُخلَّد للتوافق — لم يعد يُستخدم في الفلترة
    required String pathwayId,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا — يضمن ظهور الطلاب حتى لو تأخر البث
    _firestore
        .collection('students')
        .where('pathwayId', isEqualTo: pathwayId)
        .get()
        .then((_) {}, onError: (Object e) {
      debugPrint('StudentsService warm-up get error: $e');
    });

    return _firestore
        .collection('students')
        .where('pathwayId', isEqualTo: pathwayId)
        .snapshots()
        .map((snapshot) {
      final students = snapshot.docs
          .map((doc) => Student.fromFirestore(doc))
          .toList();
      // فرز أبجدي في الذاكرة لتفادي الفهارس المركّبة
      students.sort((a, b) => a.name.compareTo(b.name));
      return students;
    });
  }

  // ================= جلب طلاب مسار معين مرة واحدة (موثوق) =================

  /// جلب مباشر get() بدل البث — يُستخدم في حوار الدرس اليومي لضمان ظهور
  /// جدول الحضور فورًا حتى لو تأخر البث أو علق في انتظار الخادم
  Future<List<Student>> fetchPathwayStudents({
    String? teacherId, // مُخلَّد للتوافق — لم يعد يُستخدم في الفلترة
    required String pathwayId,
  }) async {
    final snapshot = await _firestore
        .collection('students')
        .where('pathwayId', isEqualTo: pathwayId)
        .get();
    final students = snapshot.docs
        .map((doc) => Student.fromFirestore(doc))
        .toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  // ================= بث طلاب مسار معين (للإدارة) =================

  /// الطلاب مشتركون — نفس استعلام watchPathwayStudents.
  Stream<List<Student>> watchPathwayStudentsForAdmin({
    required String pathwayId,
  }) {
    return watchPathwayStudents(pathwayId: pathwayId);
  }

  // ================= عدد الطلاب لكل مسار =================

  /// عدّ طلاب كل مستوى — الطلاب مشتركون فلا فلترة بمعلم.
  Stream<Map<String, int>> watchStudentCounts([String? teacherId]) {
    return _firestore
        .collection('students')
        .snapshots()
        .map((snapshot) {
      final counts = <String, int>{
        for (final p in AppConstants.pathways) p.id: 0,
      };
      for (final doc in snapshot.docs) {
        final pathwayId = doc.data()['pathwayId'] as String?;
        if (pathwayId != null && counts.containsKey(pathwayId)) {
          counts[pathwayId] = counts[pathwayId]! + 1;
        }
      }
      return counts;
    });
  }

  /// إجمالي الطلاب في المستوى
  Stream<int> watchTotalStudents([String? teacherId]) {
    return _firestore
        .collection('students')
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ================= إضافة طالب (الإدارة فقط) =================

  Future<StudentOpResult> addStudent({
    String? teacherId, // مُخلَّد للتوافق — الإدارة لا تحدد معلمًا
    required String pathwayId,
    required String pathwayName,
    required String name,
    String? phone,
    String? notes,
  }) async {
    try {
      await _firestore.collection('students').add({
        'pathwayId': pathwayId,
        'pathwayName': pathwayName,
        'name': name.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'enrolledAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'totalQuranPages': 0,
        'lastQuranWard': null,
      });
      return const StudentOpResult.ok();
    } catch (e) {
      debugPrint('StudentsService.addStudent error: $e');
      return const StudentOpResult.fail('فشل إضافة الطالب، حاول مرة أخرى');
    }
  }

  // ================= حذف طالب (الإدارة فقط) =================

  Future<StudentOpResult> deleteStudent(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).delete();
      return const StudentOpResult.ok();
    } catch (e) {
      debugPrint('StudentsService.deleteStudent error: $e');
      return const StudentOpResult.fail('فشل حذف الطالب، حاول مرة أخرى');
    }
  }
}
