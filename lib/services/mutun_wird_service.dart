import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// نتيجة عملية على إعداد "معلم المتون والأوراد"
class MutunWirdOpResult {
  final bool success;
  final String? errorMessage;

  const MutunWirdOpResult.ok() : success = true, errorMessage = null;
  const MutunWirdOpResult.fail(this.errorMessage) : success = false;
}

/// إدخال تاريخي لتعيين سابق (فترة مغلقة) — لا يُحذف أبداً
class MutunWirdHistoryEntry {
  final String teacherUid;
  final String teacherName;
  final DateTime? from; // بداية التعيين
  final DateTime? to; // نهاية التعيين

  const MutunWirdHistoryEntry({
    required this.teacherUid,
    required this.teacherName,
    this.from,
    this.to,
  });

  factory MutunWirdHistoryEntry.fromMap(Map<String, dynamic> map) {
    return MutunWirdHistoryEntry(
      teacherUid: (map['teacherUid'] as String?) ?? '',
      teacherName: (map['teacherName'] as String?) ?? '',
      from: (map['from'] as Timestamp?)?.toDate(),
      to: (map['to'] as Timestamp?)?.toDate(),
    );
  }
}

/// التعيين الحالي لمعلم المتون والأوراد (المسؤول عن السجلات الرسمية)
class MutunWirdDesignation {
  final String teacherUid; // '' عند عدم التعيين
  final String teacherName;
  final DateTime? designatedAt; // بداية التعيين الحالي
  final DateTime? updatedAt;
  final String updatedBy; // UID المدير الذي عدّل الإعداد آخر مرة
  final List<MutunWirdHistoryEntry> history; // التعيينات السابقة (مغلقة)

  const MutunWirdDesignation({
    this.teacherUid = '',
    this.teacherName = '',
    this.designatedAt,
    this.updatedAt,
    this.updatedBy = '',
    this.history = const [],
  });

  bool get hasDesignatedTeacher => teacherUid.isNotEmpty;

  factory MutunWirdDesignation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return const MutunWirdDesignation();
    final rawHistory = (data['history'] as List?) ?? const [];
    final history = <MutunWirdHistoryEntry>[];
    for (final entry in rawHistory) {
      if (entry is Map) {
        history.add(
          MutunWirdHistoryEntry.fromMap(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return MutunWirdDesignation(
      teacherUid: (data['teacherUid'] as String?) ?? '',
      teacherName: (data['teacherName'] as String?) ?? '',
      designatedAt: (data['designatedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: (data['updatedBy'] as String?) ?? '',
      history: history,
    );
  }
}

/// خدمة إعداد "معلم المتون والأوراد" — الإعداد الذي تحدده الإدارة
/// لاختيار المعلم الوحيد المسؤول عن السجلات الرسمية:
/// إضافة المتون الرسمية، تسجيل تسميع الطلاب، تسجيل تقدمهم في المتون،
/// وتسجيل الأوراد القرآنية الرسمية التي تظهر في تقارير الإدارة.
///
/// التخزين: وثيقة Firestore `app_settings/mutun_wird` بالحقول:
/// {teacherUid, teacherName, designatedAt, updatedAt, updatedBy,
///  history: [{teacherUid, teacherName, from, to}]}
///
/// قاعدة صارمة: **لا حذف لأي بيانات إطلاقاً** — تغيير المعلم المسؤول
/// يُحدّث الوثيقة ويُلحق التعيين السابق بسجل التاريخ فقط،
/// والسجلات الرسمية القديمة (المختومة بعلامة isOfficial وقت إنشائها)
/// تبقى رسمية بلا نقل أو حذف.
class MutunWirdService {
  static const String settingsCollection = 'app_settings';
  static const String settingsDocId = 'mutun_wird';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection(settingsCollection).doc(settingsDocId);

  // ================= القراءة =================

  /// بث التعيين الحالي — يعمل حتى لو وثيقة الإعداد غير موجودة بعد
  /// (يُعاد تعيين فارغ: hasDesignatedTeacher == false).
  Stream<MutunWirdDesignation> watchDesignation() {
    // جلب يدوي أولي لتعبئة الكاش قبل أول snapshot (نمط الإحماء المعتمد)
    _docRef.get().then(
      (_) {},
      onError: (Object e) {
        debugPrint('MutunWirdService.watchDesignation warm-up error: $e');
      },
    );

    return _docRef.snapshots().map((doc) => MutunWirdDesignation.fromDoc(doc));
  }

  /// UID المعلم المسؤول حالياً — null إذا لم يُعيَّن أحد بعد.
  Future<String?> getDesignatedTeacherUid() async {
    try {
      final doc = await _docRef.get();
      if (!doc.exists) return null;
      final uid = (doc.data()?['teacherUid'] as String?) ?? '';
      return uid.isEmpty ? null : uid;
    } catch (e) {
      debugPrint('MutunWirdService.getDesignatedTeacherUid error: $e');
      return null;
    }
  }

  /// هل [teacherId] هو المعلم المسؤول المخصص؟
  Future<bool> isDesignated(String teacherId) async {
    final uid = await getDesignatedTeacherUid();
    return uid != null && uid == teacherId;
  }

  // ================= الكتابة (للإدارة فقط) =================

  /// تعيين/تغيير المعلم المسؤول — للإدارة فقط.
  ///
  /// تغيير التعيين لا ينقل أو يحذف أي سجلات: السجلات الرسمية للمعلم
  /// السابق تبقى رسمية (ختم isOfficial لا يتغير)، والمعلم الجديد يتحمل
  /// السجلات الجديدة من لحظة تعيينه.
  Future<MutunWirdOpResult> setDesignatedTeacher({
    required String teacherUid,
    required String teacherName,
    required String adminUid,
  }) async {
    final newUid = teacherUid.trim();
    if (newUid.isEmpty) {
      return const MutunWirdOpResult.fail('اختر معلماً لتعيينه أولاً.');
    }

    try {
      // التحقق أن المتصل مدير فعلاً (حماية في الخدمة لا في الواجهة فقط)
      if (!await _isCallerAdmin(adminUid)) {
        return const MutunWirdOpResult.fail(
          'تعيين معلم المتون والأوراد متاح للإدارة فقط.',
        );
      }

      final now = DateTime.now();
      final doc = await _docRef.get();
      final data = doc.exists
          ? (doc.data() ?? <String, dynamic>{})
          : <String, dynamic>{};
      final previousUid = (data['teacherUid'] as String?) ?? '';

      final fields = <String, dynamic>{
        'teacherUid': newUid,
        'teacherName': teacherName.trim(),
        'designatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
      };

      // إغلاق تعيين المعلم السابق بإلحاقه بسجل التاريخ — لا حذف إطلاقاً
      if (previousUid.isNotEmpty && previousUid != newUid) {
        final closedEntry = <String, dynamic>{
          'teacherUid': previousUid,
          'teacherName': (data['teacherName'] as String?) ?? '',
          'from': data['designatedAt'],
          'to': Timestamp.fromDate(now),
        };
        fields['history'] = FieldValue.arrayUnion([closedEntry]);
      }

      await _docRef.set(fields, SetOptions(merge: true));
      return const MutunWirdOpResult.ok();
    } catch (e) {
      debugPrint('MutunWirdService.setDesignatedTeacher error: $e');
      return const MutunWirdOpResult.fail(
        'تعذّر حفظ التعيين. تحقق من الاتصال وحاول مجدداً.',
      );
    }
  }

  /// يُستدعى قبل حذف حساب معلم: إذا كان المحذوف هو المعلم المسؤول
  /// يُغلق تعيينه (يُلحق بالتاريخ) ويُفرَّغ التعيين الحالي —
  /// السجلات الرسمية المنشأة سابقاً تبقى رسمية (مختومة بعلامة isOfficial).
  Future<void> closeDesignationForDeletedTeacher(
    String deletedTeacherUid,
  ) async {
    try {
      final doc = await _docRef.get();
      if (!doc.exists) return;
      final data = doc.data() ?? <String, dynamic>{};
      final currentUid = (data['teacherUid'] as String?) ?? '';
      if (currentUid != deletedTeacherUid) return; // ليس المعلم المسؤول

      final closedEntry = <String, dynamic>{
        'teacherUid': currentUid,
        'teacherName': (data['teacherName'] as String?) ?? '',
        'from': data['designatedAt'],
        'to': Timestamp.fromDate(DateTime.now()),
      };

      await _docRef.update({
        'teacherUid': '',
        'teacherName': '',
        'designatedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([closedEntry]),
      });
    } catch (e) {
      debugPrint(
        'MutunWirdService.closeDesignationForDeletedTeacher error: $e',
      );
    }
  }

  // ================= فحوصات الصلاحية المشتركة =================

  /// تحقق صلاحية إنشاء سجل رسمي (متن/تسجيل تسميع/تقدم/ورد قرآني):
  /// (أ) [teacherId] يجب أن يكون UID المعلم المسؤول المخصص من الإدارة،
  /// (ب) [teacherId] يجب أن يكون UID المستخدم الحالي المسجَّل
  ///     (منع انتحال هوية معلم آخر).
  Future<bool> canCreateOfficial(String teacherId) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || currentUid.isEmpty) return false;
      if (teacherId != currentUid) return false; // منع انتحال الهوية

      final designatedUid = await getDesignatedTeacherUid();
      return designatedUid != null && designatedUid == teacherId;
    } catch (e) {
      debugPrint('MutunWirdService.canCreateOfficial error: $e');
      return false;
    }
  }

  /// صلاحية حذف سجل قائم (متن/تسجيل حفظ/ورد قرآني):
  /// - السجل الرسمي (isOfficial == true): معلم المتون والأوراد الحالي فقط.
  /// - السجل غير الرسمي (قديم/خاص): المعلم المسؤول أو صاحب السجل نفسه.
  Future<bool> canDeleteRecord({
    required bool isOfficial,
    required String recordTeacherId,
  }) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || currentUid.isEmpty) return false;

      final designatedUid = await getDesignatedTeacherUid();
      final isDesignated = designatedUid != null && designatedUid == currentUid;

      if (isOfficial) return isDesignated; // الرسمي: المسؤول فقط
      return isDesignated || currentUid == recordTeacherId; // أو صاحب السجل
    } catch (e) {
      debugPrint('MutunWirdService.canDeleteRecord error: $e');
      return false;
    }
  }

  /// هل المتصل الحالي مدير؟ (فحص وثيقة users/uid + مطابقة المستخدم المسجَّل)
  Future<bool> _isCallerAdmin(String claimedAdminUid) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      // UID المدير الممرر يجب أن يطابق المستخدم المسجَّل فعلاً
      if (currentUid == null ||
          currentUid.isEmpty ||
          currentUid != claimedAdminUid) {
        return false;
      }
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUid)
          .get();
      if (!userDoc.exists) return false;
      return (userDoc.data()?['role'] as String?) == 'admin';
    } catch (e) {
      debugPrint('MutunWirdService._isCallerAdmin error: $e');
      return false;
    }
  }
}
