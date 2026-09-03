import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/matna.dart';

/// نتيجة عملية على المتون
class MutunOpResult {
  final bool success;
  final String? errorMessage;
  final String? docId;
  /// المتن/التسجيل المُنشأ (إن وُجد) — يُستخدم للعرض المتفائل الفوري
  final Matna? matna;
  final MutunRecording? recording;

  const MutunOpResult.ok({this.docId, this.matna, this.recording})
      : success = true,
        errorMessage = null;
  const MutunOpResult.fail(this.errorMessage)
      : success = false,
        docId = null,
        matna = null,
        recording = null;
}

/// خدمة المتون — كل الاستعلامات مُرشّحة بـ teacherId للأمان
class MutunService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String weekdayOf(DateTime date) =>
      DateFormat('EEEE', 'ar').format(date);

  // ================= المتون (المقررات) =================

  /// بث متون مسار معيّن لمعلم (فرز في الذاكرة)
  ///
  /// ملاحظة مهمة: شرط واحد فقط (teacherId) ثم ترشيح pathwayId محليًا —
  /// الجمع بين شرطي where يتطلب فهرسًا مركبًا في Firestore، وغيابه
  /// كان يعلّق البث بلا رد فلا تظهر المتون المضافة للمستخدم إطلاقًا.
  Stream<List<Matna>> watchPathwayMutun({
    required String teacherId,
    required String pathwayId,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا قبل أول snapshot
    _firestore
        .collection('mutun')
        .where('teacherId', isEqualTo: teacherId)
        .get()
        .then((_) {}, onError: (Object e) {
      debugPrint('MutunService warm-up get error: $e');
    });

    return _firestore
        .collection('mutun')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .where((d) => d.data()['pathwayId'] == pathwayId)
          .map((d) => Matna.fromFirestore(d))
          .toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });
      return list;
    });
  }

  /// إضافة متن جديد
  Future<MutunOpResult> addMatna({
    required String teacherId,
    required String pathwayId,
    required String name,
    required String type,
    required int totalCount,
  }) async {
    try {
      final ref = await _firestore.collection('mutun').add({
        'teacherId': teacherId,
        'pathwayId': pathwayId,
        'name': name.trim(),
        'type': type,
        'totalCount': totalCount,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // بناء المتن محليًا — يتيح عرضه فورًا (تحديث متفائل)
      // قبل وصول أول snapshot من البث.
      final created = Matna(
        id: ref.id,
        teacherId: teacherId,
        pathwayId: pathwayId,
        name: name.trim(),
        type: type,
        totalCount: totalCount,
        createdAt: DateTime.now(),
      );
      return MutunOpResult.ok(docId: ref.id, matna: created);
    } catch (e) {
      debugPrint('MutunService.addMatna error: $e');
      return const MutunOpResult.fail('تعذّرت إضافة المتن. تحقق من الاتصال وحاول مجدداً.');
    }
  }

  /// حذف متن مع كل تسجيلاته (معاملة مجمّعة)
  Future<MutunOpResult> deleteMatna(Matna matna) async {
    try {
      final recordings = await _firestore
          .collection('mutun_recordings')
          .where('matnaId', isEqualTo: matna.id)
          .get();

      final batch = _firestore.batch();
      batch.delete(_firestore.collection('mutun').doc(matna.id));
      for (final doc in recordings.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return const MutunOpResult.ok();
    } catch (e) {
      debugPrint('MutunService.deleteMatna error: $e');
      return const MutunOpResult.fail('تعذّر حذف المتن. حاول مجدداً.');
    }
  }

  // ================= تسجيلات الحفظ =================

  /// بث كل تسجيلات متن معيّن (لحساب تقدم كل طالب في الذاكرة)
  /// شرط واحد (teacherId) + ترشيح matnaId محليًا — لتفادي الفهارس المركّبة
  Stream<List<MutunRecording>> watchMatnaRecordings({
    required String teacherId,
    required String matnaId,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا — يضمن ظهور التسجيلات حتى لو تأخر البث
    _firestore
        .collection('mutun_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .get()
        .then((_) {}, onError: (Object e) {
      debugPrint('MutunService.watchMatnaRecordings warm-up error: $e');
    });

    return _firestore
        .collection('mutun_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .where((d) => d.data()['matnaId'] == matnaId)
          .map((d) => MutunRecording.fromFirestore(d))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date)); // الأحدث أولاً
      return list;
    });
  }

  /// تسجيل حفظ يومي لطالب — [status]: 'present' | 'absent' | 'not_listened'
  Future<MutunOpResult> addRecording({
    required Matna matna,
    required String studentId,
    required DateTime date,
    required double from,
    required double to,
    String? notes,
    String status = 'present',
  }) async {
    try {
      final ref = await _firestore.collection('mutun_recordings').add({
        'teacherId': matna.teacherId,
        'pathwayId': matna.pathwayId,
        'matnaId': matna.id,
        'studentId': studentId,
        'weekday': weekdayOf(date),
        'date': Timestamp.fromDate(date),
        'from': from,
        'to': to,
        'count': to - from + 1,
        'notes': (notes != null && notes.trim().isNotEmpty)
            ? notes.trim()
            : null,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // بناء التسجيل محليًا — يتيح عرضه فورًا (تحديث متفائل)
      final created = MutunRecording(
        id: ref.id,
        teacherId: matna.teacherId,
        pathwayId: matna.pathwayId,
        matnaId: matna.id,
        studentId: studentId,
        weekday: weekdayOf(date),
        date: date,
        from: from,
        to: to,
        count: to - from + 1,
        notes: (notes != null && notes.trim().isNotEmpty)
            ? notes.trim()
            : null,
        createdAt: DateTime.now(),
        status: status,
      );
      return MutunOpResult.ok(recording: created);
    } catch (e) {
      debugPrint('MutunService.addRecording error: $e');
      return const MutunOpResult.fail('تعذّر حفظ التسجيل. حاول مجدداً.');
    }
  }

  /// بث تسجيلات طالب معيّن (لتقارير الطلاب في حساب الإدارة)
  /// شرط واحد (studentId) — لتفادي الفهارس المركّبة — + فرز الأحدث أولاً
  Stream<List<MutunRecording>> watchStudentRecordings({
    required String studentId,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا قبل أول snapshot
    _firestore
        .collection('mutun_recordings')
        .where('studentId', isEqualTo: studentId)
        .get()
        .then((_) {}, onError: (Object e) {
      debugPrint('MutunService.watchStudentRecordings warm-up error: $e');
    });

    return _firestore
        .collection('mutun_recordings')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((d) => MutunRecording.fromFirestore(d))
          .toList();
      list.sort((a, b) {
        final cmp = b.date.compareTo(a.date); // الأحدث أولاً
        if (cmp != 0) return cmp;
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// حذف تسجيل حفظ
  Future<MutunOpResult> deleteRecording(String recordingId) async {
    try {
      await _firestore
          .collection('mutun_recordings')
          .doc(recordingId)
          .delete();
      return const MutunOpResult.ok();
    } catch (e) {
      debugPrint('MutunService.deleteRecording error: $e');
      return const MutunOpResult.fail('تعذّر حذف التسجيل. حاول مجدداً.');
    }
  }
}
