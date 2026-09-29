
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
///
/// عند فتحها من حساب المشرف (قسم المعلمين) يمرر المشرف [teacherId]
/// صاحب الحساب المعروض، فيظهر كل ما في حساب ذلك المعلم ويمكنه
/// الإضافة والتسجيل فيه بصفته المشرف.
class PathwayDetailScreen extends StatelessWidget {
  final PathwayInfo pathway;

  /// معرّف صاحب الحساب المعروض — null = حساب المستخدم الحالي (الوضع المعتاد)
  final String? teacherId;

  /// اسم المعلم المعروض (يظهر في الشريط العلوي عند عرض حساب معلم آخر)
  final String? viewingTeacherName;

  const PathwayDetailScreen({
    super.key,
    required this.pathway,
    this.teacherId,
    this.viewingTeacherName,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser;
    final currentUid = currentUser?.uid ?? '';
    final currentTeacherName = (viewingTeacherName?.trim().isNotEmpty ?? false)
        ? viewingTeacherName!.trim()
        : currentUser?.name.trim();
    final teacherId = (this.teacherId != null && this.teacherId!.isNotEmpty)
        ? this.teacherId!
        : currentUid;
    final isQuran = pathway.id == 'quran';
    final accent = isQuran ? AppColors.gold : AppColors.primary;
    final imageAsset = AppConstants.pathwayImageAsset(pathway.id);

    final tabs = pathway.isQuranOnly
        ? const [
            Tab(icon: Icon(Icons.auto_stories_rounded), text: 'القرآن'),
          ]
        : const [
            Tab(icon: Icon(Icons.menu_book_rounded), text: 'الدروس'),
            Tab(icon: Icon(Icons.library_books_rounded), text: 'المتون'),
            Tab(icon: Icon(Icons.auto_stories_rounded), text: 'القرآن'),
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
          toolbarHeight: 116,
          titleSpacing: 4,
          title: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isQuran ? AppColors.gold : AppColors.goldSoft,
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
                            size: 24,
                          ),
                        )
                      : Icon(
                          isQuran
                              ? Icons.menu_book_rounded
                              : Icons.school_rounded,
                          color: accent,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pathway.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pathway.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentTeacherName == null || currentTeacherName.isEmpty
                          ? 'تصفح حساب المعلم'
                          : 'تصفح حساب $currentTeacherName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.goldDark,
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
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.lineSoft)),
              ),
              child: TabBar(
                tabs: tabs,
                isScrollable: false,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.inkMuted,
                indicatorColor: AppColors.primaryDark,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
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


