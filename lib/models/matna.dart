import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج المتن (مقرر حفظ داخل مسار)
class Matna {
  final String id;
  final String teacherId;
  final String pathwayId;
  final String name;
  final String type; // 'nazm' (نظم - أبيات) | 'nathr' (نثر - صفحات)
  final int totalCount;
  final DateTime? createdAt;

  const Matna({
    required this.id,
    required this.teacherId,
    required this.pathwayId,
    required this.name,
    required this.type,
    required this.totalCount,
    this.createdAt,
  });

  bool get isNazm => type == 'nazm';
  String get unitLabel => isNazm ? 'بيت' : 'صفحة';
  String get typeLabel => isNazm ? 'نظم' : 'نثر';

  factory Matna.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Matna(
      id: doc.id,
      teacherId: (data['teacherId'] as String?) ?? '',
      pathwayId: (data['pathwayId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'nathr',
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'pathwayId': pathwayId,
      'name': name.trim(),
      'type': type,
      'totalCount': totalCount,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

/// تسجيل حفظ يومي لطالب في متن
class MutunRecording {
  final String id;
  final String teacherId;
  final String pathwayId;
  final String matnaId;
  final String studentId;
  final String weekday;
  final DateTime date;
  final double from;
  final double to;
  final double count; // to - from + 1
  final String? notes;
  final DateTime? createdAt;
  final String status; // 'present' | 'absent' | 'not_listened' — null/غير موجود = حاضر (توافق القديم)

  const MutunRecording({
    required this.id,
    required this.teacherId,
    required this.pathwayId,
    required this.matnaId,
    required this.studentId,
    required this.weekday,
    required this.date,
    required this.from,
    required this.to,
    required this.count,
    this.notes,
    this.createdAt,
    this.status = 'present',
  });

  bool get isAbsent => status == 'absent';
  bool get isNotListened => status == 'not_listened';
  bool get wasPresent => !isAbsent && !isNotListened;
  String get statusLabel => switch (status) {
        'absent' => 'غائب',
        'not_listened' => 'لم يسمع',
        _ => 'حاضر',
      };

  factory MutunRecording.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MutunRecording(
      id: doc.id,
      teacherId: (data['teacherId'] as String?) ?? '',
      pathwayId: (data['pathwayId'] as String?) ?? '',
      matnaId: (data['matnaId'] as String?) ?? '',
      studentId: (data['studentId'] as String?) ?? '',
      weekday: (data['weekday'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      from: (data['from'] as num?)?.toDouble() ?? 0,
      to: (data['to'] as num?)?.toDouble() ?? 0,
      count: (data['count'] as num?)?.toDouble() ?? 0,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: (data['status'] as String?) ?? 'present',
    );
  }
}
