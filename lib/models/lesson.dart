import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج الدرس (الإعداد الأولي لكل مسار)
class Lesson {
  final String id;
  final String teacherId;
  final String pathwayId;
  final String name;
  final String type; // 'nazm' (نظم - أبيات) | 'nathr' (نثر - صفحات)
  final int totalCount;
  final int completedCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lesson({
    required this.id,
    required this.teacherId,
    required this.pathwayId,
    required this.name,
    required this.type,
    required this.totalCount,
    this.completedCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isNazm => type == 'nazm';
  String get unitLabel => isNazm ? 'بيت' : 'صفحة';
  String get typeLabel => isNazm ? 'نظم' : 'نثر';

  int get remainingCount =>
      (totalCount - completedCount).clamp(0, totalCount);
  double get progress =>
      totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0;
  int get progressPercent => (progress * 100).round();

  factory Lesson.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lesson(
      id: doc.id,
      teacherId: (data['teacherId'] as String?) ?? '',
      pathwayId: (data['pathwayId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'nathr',
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      completedCount: (data['completedCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'pathwayId': pathwayId,
      'name': name,
      'type': type,
      'totalCount': totalCount,
      'completedCount': completedCount,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// نموذج تسجيل درس يومي
class LessonRecording {
  final String id;
  final String lessonId;
  final String teacherId;
  final String pathwayId;
  final String weekday; // يُحسب تلقائياً من التاريخ
  final DateTime date;
  final String duration; // نص حر يكتبه المعلم
  final int from;
  final int to;
  final int count; // to - from + 1
  final String? notes;
  final int presentCount;
  final int totalStudents;
  final DateTime? createdAt;

  const LessonRecording({
    required this.id,
    required this.lessonId,
    required this.teacherId,
    required this.pathwayId,
    required this.weekday,
    required this.date,
    required this.duration,
    required this.from,
    required this.to,
    required this.count,
    this.notes,
    this.presentCount = 0,
    this.totalStudents = 0,
    this.createdAt,
  });

  factory LessonRecording.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LessonRecording(
      id: doc.id,
      lessonId: (data['lessonId'] as String?) ?? '',
      teacherId: (data['teacherId'] as String?) ?? '',
      pathwayId: (data['pathwayId'] as String?) ?? '',
      weekday: (data['weekday'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: (data['duration'] as String?) ?? '',
      from: (data['from'] as num?)?.toInt() ?? 0,
      to: (data['to'] as num?)?.toInt() ?? 0,
      count: (data['count'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String?,
      presentCount: (data['presentCount'] as num?)?.toInt() ?? 0,
      totalStudents: (data['totalStudents'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lessonId': lessonId,
      'teacherId': teacherId,
      'pathwayId': pathwayId,
      'weekday': weekday,
      'date': Timestamp.fromDate(date),
      'duration': duration,
      'from': from,
      'to': to,
      'count': count,
      'notes': notes,
      'presentCount': presentCount,
      'totalStudents': totalStudents,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
