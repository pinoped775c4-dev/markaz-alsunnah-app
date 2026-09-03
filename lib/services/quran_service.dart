import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/quran.dart';
import 'mutun_wird_service.dart';

/// نتيجة عملية قرآنية
class QuranOpResult {
  final bool success;
  final String? errorMessage;

  const QuranOpResult.ok() : success = true, errorMessage = null;
  const QuranOpResult.fail(this.errorMessage) : success = false;
}

/// خدمة الأوراد القرآنية — كل الاستعلامات مُرشّحة بـ teacherId
///
/// نظام "معلم المتون والأوراد": تسجيل الأوراد الرسمية متاح
/// للمعلم المسؤول المخصص من الإدارة فقط (تحقق فعلي في الخدمة)،
/// والورد الجديد يُختم بـ isOfficial فيدخل التقارير الرسمية.
class QuranService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MutunWirdService _wirdService = MutunWirdService();

  static String weekdayOf(DateTime date) =>
      DateFormat('EEEE', 'ar').format(date);

  /// بث كل تسجيلات معلم في مسار معيّن (تُجمّع لكل طالب في الذاكرة)
  ///
  /// شرط واحد فقط (teacherId) ثم ترشيح pathwayId محليًا —
  /// الجمع بين شرطي where يتطلب فهرسًا مركبًا مفقودًا في Firestore
  /// وكان يعلّق البث فلا تظهر تسجيلات الورد المضافة.
  Stream<List<QuranRecording>> watchPathwayRecordings({
    required String teacherId,
    required String pathwayId,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا — يضمن ظهور السجل حتى لو تأخر البث
    _firestore
        .collection('quran_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .get()
        .then(
          (_) {},
          onError: (Object e) {
            debugPrint('QuranService.watchPathwayRecordings warm-up error: $e');
          },
        );

    return _firestore
        .collection('quran_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .where((d) => d.data()['pathwayId'] == pathwayId)
              .map((d) => QuranRecording.fromFirestore(d))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date)); // الأحدث أولاً
          return list;
        });
  }

  /// بث كل تسجيلات معلم في كل المسارات (لتقارير الإدارة)
  Stream<List<QuranRecording>> watchAllTeacherRecordings(String teacherId) {
    return _firestore
        .collection('quran_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => QuranRecording.fromFirestore(d))
              .toList(),
        );
  }

  /// بث تسجيلات الورد القرآني لطالب معيّن (لتقارير الطلاب في حساب الإدارة)
  /// شرط واحد (studentId) — لتفادي الفهارس المركّبة — + فرز الأحدث أولاً
  Stream<List<QuranRecording>> watchStudentRecordings({
    required String studentId,
    bool officialOnly = false,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا قبل أول snapshot
    _firestore
        .collection('quran_recordings')
        .where('studentId', isEqualTo: studentId)
        .get()
        .then(
          (_) {},
          onError: (Object e) {
            debugPrint('QuranService.watchStudentRecordings warm-up error: $e');
          },
        );

    return _firestore
        .collection('quran_recordings')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .where((d) => !officialOnly || d.data()['isOfficial'] == true)
              .map((d) => QuranRecording.fromFirestore(d))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date)); // الأحدث أولاً
          return list;
        });
  }

  /// تسجيل ورد يومي لطالب — رسمي للمعلم المسؤول المخصص فقط (يُختم isOfficial)
  Future<QuranOpResult> addWardRecording({
    required String teacherId,
    required String pathwayId,
    required String studentId,
    required DateTime date,
    required double fromPage,
    required double toPage,
    String? notes,
  }) async {
    // تحقق فعلي في الخدمة: المسجل يجب أن يكون المعلم المسؤول المخصص
    // ونفس المستخدم المسجل (منع انتحال هوية معلم آخر)
    if (!await _wirdService.canCreateOfficial(teacherId)) {
      return const QuranOpResult.fail(
        'تسجيل الأوراد القرآنية الرسمية متاح لمعلم المتون والأوراد المخصص من الإدارة فقط.',
      );
    }
    // تحقق من نطاق المصحف
    if (fromPage < 1 ||
        toPage > AppConstants.khatmaPages ||
        toPage < fromPage) {
      return QuranOpResult.fail(
        'نطاق الصفحات غير صحيح (1 – ${AppConstants.khatmaPages})',
      );
    }

    try {
      await _firestore.collection('quran_recordings').add({
        'teacherId': teacherId,
        'pathwayId': pathwayId,
        'studentId': studentId,
        'weekday': weekdayOf(date),
        'date': Timestamp.fromDate(date),
        'fromPage': fromPage,
        'toPage': toPage,
        'count': toPage - fromPage + 1,
        'notes': (notes != null && notes.trim().isNotEmpty)
            ? notes.trim()
            : null,
        'isOfficial': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const QuranOpResult.ok();
    } catch (e) {
      debugPrint('QuranService.addWardRecording error: $e');
      return const QuranOpResult.fail('تعذّر حفظ الورد. حاول مجدداً.');
    }
  }

  /// حذف تسجيل ورد — الرسمي: المعلم المسؤول فقط؛ غير الرسمي: المسؤول أو صاحب السجل
  Future<QuranOpResult> deleteRecording(String recordingId) async {
    try {
      // جلب السجل أولاً لفحص صلاحية الحذف (رسمي/غير رسمي)
      final doc = await _firestore
          .collection('quran_recordings')
          .doc(recordingId)
          .get();
      if (!doc.exists) {
        return const QuranOpResult.ok(); // حُذف مسبقاً — لا خطأ
      }
      final rec = QuranRecording.fromFirestore(doc);
      if (!await _wirdService.canDeleteRecord(
        isOfficial: rec.isOfficial,
        recordTeacherId: rec.teacherId,
      )) {
        return QuranOpResult.fail(
          rec.isOfficial
              ? 'حذف السجلات الرسمية متاح لمعلم المتون والأوراد المخصص فقط.'
              : 'لا يمكنك حذف هذا الورد — متاح لصاحبه أو لمعلم المتون والأوراد.',
        );
      }
      await _firestore.collection('quran_recordings').doc(recordingId).delete();
      return const QuranOpResult.ok();
    } catch (e) {
      debugPrint('QuranService.deleteRecording error: $e');
      return const QuranOpResult.fail('تعذّر حذف التسجيل. حاول مجدداً.');
    }
  }
}
