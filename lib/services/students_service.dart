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

/// خدمة إدارة الطلاب — كل الاستعلامات مُرشّحة بـ teacherId للأمان
class StudentsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================= بث طلاب مسار معين (للمعلم الحالي) =================

  ///
  /// شرط واحد فقط (teacherId) ثم ترشيح pathwayId محليًا —
  /// الجمع بين شرطي where يتطلب فهرسًا مركبًا مفقودًا في Firestore،
  /// وغيابه كان يعلّق قائمة الطلاب بلا رد (loading إلى الأبد).
  Stream<List<Student>> watchPathwayStudents({
    required String teacherId,
    required String pathwayId,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا — يضمن ظهور الطلاب حتى لو تأخر البث
    _firestore
        .collection('students')
        .where('teacherId', isEqualTo: teacherId)
        .get()
        .then((_) {}, onError: (Object e) {
      debugPrint('StudentsService warm-up get error: $e');
    });

    return _firestore
        .collection('students')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final students = snapshot.docs
          .where((doc) => doc.data()['pathwayId'] == pathwayId)
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
    required String teacherId,
    required String pathwayId,
  }) async {
    final snapshot = await _firestore
        .collection('students')
        .where('teacherId', isEqualTo: teacherId)
        .get();
    final students = snapshot.docs
        .where((doc) => doc.data()['pathwayId'] == pathwayId)
        .map((doc) => Student.fromFirestore(doc))
        .toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  // ================= عدد الطلاب لكل مسار (لإحصائيات لوحة المعلم) =================

  Stream<Map<String, int>> watchStudentCounts(String teacherId) {
    return _firestore
        .collection('students')
        .where('teacherId', isEqualTo: teacherId)
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

  /// إجمالي طلاب المعلم
  Stream<int> watchTotalStudents(String teacherId) {
    return _firestore
        .collection('students')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ================= إضافة طالب =================

  Future<StudentOpResult> addStudent({
    required String teacherId,
    required String pathwayId,
    required String pathwayName,
    required String name,
    String? phone,
    String? notes,
  }) async {
    try {
      await _firestore.collection('students').add({
        'teacherId': teacherId,
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

  // ================= حذف طالب =================

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
