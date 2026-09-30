import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/mutun_wird_service.dart';
import '../../services/students_service.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/pathway_circle_item.dart';
import '../account/account_screen.dart';
import 'pathway_detail_screen.dart';
import 'students_section_screen.dart';
import 'teachers_section_screen.dart';

/// لوحة المعلم: تحية باسم المعلم + ملخص بسيط + قائمة مسارات تعليمية.
///
/// حساب المشرف (معلم المتون والأوراد المخصص من الإدارة) يختلف:
/// يعرض بطاقتي "المعلمون" للدخول في حساب أي معلم، و"الطلاب" للمتابعة.
class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final service = StudentsService();
    final todayText =
        DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now());
    // 4 مستويات فقط (بدون مستوى القرآن المنفصل)
    final circlePathways =
        AppConstants.pathways.where((p) => p.id != 'quran').toList();

    return Scaffold(
      body: WatermarkedBackground(
        // مراقبة تعيين "معلم المتون والأوراد" — إن كان المتصل هو المخصص
        // فيُعامل كمشرف ويعرض القسمين.
        // (المعلم العادي لا يملك صلاحية قراءة الإعداد فيظهر له الخطأ
        // ويُبقى على العرض المعتاد دون أي تأثير.)
        child: StreamBuilder<MutunWirdDesignation>(
          stream: MutunWirdService().watchDesignation(),
          builder: (context, designationSnap) {
            final designation = designationSnap.data;
            final isSupervisor = designation != null &&
                designation.hasDesignatedTeacher &&
                designation.teacherUid == user.uid;

            return StreamBuilder<Map<String, int>>(
              stream: service.watchStudentCounts(user.uid),
              builder: (context, snapshot) {
                final counts = snapshot.data ?? {};
                final totalStudents =
                    counts.values.fold<int>(0, (a, b) => a + b);

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {},
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ===== الشريط العلوي: صورة الشيخ + اسمه + إعدادات =====
                      SliverToBoxAdapter(
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: Row(
                              children: [
                                ProfileAvatar(
                                  photoBase64: user.photoBase64,
                                  name: user.name,
                                  size: 48,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'الشيخ ${user.name}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontSize: 15.5),
                                      ),
                                      Text(
                                        isSupervisor
                                            ? 'مشرف المتون والأوراد • $todayText'
                                            : todayText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'الإعدادات',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.surface,
                                    side: const BorderSide(
                                        color: AppColors.lineSoft),
                                  ),
                                  icon: const Icon(
                                      Icons.settings_outlined,
                                      color: AppColors.primary,
                                      size: 21),
                                  onPressed: () =>
                                      showSettingsSheet(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ترويسة هادئة للمركز مع ملخص العدد دون خلفية متدرجة.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                          child: Builder(
                            builder: (context) {
                              final theme = Theme.of(context);
                              final scheme = theme.colorScheme;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const CircularLogo(
                                      size: 64,
                                      elevated: false,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppConstants.centerName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontSize: 13,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            AppConstants.centerLocation,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: scheme.brightness ==
                                                      Brightness.dark
                                                  ? AppColors.goldSoft
                                                  : AppColors.goldDark,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 112,
                                        ),
                                        child: Text(
                                          studentsCountLabel(totalStudents),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // ====== حساب المشرف: قسمان (المعلمون + الطلاب) ======
                      if (isSupervisor) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 22, 16, 0),
                            child: SectionHeader(
                              title: 'الأقسام',
                              subtitle:
                                  'ادخل في حساب أي معلم، أو تابع طلاب المستويات',
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 6, 16, 4),
                            child: SectionItemList(
                              items: [
                                CircleSectionItem(
                                  imageAsset: AppConstants.teachersSectionAsset,
                                  label: 'المعلمون',
                                  badge: const _TeachersCountBadge(),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const TeachersSectionScreen(),
                                    ),
                                  ),
                                ),
                                CircleSectionItem(
                                  imageAsset: AppConstants.studentsSectionAsset,
                                  label: 'الطلاب',
                                  badge: CountBadge(
                                    text: studentsCountLabel(totalStudents),
                                    active: totalStudents > 0,
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const StudentsSectionScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // ====== حساب المعلم المعتاد: 4 مستويات ======
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 22, 16, 0),
                            child: SectionHeader(
                              title: 'المستويات التعليمية',
                              subtitle: 'اختر مستواك لإدارة طلابك ودروسك',
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 6, 16, 4),
                            child: SectionItemList(
                              items: [
                                for (final pathway in circlePathways)
                                  CircleSectionItem(
                                    imageAsset: AppConstants
                                        .pathwayImageAsset(pathway.id),
                                    label: pathway.name,
                                    isGold: pathway.id == 'quran',
                                    fallbackIcon: pathway.id == 'quran'
                                        ? Icons.menu_book_rounded
                                        : Icons.school_rounded,
                                    badge: CountBadge(
                                      text: studentsCountLabel(
                                        counts[pathway.id] ?? 0,
                                      ),
                                      active: (counts[pathway.id] ?? 0) > 0,
                                      gold: pathway.id == 'quran',
                                    ),
                                    onTap: () =>
                                        _openPathway(context, pathway),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SliverToBoxAdapter(
                          child: SizedBox(height: 28)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openPathway(BuildContext context, PathwayInfo pathway) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PathwayDetailScreen(pathway: pathway),
      ),
    );
  }
}

/// شارة عدد المعلمين — بث مباشر من قاعدة البيانات (لكل المعلمين المسجلين)
class _TeachersCountBadge extends StatelessWidget {
  const _TeachersCountBadge();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: TeachersService().watchTeachers(),
      builder: (context, snapshot) {
        final hasData = snapshot.hasData;
        final count = snapshot.data?.length ?? 0;
        return CountBadge(
          text: hasData ? AppConstants.teachersCountText(count) : '...',
          active: hasData && count > 0,
        );
      },
    );
  }
}
