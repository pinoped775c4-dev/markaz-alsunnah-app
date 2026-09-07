// إعدادات Firebase — قيم أندرويد مأخوذة من google-services.json (المشروع: calculator-7ae7b38d)
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
    apiKey: 'AIzaSyCG-rrCc_EfZatMDQNXUj9vDbnNNqu4F6Y',
    appId: '1:79484274758:web:2febb5f5569430f0012247',
    messagingSenderId: '79484274758',
    projectId: 'calculator-7ae7b38d',
    authDomain: 'calculator-7ae7b38d.firebaseapp.com',
    storageBucket: 'calculator-7ae7b38d.firebasestorage.app',
  );

  // ================= إعدادات أندرويد =================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDj3xXojV3Om2yw1mdMfgP8SONP4s9MqHk',
    appId: '1:79484274758:android:5d0e59bc21ac3a1a012247',
    messagingSenderId: '79484274758',
    projectId: 'calculator-7ae7b38d',
    storageBucket: 'calculator-7ae7b38d.firebasestorage.app',
  );

  // ================= إعدادات iOS =================
  // TODO: سجّل تطبيق iOS في Firebase Console وأضف القيم هنا
  // Firebase Console → Project Settings → Add app → iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'iOS_API_KEY_HERE',
    appId: 'iOS_APP_ID_HERE',
    messagingSenderId: '79484274758',
    projectId: 'calculator-7ae7b38d',
    storageBucket: 'calculator-7ae7b38d.firebasestorage.app',
    iosBundleId: 'com.markaz.alsunnah',
  );

  // ================= إعدادات macOS =================
  // TODO: سجّل تطبيق macOS في Firebase Console وأضف القيم هنا
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'macOS_API_KEY_HERE',
    appId: 'macOS_APP_ID_HERE',
    messagingSenderId: '79484274758',
    projectId: 'calculator-7ae7b38d',
    storageBucket: 'calculator-7ae7b38d.firebasestorage.app',
    iosBundleId: 'com.markaz.alsunnah',
  );
}
