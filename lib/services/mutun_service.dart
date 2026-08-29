import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/matna.dart';

/// نتيجة عملية على المتون
class MutunOpResult {
  final bool success;
  final String? errorMessage;
  final String? docId;

  const MutunOpResult.ok({this.docId})
      : success = true,
        errorMessage = null;
  const MutunOpResult.fail(this.errorMessage)
      : success = false,
        docId = null;
}

/// خدمة المتون — كل الاستعلامات مُرشّحة بـ teacherId للأمان
class MutunService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String weekdayOf(DateTime date) =>
      DateFormat('EEEE', 'ar').format(date);

  // ================= المتون (المقررات) =================

  /// بث متون مسار معيّن لمعلم (فرز في الذاكرة)
  Stream<List<Matna>> watchPathwayMutun({
    required String teacherId,
    required String pathwayId,
  }) {
    return _firestore
        .collection('mutun')
        .where('teacherId', isEqualTo: teacherId)
        .where('pathwayId', isEqualTo: pathwayId)
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((d) => Matna.fromFirestore(d)).toList();
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
      return MutunOpResult.ok(docId: ref.id);
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
  Stream<List<MutunRecording>> watchMatnaRecordings({
    required String teacherId,
    required String matnaId,
  }) {
    return _firestore
        .collection('mutun_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .where('matnaId', isEqualTo: matnaId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((d) => MutunRecording.fromFirestore(d))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date)); // الأحدث أولاً
      return list;
    });
  }

  /// تسجيل حفظ يومي لطالب
  Future<MutunOpResult> addRecording({
    required Matna matna,
    required String studentId,
    required DateTime date,
    required int from,
    required int to,
    String? notes,
  }) async {
    try {
      await _firestore.collection('mutun_recordings').add({
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
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const MutunOpResult.ok();
    } catch (e) {
      debugPrint('MutunService.addRecording error: $e');
      return const MutunOpResult.fail('تعذّر حفظ التسجيل. حاول مجدداً.');
    }
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
