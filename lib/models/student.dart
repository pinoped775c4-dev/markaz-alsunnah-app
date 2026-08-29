import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات الطالب (لا حسابات للطلاب — يديرهم المعلم)
class Student {
  final String id;
  final String teacherId;
  final String pathwayId;
  final String pathwayName;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime? enrolledAt;
  final String status; // 'active' | 'inactive'
  final int totalQuranPages;
  final String? lastQuranWard;

  const Student({
    required this.id,
    required this.teacherId,
    required this.pathwayId,
    required this.pathwayName,
    required this.name,
    this.phone,
    this.notes,
    this.enrolledAt,
    this.status = 'active',
    this.totalQuranPages = 0,
    this.lastQuranWard,
  });

  bool get isActive => status == 'active';

  factory Student.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Student(
      id: doc.id,
      teacherId: (data['teacherId'] as String?) ?? '',
      pathwayId: (data['pathwayId'] as String?) ?? '',
      pathwayName: (data['pathwayName'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: data['phone'] as String?,
      notes: data['notes'] as String?,
      enrolledAt: (data['enrolledAt'] as Timestamp?)?.toDate(),
      status: (data['status'] as String?) ?? 'active',
      totalQuranPages: (data['totalQuranPages'] as num?)?.toInt() ?? 0,
      lastQuranWard: data['lastQuranWard'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'pathwayId': pathwayId,
      'pathwayName': pathwayName,
      'name': name,
      'phone': phone,
      'notes': notes,
      'enrolledAt': enrolledAt != null
          ? Timestamp.fromDate(enrolledAt!)
          : FieldValue.serverTimestamp(),
      'status': status,
      'totalQuranPages': totalQuranPages,
      'lastQuranWard': lastQuranWard,
    };
  }
}
