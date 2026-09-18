
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/branding.dart';
import 'lessons_tab.dart';
import 'mutun_tab.dart';
import 'quran_tab.dart';

/// شاشة تفاصيل المسار الفاخرة: 3 تبويبات (الدروس | المتون | القرآن)
/// تبويب الطلاب حُذف — الطلاب مشتركون تديرهم الإدارة فقط
class PathwayDetailScreen extends StatelessWidget {
  final PathwayInfo pathway;

  const PathwayDetailScreen({super.key, required this.pathway});

  @override
  Widget build(BuildContext context) {
    final teacherId =
        context.watch<AuthService>().currentUser?.uid ?? '';
    final isQuran = pathway.id == 'quran';
    final accent = isQuran ? AppColors.gold : AppColors.primary;
    final imageAsset = AppConstants.pathwayImageAsset(pathway.id);

    // تبويبات بأيقونات مناسبة: طلاب / كتاب مفتوح / كتب متراصة / مصحف على حامل
    Tab buildTab(IconData icon, String text) => Tab(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(fontSize: 11.5)),
            ],
          ),
        );

    final tabs = pathway.isQuranOnly
        ? [buildTab(Icons.auto_stories_rounded, 'القرآن')]
        : [
            buildTab(Icons.menu_book_rounded, 'الدروس'),
            buildTab(Icons.library_books_rounded, 'المتون'),
            buildTab(Icons.auto_stories_rounded, 'القرآن'),
          ];

    // بناء lazy: التبويب لا يُركّب (ولا يبدأ استعلاماته) إلا عند أول ظهور —
    // سابقًا كان TabBarView يبني كل التبويبات فورًا فتتزامن كل streams
    // (طلاب + دروس + متون + قرآن) ويثقل التطبيق بلا داعٍ.
    final views = pathway.isQuranOnly
        ? [
            _LazyTab(() => QuranTab(pathway: pathway, teacherId: teacherId))
          ]
        : [
            _LazyTab(
                () => LessonsTab(pathway: pathway, teacherId: teacherId)),
            _LazyTab(
                () => MutunTab(pathway: pathway, teacherId: teacherId)),
            _LazyTab(
                () => QuranTab(pathway: pathway, teacherId: teacherId)),
          ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              // أيقونة المسار: نفس صورة الصفحة الرئيسية داخل دائرة
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isQuran
                        ? AppColors.gold
                        : AppColors.goldSoft,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: imageAsset != null
                      ? Image.asset(
                          imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            isQuran
                                ? Icons.menu_book_rounded
                                : Icons.school_rounded,
                            color: accent,
                            size: 23,
                          ),
                        )
                      : Icon(
                          isQuran
                              ? Icons.menu_book_rounded
                              : Icons.school_rounded,
                          color: accent,
                          size: 23,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pathway.name,
                        style: const TextStyle(fontSize: 17)),
                    Text(
                      pathway.description,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.lineSoft)),
              ),
              child: TabBar(tabs: tabs),
            ),
          ),
        ),
        body: WatermarkedBackground(
          opacity: 0.04,
          child: TabBarView(children: views),
        ),
      ),
    );
  }
}

/// تبويب كسول: لا يُنشئ محتواه (ولا يبدأ استعلاماته) إلا عند أول بناء فعلي
/// بعد أن يفعّله المستخدم — يقلل الحمل الابتدائي لشاشة تفاصيل المسار.
class _LazyTab extends StatefulWidget {
  final Widget Function() builder;

  const _LazyTab(this.builder);

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> {
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    // نُنشئ الابن مرة واحدة فقط عند أول build حقيقي لهذا التبويب
    _child ??= KeyedSubtree(key: UniqueKey(), child: widget.builder());
    return _child!;
  }
}


