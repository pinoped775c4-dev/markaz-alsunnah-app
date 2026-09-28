import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

/// تسجيل ورد قرآني يومي لطالب. الموضع غير مهم؛ يُحفظ عدد الصفحات فقط.
class QuranRecording {
  final String id;
  final String teacherId;
  final String pathwayId;
  final String studentId;
  final String weekday;
  final DateTime date;
  final double count;
  final String? notes;
  final DateTime? createdAt;
  final bool isOfficial;

  const QuranRecording({
    required this.id,
    required this.teacherId,
    required this.pathwayId,
    required this.studentId,
    required this.weekday,
    required this.date,
    double? count,
    // Legacy constructor arguments retained for source compatibility only.
    double? fromPage,
    double? toPage,
    this.notes,
    this.createdAt,
    this.isOfficial = false,
  }) : count = count ??
           (fromPage != null && toPage != null
               ? (toPage - fromPage + 1).toDouble()
               : 0.0);

  /// Legacy reads are supported for old UI/report callers; new records have no location.
  double get fromPage => 0;
  double get toPage => count;
  bool get completesKhatma => count >= AppConstants.khatmaPages;

  factory QuranRecording.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // Old records stored only the range; migrate them in memory to page count.
    final legacyFrom = (data['fromPage'] as num?)?.toDouble();
    final legacyTo = (data['toPage'] as num?)?.toDouble();
    final storedCount = (data['count'] as num?)?.toDouble();
    final double count = storedCount ??
        (legacyFrom != null && legacyTo != null
            ? (legacyTo - legacyFrom + 1).toDouble()
            : 0.0);
    return QuranRecording(
      id: doc.id,
      teacherId: (data['teacherId'] as String?) ?? '',
      pathwayId: (data['pathwayId'] as String?) ?? '',
      studentId: (data['studentId'] as String?) ?? '',
      weekday: (data['weekday'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      count: count,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isOfficial: (data['isOfficial'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'teacherId': teacherId,
    'pathwayId': pathwayId,
    'studentId': studentId,
    'weekday': weekday,
    'date': Timestamp.fromDate(date),
    'count': count,
    'notes': notes,
    'isOfficial': isOfficial,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };
}

/// ملخص تقدم طالب في القرآن اعتماداً على مجموع الصفحات فقط.
class QuranProgressSummary {
  final int currentPage; // progress within the current 604-page cycle
  final int completedKhatmas;
  final int totalPagesRead;
  final int recordingsCount;
  final DateTime? lastDate;

  const QuranProgressSummary({required this.currentPage, required this.completedKhatmas, required this.totalPagesRead, required this.recordingsCount, this.lastDate});
  static const empty = QuranProgressSummary(currentPage: 0, completedKhatmas: 0, totalPagesRead: 0, recordingsCount: 0);
  double get khatmaProgress => (currentPage / AppConstants.khatmaPages).clamp(0.0, 1.0);
  int get khatmaPercent => (khatmaProgress * 100).round();
  int get remainingPages => AppConstants.khatmaPages - currentPage;
}

QuranProgressSummary summarizeQuranProgress(List<QuranRecording> recordings) {
  final total = recordings.fold<int>(0, (sum, r) => sum + r.count.round());
  DateTime? last;
  for (final r in recordings) {
    if (last == null || r.date.isAfter(last)) last = r.date;
  }
  return QuranProgressSummary(
    currentPage: total % AppConstants.khatmaPages,
    completedKhatmas: total ~/ AppConstants.khatmaPages,
    totalPagesRead: total,
    recordingsCount: recordings.length,
    lastDate: last,
  );
}
