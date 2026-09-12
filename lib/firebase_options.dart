// إعدادات Firebase — المشروع: markaz-aloom
//
// ⚠️ تنبيه أمني:
// هذا الملف يحتوي على مفاتيح API. عند نشر المستودع:
// 1) اجعل المستودع خاصاً (Private) على GitHub.
// 2) أو استخدم متغيرات بيئة خارجية — انظر .env.example
// 3) أضف google-services.json إلى .gitignore (تمت إضافته).
//
// ملاحظة: مفاتيح Firebase API المصممة للعميل (client SDK) ليست
// سرّية بطبيعتها — الحماية الحقيقية في Firestore Rules و App Check.
// لكنها مع ذلك يجب ألا تُعرض في مستودع عام.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        // Linux و Windows غير مدعومة حالياً
        throw UnsupportedError(
          'المنصة الحالية ($defaultTargetPlatform) غير مدعومة. '
          'التطبيق يدعم أندرويد و iOS والويب فقط.',
        );
    }
  }

  /// التحقق من أن إعدادات المنصة الحالية حقيقية وليست نائبة
  static bool get isConfigured =>
      !currentPlatform.apiKey.contains('_HERE') &&
      !currentPlatform.appId.contains('_HERE');

  // ================= إعدادات الويب =================
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCQeoGL6kaH_KhyNHGXWY9uCKoGkGISx78',
    appId: '1:645926213470:web:2e943f6851b4c97b6161cf',
    messagingSenderId: '645926213470',
    projectId: 'markaz-aloom',
    authDomain: 'markaz-aloom.firebaseapp.com',
    storageBucket: 'markaz-aloom.firebasestorage.app',
    measurementId: 'G-57TN17MWK1',
  );

  // ================= إعدادات أندرويد =================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAsMia_Hez99yixJC6KOjJN99oN3-jKmTs',
    appId: '1:645926213470:android:69f16c2a86159c156161cf',
    messagingSenderId: '645926213470',
    projectId: 'markaz-aloom',
    storageBucket: 'markaz-aloom.firebasestorage.app',
  );

  // ================= إعدادات iOS =================
  // TODO: سجّل تطبيق iOS في Firebase Console وأضف القيم هنا
  // Firebase Console → Project Settings → Add app → iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'iOS_API_KEY_HERE',
    appId: 'iOS_APP_ID_HERE',
    messagingSenderId: '645926213470',
    projectId: 'markaz-aloom',
    storageBucket: 'markaz-aloom.firebasestorage.app',
    iosBundleId: 'com.markaz.alsunnah',
  );

  // ================= إعدادات macOS =================
  // TODO: سجّل تطبيق macOS في Firebase Console وأضف القيم هنا
  // Firebase Console → Project Settings → Add app → macOS
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'macOS_API_KEY_HERE',
    appId: 'macOS_APP_ID_HERE',
    messagingSenderId: '645926213470',
    projectId: 'markaz-aloom',
    storageBucket: 'markaz-aloom.firebasestorage.app',
    iosBundleId: 'com.markaz.alsunnah',
  );
}
