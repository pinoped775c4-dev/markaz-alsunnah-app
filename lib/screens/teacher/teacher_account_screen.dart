import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/students_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/pathway_circle_item.dart';
import 'pathway_detail_screen.dart';

/// "حساب المعلم" — يفتحها المشرف من قسم "المعلمون":
/// تعرض كل ما في حساب المعلم المختار (مستوياته: دروسه، متونه، أوردته)،
/// ويتيح للمشرف إضافة الدروس والتسجيل فيها بصفته المشرف.
class TeacherAccountScreen extends StatelessWidget {
  final AppUser teacher;

  const TeacherAccountScreen({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    final service = StudentsService();
    // 4 مستويات فقط (بنفس منطق الصفحة الرئيسية)
    final circlePathways =
        AppConstants.pathways.where((p) => p.id != 'quran').toList();

    return Scaffold(
      body: WatermarkedBackground(
        child: StreamBuilder<Map<String, int>>(
          stream: service.watchStudentCounts(),
          builder: (context, snapshot) {
            final counts = snapshot.data ?? {};

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ===== الشريط العلوي: رجوع + صورة المعلم + اسمه =====
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
                      child: Row(
                        children: [
                          // زر الرجوع (مُنعكس لليمين وفق الاتجاه العربي)
                          Transform.flip(
                            flipX: true,
                            child: IconButton(
                              tooltip: 'رجوع',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                side: const BorderSide(
                                    color: AppColors.lineSoft),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ProfileAvatar(
                            photoBase64: teacher.photoBase64,
                            name: teacher.name,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الشيخ ${teacher.name}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontSize: 15.5),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.goldSurface,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.goldSoft),
                                  ),
                                  child: Text(
                                    teacher.isActive
                                        ? 'حساب المعلم — بصلاحية المشرف'
                                        : 'حساب معطّل',
                                    style: const TextStyle(
                                      color: AppColors.goldDark,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ===== شعار المركز =====
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(child: CircularLogo(size: 108)),
                  ),
                ),

                // ===== اسم المركز =====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          AppConstants.centerName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: AppColors.primaryDark,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppConstants.centerLocation,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== عنوان القسم =====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: SectionHeader(
                      title: 'المستويات التعليمية',
                      subtitle:
                          'كل ما في حساب هذا المعلم: دروسه ومتونه وأوردته',
                    ),
                  ),
                ),

                // ===== أيقونات المستويات: 4 أيقونات في صف واحد =====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  counts[pathway.id] ?? 0),
                              active: (counts[pathway.id] ?? 0) > 0,
                              gold: pathway.id == 'quran',
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PathwayDetailScreen(
                                  pathway: pathway,
                                  teacherId: teacher.uid,
                                  viewingTeacherName: teacher.name,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: 28)),
              ],
            );
          },
        ),
      ),
    );
  }
}
