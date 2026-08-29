import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات المستخدم (مدير أو معلم)
class AppUser {
  final String uid;
  final String role; // 'admin' | 'teacher'
  final String name;
  final String email;
  final String status; // 'active' | 'disabled'
  final String? specialization;
  final String? phone;
  final String? photoBase64;
  final String? createdBy;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.status,
    this.specialization,
    this.phone,
    this.photoBase64,
    this.createdBy,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isTeacher => role == 'teacher';
  bool get isActive => status == 'active';

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      role: (data['role'] as String?) ?? 'teacher',
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'active',
      specialization: data['specialization'] as String?,
      phone: data['phone'] as String?,
      photoBase64: data['photoBase64'] as String?,
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'name': name,
      'email': email,
      'status': status,
      'specialization': specialization,
      'phone': phone,
      'photoBase64': photoBase64,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? status,
    String? name,
    String? specialization,
    String? phone,
    String? photoBase64,
  }) {
    return AppUser(
      uid: uid,
      role: role,
      name: name ?? this.name,
      email: email,
      status: status ?? this.status,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
      photoBase64: photoBase64 ?? this.photoBase64,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
