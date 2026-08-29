// إعدادات Firebase — قيم أندرويد مأخوذة من google-services.json (المشروع: calculator-7ae7b38d)
//
// ⚠️ منصة الويب: يجب تسجيل تطبيق Web في Firebase Console ونسخ قيمه هنا
//    Project settings → Your apps → Add app → Web
//    https://console.firebase.google.com/project/calculator-7ae7b38d/settings/general
//    بدونها ستظهر شاشة توضيحية ودية عند تشغيل معاينة الويب فقط — أندرويد يعمل مباشرة.

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
      default:
        return android;
    }
  }

  // ================= إعدادات الويب (فعلية من Firebase Console) =================
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCG-rrCc_EfZatMDQNXUj9vDbnNNqu4F6Y',
    appId: '1:79484274758:web:2febb5f5569430f0012247',
    messagingSenderId: '79484274758',
    projectId: 'calculator-7ae7b38d',
    authDomain: 'calculator-7ae7b38d.firebaseapp.com',
    storageBucket: 'calculator-7ae7b38d.firebasestorage.app',
  );

  // ================= إعدادات أندرويد (فعلية من google-services.json) =================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDj3xXojV3Om2yw1mdMfgP8SONP4s9MqHk',
    appId: '1:79484274758:android:5d0e59bc21ac3a1a012247',
    messagingSenderId: '79484274758',
    projectId: 'calculator-7ae7b38d',
    storageBucket: 'calculator-7ae7b38d.firebasestorage.app',
  );

  /// التحقق من أن إعدادات المنصة الحالية حقيقية وليست نائبة
  static bool get isConfigured =>
      !currentPlatform.apiKey.contains('_HERE') &&
      !currentPlatform.appId.contains('_HERE');
}
