import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/app_user.dart';

/// نتيجة عملية المصادقة
class AuthResult {
  final AppUser? user;
  final String? errorMessage;

  const AuthResult.success(this.user) : errorMessage = null;
  const AuthResult.failure(this.errorMessage) : user = null;

  bool get isSuccess => user != null;
}

/// خدمة المصادقة وإدارة الجلسات
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  bool _isInitialized = false;
  StreamSubscription<User?>? _authStateSubscription;

  AppUser? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _currentUser != null;

  /// بدء الاستماع لتغييرات حالة المصادقة
  /// يُستدعى من main() بعد تهيئة Firebase.
  /// إذا تغيّرت حالة المستخدم (انتهاء توكن، تعطيل حساب)،
  /// يتم تحديث الحالة تلقائياً وتسجيل الخروج إن لزم.
  void startAuthStateListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null && _currentUser != null) {
        // المستخدم تم تسجيل خروجه أو تعطيل حسابه
        debugPrint('Auth state changed: user signed out or disabled');
        _currentUser = null;
        notifyListeners();
      } else if (user != null && _currentUser != null && user.uid != _currentUser!.uid) {
        // المستخدم تغيّر (حدث نادر)
        debugPrint('Auth state changed: user uid mismatch, re-fetching profile');
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  /// فحص الجلسة الحالية عند بدء التطبيق (يُستدعى من شاشة البداية)
  Future<void> checkExistingSession() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _isInitialized = true;
        notifyListeners();
        return;
      }

      final profile = await _fetchProfile(firebaseUser.uid);
      if (profile == null) {
        // لا يوجد ملف شخصي — تسجيل خروج
        await _auth.signOut();
        _isInitialized = true;
        notifyListeners();
        return;
      }

      if (!profile.isActive) {
        await _auth.signOut();
        _isInitialized = true;
        notifyListeners();
        return;
      }

      _currentUser = profile;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService.checkExistingSession error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// تسجيل الدخول بالبريد وكلمة المرور
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        return const AuthResult.failure('حدث خطأ غير متوقع، حاول مرة أخرى');
      }

      // جلب الملف الشخصي من Firestore
      var profile = await _fetchProfile(uid);

      // Bootstrap: إنشاء حساب المدير الأول لمرة واحدة فقط
      if (profile == null &&
          email.trim().toLowerCase() ==
              AppConstants.bootstrapAdminEmail.toLowerCase()) {
        profile = await _bootstrapAdmin(uid, email.trim());
      }

      if (profile == null) {
        await _auth.signOut();
        return const AuthResult.failure(
          'لا يوجد حساب مرتبط بهذا البريد. الحسابات تُنشأ من قِبل الإدارة فقط.',
        );
      }

      if (!profile.isActive) {
        await _auth.signOut();
        return const AuthResult.failure(
          'هذا الحساب معطّل. تواصل مع إدارة المركز لتفعيله.',
        );
      }

      _currentUser = profile;
      notifyListeners();
      return AuthResult.success(profile);
    } on FirebaseAuthException catch (e) {
      // سلسلة الدخول البديلة: كلمة مرور مؤقتة وضعها المدير
      // (تُخزن في ملف users لأن كلمة مرور Firebase Auth لا تعدَّل
      // إلا من صاحبها). نطابقها هنا ونبني جلسة من ملف Firestore.
      final tempResult = await _tryTempPasswordLogin(email.trim(), password);
      if (tempResult != null) return tempResult;

      return AuthResult.failure(_mapAuthError(e));
    } catch (e) {
      debugPrint('AuthService.signIn error: $e');
      return const AuthResult.failure('حدث خطأ في الاتصال، تحقق من الإنترنت وحاول مرة أخرى');
    }
  }

  /// محاولة دخول بكلمة المرور المؤقتة التي وضعها المدير.
  /// تعيد نتيجة دخول إذا طابقت، أو null إن لم تطابق (ليست كلمة مؤقتة).
  /// 
  /// 🔒 الأمان: كلمة المرور المؤقتة مخزنة كـ SHA-256 hash في Firestore،
  /// نقارن hash المدخل مع hash المخزن (لا نقارن النص الصريح أبداً).
  Future<AuthResult?> _tryTempPasswordLogin(
      String email, String password) async {
    try {
      // حساب hash لكلمة المرور المُدخلة
      final inputHash = _hashPassword(password);

      // استعلام واحد بسيط على البريد (لا فهارس مركبة)
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .get();

      // إن لم يُعثر على البريد بأي صيغة، جرّب كما كتبه المستخدم
      var docs = snapshot.docs;
      if (docs.isEmpty) {
        final snapshot2 = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .get();
        docs = snapshot2.docs;
      }

      if (docs.isEmpty) return null;

      final data = docs.first.data();
      final storedHash = data['tempPasswordHash'] as String?;
      
      // توافق مع الإصدارات القديمة: تحقق من النص الصريح (سيُحذف لاحقاً)
      final storedPlain = data['tempPassword'] as String?;
      
      bool matched = false;
      if (storedHash != null && storedHash.isNotEmpty) {
        // المقارنة الآمنة: hash مع hash
        matched = _secureCompare(storedHash, inputHash);
      } else if (storedPlain != null && storedPlain.isNotEmpty) {
        // توافق قديم: مقارنة مباشرة (قبل الترحيل)
        matched = storedPlain == password;
        // ترحيل فوري: استبدال النص الصريح بالـ hash
        if (matched) {
          await _migratePasswordToHash(docs.first.id, password);
        }
      }
      
      if (!matched) return null;

      // كلمة المرور المؤقتة صحيحة — بناء الجلسة من ملف Firestore
      final profile = AppUser(
        uid: docs.first.id,
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
      if (!profile.isActive) {
        return const AuthResult.failure(
          'هذا الحساب معطّل. تواصل مع إدارة المركز لتفعيله.',
        );
      }

      _currentUser = profile;
      notifyListeners();
      return AuthResult.success(profile);
    } catch (e) {
      debugPrint('AuthService._tryTempPasswordLogin error: $e');
      return null;
    }
  }

  /// حساب SHA-256 hash لكلمة المرور مع salt
  static String _hashPassword(String password) {
    final salt = 'markaz_alsunnah_salt_v1';
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// مقارنة آمنة لمنع timing attacks
  static bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// ترحيل كلمة المرور من النص الصريح إلى hash (تلقائي عند أول دخول ناجح)
  Future<void> _migratePasswordToHash(String uid, String plainPassword) async {
    try {
      final hash = _hashPassword(plainPassword);
      await _firestore.collection('users').doc(uid).update({
        'tempPasswordHash': hash,
        'tempPassword': FieldValue.delete(), // حذف النص الصريح
        'passwordMigratedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Password migrated to hash for user: $uid');
    } catch (e) {
      debugPrint('Password migration failed: $e');
    }
  }

  /// إنشاء حساب المدير الأول (Bootstrap لمرة واحدة)
  Future<AppUser?> _bootstrapAdmin(String uid, String email) async {
    try {
      final adminUser = AppUser(
        uid: uid,
        role: 'admin',
        name: 'مدير المركز',
        email: email,
        status: 'active',
        createdBy: uid,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(uid).set(adminUser.toMap());
      return adminUser;
    } catch (e) {
      debugPrint('AuthService._bootstrapAdmin error: $e');
      return null;
    }
  }

  /// جلب الملف الشخصي من Firestore
  Future<AppUser?> _fetchProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      debugPrint('AuthService._fetchProfile error: $e');
      return null;
    }
  }

  /// إرسال بريد إعادة تعيين كلمة المرور
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // نجاح
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'حدث خطأ في الاتصال، حاول مرة أخرى';
    }
  }

  /// تسجيل الخروج ومسح الجلسة بالكامل
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// تحديث الصورة الشخصية (تُحفظ كنص Base64 في وثيقة المستخدم)
  Future<bool> updateProfilePhoto(String? photoBase64) async {
    final user = _currentUser;
    if (user == null) return false;
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'photoBase64': photoBase64,
      });
      _currentUser = AppUser(
        uid: user.uid,
        role: user.role,
        name: user.name,
        email: user.email,
        status: user.status,
        specialization: user.specialization,
        phone: user.phone,
        photoBase64: photoBase64,
        createdBy: user.createdBy,
        createdAt: user.createdAt,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService.updateProfilePhoto error: $e');
      return false;
    }
  }

  /// ترجمة أخطاء Firebase إلى رسائل عربية واضحة
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'user-not-found':
        return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة، حاول مرة أخرى';
      case 'user-disabled':
        return 'هذا الحساب معطّل. تواصل مع إدارة المركز';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، انتظر قليلاً ثم حاول مجدداً';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت، تحقق من الشبكة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، يجب أن تكون 8 أحرف على الأقل';
      default:
        return 'حدث خطأ غير متوقع، حاول مرة أخرى';
    }
  }
}
