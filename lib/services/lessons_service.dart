import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/lesson.dart';

/// نتيجة عملية على الدروس
class LessonOpResult {
  final bool success;
  final String? errorMessage;
  /// الدرس المُنشأ (إن وُجد) — يُستخدم للعرض المتفائل الفوري
  final Lesson? lesson;

  const LessonOpResult.ok() : success = true, errorMessage = null, lesson = null;
  const LessonOpResult.okWith(this.lesson)
      : success = true, errorMessage = null;
  const LessonOpResult.fail(this.errorMessage)
      : success = false, lesson = null;
}

/// خدمة الدروس — كل الاستعلامات مُرشّحة بـ teacherId للأمان
class LessonsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// اسم اليوم بالعربية من التاريخ
  static String weekdayOf(DateTime date) =>
      DateFormat('EEEE', 'ar').format(date);

  // ================= إعداد الدرس الأولي =================

  /// بث الدرس الوحيد للمسار (إن وُجد)
  ///
  /// ملاحظة مهمة: نستخدم شرطًا واحدًا فقط (teacherId) ثم نرشّح محليًا،
  /// لأن الجمع بين شرطي where على (teacherId + pathwayId) يتطلب فهرسًا
  /// مركبًا في Firestore — وغيابه كان يسبب تعليق الـ stream بلا رد.
  /// الاستعلام البسيط يعمل فورًا ويستفيد من الكاش المحلي عند انقطاع النت.
  Stream<Lesson?> watchPathwayLesson({
    required String teacherId,
    required String pathwayId,
  }) {
    // جلب يدوي أولي لتعبئة الكاش فورًا — يضمن ظهور البيانات حتى لو تأخر البث
    _firestore
        .collection('lessons')
        .where('teacherId', isEqualTo: teacherId)
        .get()
        .then((_) {}, onError: (Object e) {
      debugPrint('LessonsService warm-up get error: $e');
    });

    return _firestore
        .collection('lessons')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      for (final doc in snapshot.docs) {
        if (doc.data()['pathwayId'] == pathwayId) {
          try {
            return Lesson.fromFirestore(doc);
          } catch (e) {
            debugPrint('LessonsService: تعذّر تحويل بيانات الدرس: $e');
            return null;
          }
        }
      }
      return null;
    });
  }

  /// إنشاء إعداد الدرس الأولي
  Future<LessonOpResult> setupLesson({
    required String teacherId,
    required String pathwayId,
    required String name,
    required String type,
    required int totalCount,
  }) async {
    try {
      final docRef = await _firestore.collection('lessons').add({
        'teacherId': teacherId,
        'pathwayId': pathwayId,
        'name': name.trim(),
        'type': type,
        'totalCount': totalCount,
        'completedCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // بناء الدرس محليًا من المعرّف والقيم المُدخلة — يتيح عرضه فورًا
      // (تحديث متفائل) قبل وصول أول snapshot من البث.
      final created = Lesson(
        id: docRef.id,
        teacherId: teacherId,
        pathwayId: pathwayId,
        name: name.trim(),
        type: type,
        totalCount: totalCount,
        completedCount: 0,
        createdAt: DateTime.now(),
      );
      return LessonOpResult.okWith(created);
    } catch (e) {
      debugPrint('LessonsService.setupLesson error: $e');
      return const LessonOpResult.fail('فشل حفظ إعداد الدرس، حاول مرة أخرى');
    }
  }

  // ================= تسجيل درس يومي (معاملة ذرّية) =================

  Future<LessonOpResult> addDailyRecording({
    required Lesson lesson,
    required DateTime date,
    required String duration,
    required int from,
    required int to,
    String? notes,
    required List<String> presentStudentIds,
    required List<String> absentStudentIds,
  }) async {
    try {
      final count = to - from + 1;
      final totalStudents =
          presentStudentIds.length + absentStudentIds.length;

      await _firestore.runTransaction((transaction) async {
        // 1) تحديث عداد الدرس المنجز
        final lessonRef =
            _firestore.collection('lessons').doc(lesson.id);
        transaction.update(lessonRef, {
          'completedCount': lesson.completedCount + count,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2) إنشاء تسجيل الدرس اليومي
        final recordingRef =
            _firestore.collection('lesson_recordings').doc();
        transaction.set(recordingRef, {
          'lessonId': lesson.id,
          'teacherId': lesson.teacherId,
          'pathwayId': lesson.pathwayId,
          'weekday': weekdayOf(date),
          'date': Timestamp.fromDate(date),
          'duration': duration.trim(),
          'from': from,
          'to': to,
          'count': count,
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
          'presentCount': presentStudentIds.length,
          'totalStudents': totalStudents,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3) إنشاء وثيقة الحضور
        final attendanceRef =
            _firestore.collection('attendance').doc();
        transaction.set(attendanceRef, {
          'lessonId': lesson.id,
          'recordingId': recordingRef.id,
          'teacherId': lesson.teacherId,
          'pathwayId': lesson.pathwayId,
          'date': Timestamp.fromDate(date),
          'presentStudentIds': presentStudentIds,
          'absentStudentIds': absentStudentIds,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      return const LessonOpResult.ok();
    } catch (e) {
      debugPrint('LessonsService.addDailyRecording error: $e');
      return const LessonOpResult.fail(
          'فشل حفظ الدرس اليومي، حاول مرة أخرى');
    }
  }

  // ================= الحضور المرتبط بتسجيل =================

  /// يعيد قائمة معرّفات الطلاب الحاضرين لتسجيل معيّن (لوضع التعديل)
  Future<List<String>?> fetchPresentIds(String recordingId) async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .where('recordingId', isEqualTo: recordingId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final ids = snapshot.docs.first.data()['presentStudentIds'];
      if (ids is List) {
        return ids.map((e) => e.toString()).toList();
      }
      return null;
    } catch (e) {
      debugPrint('LessonsService.fetchPresentIds error: $e');
      return null;
    }
  }

  // ================= سجل الدروس اليومية =================

  Stream<List<LessonRecording>> watchRecordings({
    required String teacherId,
    required String lessonId,
  }) {
    // شرط واحد فقط (teacherId) + ترشيح lessonId محليًا —
    // الجمع بين شرطين يتطلب فهرسًا مركبًا قد يكون مفقودًا فيسبب
    // تعليق البث وعدم ظهور الإضافات للمستخدم.
    return _firestore
        .collection('lesson_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final recordings = snapshot.docs
          .where((doc) => doc.data()['lessonId'] == lessonId)
          .map((doc) => LessonRecording.fromFirestore(doc))
          .toList();
      // الأحدث أولاً — فرز في الذاكرة لتفادي الفهارس المركّبة
      recordings.sort((a, b) => b.date.compareTo(a.date));
      return recordings;
    });
  }

  // ================= حذف تسجيل (مع إرجاع العداد) =================

  Future<LessonOpResult> deleteRecording(
      LessonRecording recording, int currentCompleted) async {
    try {
      await _firestore.runTransaction((transaction) async {
        transaction.delete(_firestore
            .collection('lesson_recordings')
            .doc(recording.id));

        // حذف وثيقة الحضور المرتبطة
        final attendanceQuery = await _firestore
            .collection('attendance')
            .where('recordingId', isEqualTo: recording.id)
            .get();
        for (final doc in attendanceQuery.docs) {
          transaction.delete(doc.reference);
        }

        // إرجاع العداد المنجز
        final newCompleted =
            (currentCompleted - recording.count).clamp(0, 1 << 31);
        transaction.update(
            _firestore.collection('lessons').doc(recording.lessonId), {
          'completedCount': newCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return const LessonOpResult.ok();
    } catch (e) {
      debugPrint('LessonsService.deleteRecording error: $e');
      return const LessonOpResult.fail('فشل حذف التسجيل، حاول مرة أخرى');
    }
  }

  /// تعديل تسجيل يومي (يُعدّل العداد بالفرق)
  Future<LessonOpResult> updateRecording({
    required LessonRecording recording,
    required int oldCount,
    required DateTime date,
    required String duration,
    required int from,
    required int to,
    String? notes,
    required List<String> presentStudentIds,
    required List<String> absentStudentIds,
    required int currentCompleted,
  }) async {
    try {
      final newCount = to - from + 1;
      final diff = newCount - oldCount;
      final totalStudents =
          presentStudentIds.length + absentStudentIds.length;

      await _firestore.runTransaction((transaction) async {
        transaction.update(
            _firestore
                .collection('lesson_recordings')
                .doc(recording.id),
            {
              'weekday': weekdayOf(date),
              'date': Timestamp.fromDate(date),
              'duration': duration.trim(),
              'from': from,
              'to': to,
              'count': newCount,
              'notes': notes?.trim().isEmpty == true
                  ? null
                  : notes?.trim(),
              'presentCount': presentStudentIds.length,
              'totalStudents': totalStudents,
            });

        // تحديث وثيقة الحضور المرتبطة
        final attendanceQuery = await _firestore
            .collection('attendance')
            .where('recordingId', isEqualTo: recording.id)
            .get();
        if (attendanceQuery.docs.isNotEmpty) {
          transaction.update(attendanceQuery.docs.first.reference, {
            'date': Timestamp.fromDate(date),
            'presentStudentIds': presentStudentIds,
            'absentStudentIds': absentStudentIds,
          });
        } else {
          transaction.set(_firestore.collection('attendance').doc(), {
            'lessonId': recording.lessonId,
            'recordingId': recording.id,
            'teacherId': recording.teacherId,
            'pathwayId': recording.pathwayId,
            'date': Timestamp.fromDate(date),
            'presentStudentIds': presentStudentIds,
            'absentStudentIds': absentStudentIds,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (diff != 0) {
          transaction.update(
              _firestore.collection('lessons').doc(recording.lessonId),
              {
                'completedCount': currentCompleted + diff,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
      });
      return const LessonOpResult.ok();
    } catch (e) {
      debugPrint('LessonsService.updateRecording error: $e');
      return const LessonOpResult.fail('فشل تعديل التسجيل، حاول مرة أخرى');
    }
  }
}
