import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

/// تسجيل ورد قرآني يومي لطالب (صفحات 1–604)
class QuranRecording {
  final String id;
  final String teacherId;
  final String pathwayId;
  final String studentId;
  final String weekday;
  final DateTime date;
  final double fromPage; // 1..604
  final double toPage; // 1..604
  final double count; // toPage - fromPage + 1
  final String? notes;
  final DateTime? createdAt;

  /// هل الورد رسمي (سجّله معلم المتون والأوراد المخصص)؟
  /// القديم بلا علامة (null) = غير رسمي — لا يدخل التقارير الرسمية.
  final bool isOfficial;

  const QuranRecording({
    required this.id,
    required this.teacherId,
    required this.pathwayId,
    required this.studentId,
    required this.weekday,
    required this.date,
    required this.fromPage,
    required this.toPage,
    required this.count,
    this.notes,
    this.createdAt,
    this.isOfficial = false,
  });

  /// هل هذا التسجيل أتمّ الختمة؟
  bool get completesKhatma => toPage >= AppConstants.khatmaPages;

  factory QuranRecording.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return QuranRecording(
      id: doc.id,
      teacherId: (data['teacherId'] as String?) ?? '',
      pathwayId: (data['pathwayId'] as String?) ?? '',
      studentId: (data['studentId'] as String?) ?? '',
      weekday: (data['weekday'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fromPage: (data['fromPage'] as num?)?.toDouble() ?? 0,
      toPage: (data['toPage'] as num?)?.toDouble() ?? 0,
      count: (data['count'] as num?)?.toDouble() ?? 0,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isOfficial: (data['isOfficial'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'pathwayId': pathwayId,
      'studentId': studentId,
      'weekday': weekday,
      'date': Timestamp.fromDate(date),
      'fromPage': fromPage,
      'toPage': toPage,
      'count': count,
      'notes': notes,
      'isOfficial': isOfficial,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// ملخص تقدم طالب في القرآن (يُحسب في الذاكرة من سجلاته)
class QuranProgressSummary {
  /// موضع القراءة الحالي (آخر صفحة وصل إليها في الختمة الحالية)
  final int currentPage;
  final int completedKhatmas;
  final int totalPagesRead;
  final int recordingsCount;
  final DateTime? lastDate;

  const QuranProgressSummary({
    required this.currentPage,
    required this.completedKhatmas,
    required this.totalPagesRead,
    required this.recordingsCount,
    this.lastDate,
  });

  static const empty = QuranProgressSummary(
    currentPage: 0,
    completedKhatmas: 0,
    totalPagesRead: 0,
    recordingsCount: 0,
  );

  double get khatmaProgress =>
      (currentPage / AppConstants.khatmaPages).clamp(0.0, 1.0);
  int get khatmaPercent => (khatmaProgress * 100).round();
  int get remainingPages => AppConstants.khatmaPages - currentPage;
}

/// تجميع سجلات طالب إلى ملخص تقدم
QuranProgressSummary summarizeQuranProgress(List<QuranRecording> recordings) {
  if (recordings.isEmpty) return QuranProgressSummary.empty;

  int currentPage = 0;
  int khatmas = 0;
  int total = 0;
  DateTime? last;

  for (final r in recordings) {
    total += r.count.round();
    if (last == null || r.date.isAfter(last)) last = r.date;
  }

  // ترتيب زمني لتتبع الختمات
  final sorted = [...recordings]..sort((a, b) => a.date.compareTo(b.date));
  for (final r in sorted) {
    if (r.fromPage <= 1 && r.toPage >= AppConstants.khatmaPages) {
      // تسجيل ختمة كاملة دفعة واحدة
      khatmas++;
      currentPage = 0;
    } else {
      if (r.toPage >= AppConstants.khatmaPages) khatmas++;
      currentPage = (r.toPage >= AppConstants.khatmaPages ? 0 : r.toPage)
          .round();
    }
  }

  return QuranProgressSummary(
    currentPage: currentPage,
    completedKhatmas: khatmas,
    totalPagesRead: total,
    recordingsCount: recordings.length,
    lastDate: last,
  );
}
