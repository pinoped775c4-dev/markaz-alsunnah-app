# تقرير الإصلاحات الأمنية والتقنية

## ملخص التعديلات

| # | المشكلة | الحالة | الملفات المتأثرة |
|---|---------|--------|-------------------|
| 1 | مفاتيح Firebase مكشوفة | ✅ مُصلح | `.gitignore`, `firebase_options.dart` |
| 2 | كلمات مرور Plaintext | ✅ مُصلح | `auth_service.dart`, `teachers_service.dart`, `pubspec.yaml` |
| 3 | قواعد Firestore ضعيفة | ✅ مُصلح | `firestore.rules` |
| 4 | مفتاح API في ملف الاختبار | ✅ مُصلح | `test_mutun_wird.py` |
| 5 | استعلامات غير فعّالة | ✅ مُصلح | `reports_service.dart` |
| 6 | لا auth state listener | ✅ مُصلح | `auth_service.dart`, `main.dart` |
| 7 | إعدادات Firebase ناقصة (iOS/macOS) | ✅ مُصلح | `firebase_options.dart`, `main.dart` |
| 8 | لا اختبارات | ✅ مُصلح | `test/models/` (ملفات جديدة) |
| 9 | ملف .bak ملتزم | ✅ مُصلح | `build.gradle.kts.bak` محذوف |
| 10 | README افتراضي | ✅ مُصلح | `README.md` |
| 11 | Project ID في شاشة UI | ✅ مُصلح | `main.dart` |

---

## 1. 🔒 الأمان: منع تسرب المفاتيح الحساسة

### ما تغيّر:
- **`.gitignore`**: أضفنا `google-services.json` و `.env` و `.env.*` و `*.bak`
- **`firebase_options.dart`**: أضفنا تنبيه أمني واضح + دعم iOS/macOS + رسائل خطأ للمنصات غير المدعومة

### المطلوب من المطور:
- جعل المستودع **خاصاً** (Private) على GitHub
- تفعيل **Firebase App Check** لحماية إضافية

---

## 2. 🔐 تشفير كلمات المرور المؤقتة

### ما تغيّر:
- **`auth_service.dart`**: 
  - أضفنا `dart:convert` + `package:crypto`
  - كلمة المرور تُخزَّن كـ **SHA-256 hash** مع salt
  - مقارنة آمنة (constant-time) لمنع timing attacks
  - ترحيل تلقائي: عند أول دخول بكلمة قديمة (plaintext)، يتم تحويلها للـ hash تلقائياً
- **`teachers_service.dart`**: المدير يخزّن الـ hash بدلاً من النص الصريح
- **`pubspec.yaml`**: أضفنا حزمة `crypto: ^3.0.3`

### التوافق مع الإصدارات السابقة:
الكود يدعم تلقائياً:
1. الحسابات القديمة (plaintext) → تُرحَّل للـ hash عند أول دخول ناجح
2. الحسابات الجديدة → تُخزَّن مباشرة كـ hash

---

## 3. 🛡️ قواعد Firestore محكمة

### ما تغيّر (`firestore.rules`):

| المجموعة | قبل | بعد |
|----------|-----|-----|
| `students` | أي معلم يحذف/يعدل | المعلم صاحب الطلاب فقط + المدير |
| `lessons` | أي معلم يحذف/يعدل | المعلم صاحب الدرس فقط + المدير |
| `lesson_recordings` | أي معلم يحذف/يعدل | المعلم صاحب التسجيل فقط + المدير |
| `attendance` | أي معلم يحذف/يعدل | المعلم صاحب الدرس + المدير |
| `mutun` | أي معلم ينشئ رسمي | المعلم المسؤول المخصص فقط (رسمي) |
| `mutun_recordings` | أي معلم ينشئ رسمي | المعلم المسؤول المخصص فقط (رسمي) |
| `quran_recordings` | أي معلم ينشئ رسمي | المعلم المسؤول المخصص فقط (رسمي) |
| `app_settings` | أي مستخدم يقرأ | المدير + المعلم المسؤول فقط |
| `users` | منع ترقية ذاتية | منع صريح لتغيير role إلى admin |

---

## 4. ⚡ تحسين الأداء

### `reports_service.dart` — `buildStudentReport`:
**قبل:** `_firestore.collection('mutun').get()` → يجلب **كل** المتون من **كل** المعلمين

**بعد:** `_firestore.collection('mutun').where('teacherId', ...).get()` → يجلب متون معلم الطالب فقط

---

## 5. 👂 مستمع حالة المصادقة

### ما تغيّر:
- **`auth_service.dart`**: أضفنا `startAuthStateListener()` الذي يستمع لـ `FirebaseAuth.authStateChanges()`
- **`main.dart`**: يُنشئ `AuthService` مبكراً قبل `runApp` ويبدأ المراقبة

### الفائدة:
إذا انتهت صلاحية التوكن أو تم تعطيل الحساب من الخادم، التطبيق يتفاعل فوراً.

---

## 6. 📱 دعم المنصات

### `firebase_options.dart`:
- أضفنا إعدادات iOS (placeholder — يحتاج القيم من Firebase Console)
- أضفنا إعدادات macOS (placeholder)
- المنصات غير المدعومة (Linux/Windows) تُعطي رسالة خطأ واضحة بدلاً من فشل صامت

### `main.dart`:
- `try/catch` حول `DefaultFirebaseOptions.isConfigured` لمنع crash على المنصات غير المدعومة

---

## 7. 🧪 اختبارات جديدة

### ملفات جديدة:
- `test/models/constants_test.dart` — اختبار الثوابت والدوال المساعدة
- `test/models/models_test.dart` — اختبار كل نماذج البيانات (AppUser, Student, Lesson, Matna, Quran, MutunRecording)

---

## 8. 📝 توثيق

### ما تغيّر:
- **`README.md`**: توثيق كامل بالعربية (البنية، التشغيل، الأمان، الأدوار، المسارات)
- **`.env.example`**: قالب متغيرات البيئة
- **`SECURITY_FIXES.md`**: هذا الملف

---

## خطوات ما بعد الدمج

1. **انشر قواعد Firestore الجديدة:**
   ```
   Firebase Console → Firestore Database → Rules → لصق محتوى firestore.rules → Publish
   ```

2. **أضف إعدادات iOS/macOS:**
   ```
   Firebase Console → Project Settings → Add app → iOS/macOS
   انسخ القيم إلى lib/firebase_options.dart
   ```

3. **فعّل Firebase App Check:**
   ```
   Firebase Console → App Check → Enable
   ```

4. **اجعل المستودع خاصاً** على GitHub (إن لم يكن كذلك)

5. **شغّل الاختبارات:**
   ```bash
   flutter test
   ```
