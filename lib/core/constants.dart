/// ثوابت التطبيق العامة
class AppConstants {
  AppConstants._();

  /// اسم المركز الرسمي
  static const String centerName = 'مركز السنة للعلوم الشرعية وتأهيل الدعاة';
  static const String centerLocation = 'شبوة - عتق';

  /// البريد الإلكتروني للمدير المؤسس (Bootstrap)
  /// يُستخدم مرة واحدة فقط لإنشاء حساب المدير الأول.
  /// ⚠️ يجب تغييره إلى البريد الفعلي للمدير قبل النشر.
  static const String bootstrapAdminEmail = 'admin@alsunnah-center.com';

  /// المسارات التعليمية الخمسة الثابتة
  static const List<PathwayInfo> pathways = [
    PathwayInfo(
      id: 'mafatih',
      name: 'مفاتيح الطلب',
      description: 'المرحلة التأسيسية لطلب العلم',
      hasLessons: true,
      hasMutun: true,
      hasQuran: true,
    ),
    PathwayInfo(
      id: 'maarij1',
      name: 'معارج التحصيل ①',
      description: 'المستوى الأول من معارج التحصيل',
      hasLessons: true,
      hasMutun: true,
      hasQuran: true,
    ),
    PathwayInfo(
      id: 'maarij2',
      name: 'معارج التحصيل ②',
      description: 'المستوى الثاني من معارج التحصيل',
      hasLessons: true,
      hasMutun: true,
      hasQuran: true,
    ),
    PathwayInfo(
      id: 'maarij3',
      name: 'معارج التحصيل ③',
      description: 'المستوى الثالث من معارج التحصيل',
      hasLessons: true,
      hasMutun: true,
      hasQuran: true,
    ),
    PathwayInfo(
      id: 'quran',
      name: 'القرآن الكريم',
      description: 'متابعة الأوراد والختمات',
      hasLessons: false,
      hasMutun: false,
      hasQuran: true,
    ),
  ];

  /// عدد صفحات المصحف (الختمة الواحدة)
  static const int khatmaPages = 604;

  /// مسار شعار المركز (يُستخدم دائرياً وكخلفية مائية)
  static const String logoAsset = 'assets/images/logo_watermark.png';

  /// نقوش إسلامية للخلفية (خفيفة وشفافة — تتكرر على كامل الشاشة)
  static const String patternAsset = 'assets/images/pattern_islamic.png';

  /// صيغة جمع كلمة "طالب" حسب العدد (قواعد الجمع العربية)
  /// 0 = لا يوجد طلاب | 1 = طالب واحد | 2 = طالبان | 3-10 = طلاب | 11+ = طالباً
  static String studentsCountText(int count) {
    if (count <= 0) return 'لا يوجد طلاب';
    if (count == 1) return 'طالب واحد';
    if (count == 2) return 'طالبان';
    if (count >= 3 && count <= 10) return '$count طلاب';
    return '$count طالباً';
  }

  /// يعيد صورة المسار من معرّفه (null لمسار القرآن)
  static String? pathwayImageAsset(String pathwayId) {
    switch (pathwayId) {
      case 'mafatih':
        return 'assets/pathways/mafatih.png';
      case 'maarij1':
        return 'assets/pathways/maarij1.png';
      case 'maarij2':
        return 'assets/pathways/maarij2.png';
      case 'maarij3':
        return 'assets/pathways/maarij3.png';
      default:
        return null;
    }
  }
}

class PathwayInfo {
  final String id;
  final String name;
  final String description;
  final bool hasLessons;
  final bool hasMutun;
  final bool hasQuran;

  const PathwayInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.hasLessons,
    required this.hasMutun,
    required this.hasQuran,
  });

  bool get isQuranOnly => id == 'quran';

  /// تبويبات المسار (القرآن = تبويب واحد فقط)
  List<String> get tabs => isQuranOnly
      ? const ['القرآن']
      : const ['الطلاب', 'الدروس', 'المتون', 'القرآن'];
}

/// تنسيق رقم عشري لعرض عربي نظيف: يُخفي ".0" إذا كان العدد صحيحاً
String fmtNum(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  // نقتطع لأقرب 4 خانات عشرية لإزالة ضجيج الفواصل العائمة
  final r = double.parse(v.toStringAsFixed(4));
  return r == r.roundToDouble() ? r.round().toString() : r.toString();
}
