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
  /// تسجيل الدرس اليومي المُنشأ (إن وُجد) — للعرض المتفائل الفوري
  final LessonRecording? recording;

  const LessonOpResult.ok()
      : success = true,
        errorMessage = null,
        lesson = null,
        recording = null;
  const LessonOpResult.okWith(this.lesson)
      : success = true, errorMessage = null, recording = null;
  const LessonOpResult.okWithRecording(this.recording)
      : success = true, errorMessage = null, lesson = null;
  const LessonOpResult.fail(this.errorMessage)
      : success = false,
        lesson = null,
        recording = null;
}

/// خدمة الدروس — كل الاستعلامات مُرشّحة بـ teacherId للأمان
class LessonsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// اسم اليوم بالعربية من التاريخ
  static String weekdayOf(DateTime date) =>
      DateFormat('EEEE', 'ar').format(date);

  // ================= إعداد الدروس =================

  /// بث كل دروس المسار للمعلم (قائمة متعددة — نمط المتون)
  ///
  /// ملاحظة مهمة: نستخدم شرطًا واحدًا فقط (teacherId) ثم نرشّح محليًا،
  /// لأن الجمع بين شرطي where على (teacherId + pathwayId) يتطلب فهرسًا
  /// مركبًا في Firestore — وغيابه كان يسبب تعليق الـ stream بلا رد.
  /// الاستعلام البسيط يعمل فورًا ويستفيد من الكاش المحلي عند انقطاع النت.
  Stream<List<Lesson>> watchPathwayLessons({
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
      final lessons = <Lesson>[];
      for (final doc in snapshot.docs) {
        if (doc.data()['pathwayId'] != pathwayId) continue;
        try {
          lessons.add(Lesson.fromFirestore(doc));
        } catch (e) {
          debugPrint('LessonsService: تعذّر تحويل بيانات الدرس: $e');
        }
      }
      lessons.sort((a, b) {
        final an = a.name;
        final bn = b.name;
        if (an != bn) return an.compareTo(bn);
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return at.compareTo(bt);
      });
      return lessons;
    });
  }

  /// حذف درس نهائًا مع كل تسجيلاته اليومية ووثائق حضوره
  /// (نفس نمط deleteMatna — حذف بالدفعات لتجنّب حد الحجم)
  Future<LessonOpResult> deleteLesson(Lesson lesson) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('lesson_recordings')
            .where('teacherId', isEqualTo: lesson.teacherId)
            .get(),
        _firestore
            .collection('attendance')
            .where('lessonId', isEqualTo: lesson.id)
            .get(),
      ]);

      // تسجيلات الدرس فقط (فلترة محلية لتفادي الفهرس المركب)
      final recordingDocs = results[0]
          .docs
          .where((d) => d.data()['lessonId'] == lesson.id)
          .toList();
      final attendanceDocs =
          results[1].docs;

      // حذف بالدفعات (حد Firestore: 500 عملية للدفعية)
      final batches = <WriteBatch>[_firestore.batch()];
      batches.last.delete(_firestore.collection('lessons').doc(lesson.id));
      int ops = 1;
      for (final doc in [...recordingDocs, ...attendanceDocs]) {
        if (ops >= 450) {
          batches.add(_firestore.batch());
          ops = 0;
        }
        batches.last.delete(doc.reference);
        ops++;
      }

      for (final b in batches) {
        await b.commit();
      }
      return const LessonOpResult.ok();
    } catch (e) {
      debugPrint('LessonsService.deleteLesson error: $e');
      return const LessonOpResult.fail('تعذّر حذف الدرس. حاول مجدداً.');
    }
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
    required double from,
    required double to,
    String? notes,
    required List<String> presentStudentIds,
    required List<String> absentStudentIds,
  }) async {
    try {
      final count = to - from + 1;
      final totalStudents =
          presentStudentIds.length + absentStudentIds.length;

      // نجهّز معرّف التسجيل مسبقًا لنبني النموذج المحلي (عرض متفائل فوري)
      final recordingRef =
          _firestore.collection('lesson_recordings').doc();

      await _firestore.runTransaction((transaction) async {
        // 1) تحديث عداد الدرس المنجز
        final lessonRef =
            _firestore.collection('lessons').doc(lesson.id);
        transaction.update(lessonRef, {
          'completedCount': lesson.completedCount + count.round(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2) إنشاء تسجيل الدرس اليومي
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

      // البناء المحلي للتسجيل — يُعرض فورًا قبل وصول بث Firestore
      final created = LessonRecording(
        id: recordingRef.id,
        lessonId: lesson.id,
        teacherId: lesson.teacherId,
        pathwayId: lesson.pathwayId,
        weekday: weekdayOf(date),
        date: date,
        duration: duration.trim(),
        from: from,
        to: to,
        count: count,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        presentCount: presentStudentIds.length,
        totalStudents: totalStudents,
        createdAt: DateTime.now(),
      );
      return LessonOpResult.okWithRecording(created);
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
    // جلب يدوي أولي لتعبئة الكاش فورًا — يضمن ظهور السجل حتى لو تأخر البث.
    _firestore
        .collection('lesson_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .get()
        .then((_) {}, onError: (Object e) {
      debugPrint('LessonsService.watchRecordings warm-up error: $e');
    });

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

  /// جلب آخر تسجيل يومي لدرس معيّن (الأحدث بالتاريخ) —
  /// يُستخدم للترقيم التلقائي: "من" في الدرس الجديد = آخر "إلى" + 1.
  /// شرط واحد (teacherId) + فلترة lessonId محلياً — بلا فهارس مركّبة.
  Future<LessonRecording?> fetchLatestRecording({
    required String teacherId,
    required String lessonId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('lesson_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      final recordings = snapshot.docs
          .where((doc) => doc.data()['lessonId'] == lessonId)
          .map((doc) => LessonRecording.fromFirestore(doc))
          .toList();
      if (recordings.isEmpty) return null;
      // الأحدث بالتاريخ — فرز في الذاكرة
      recordings.sort((a, b) => b.date.compareTo(a.date));
      return recordings.first;
    } catch (e) {
      debugPrint('LessonsService.fetchLatestRecording error: $e');
      return null;
    }
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
    required double oldCount,
    required DateTime date,
    required String duration,
    required double from,
    required double to,
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
                'completedCount': currentCompleted + diff.round(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
      });

      // البناء المحلي للتسجيل المُعدّل — للعرض المتفائل الفوري
      final updated = LessonRecording(
        id: recording.id,
        lessonId: recording.lessonId,
        teacherId: recording.teacherId,
        pathwayId: recording.pathwayId,
        weekday: weekdayOf(date),
        date: date,
        duration: duration.trim(),
        from: from,
        to: to,
        count: newCount,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        presentCount: presentStudentIds.length,
        totalStudents: totalStudents,
        createdAt: recording.createdAt,
      );
      return LessonOpResult.okWithRecording(updated);
    } catch (e) {
      debugPrint('LessonsService.updateRecording error: $e');
      return const LessonOpResult.fail('فشل تعديل التسجيل، حاول مرة أخرى');
    }
  }
}
