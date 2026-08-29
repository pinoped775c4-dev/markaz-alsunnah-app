import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/students_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';
import '../account/account_screen.dart';
import 'pathway_detail_screen.dart';

/// لوحة المعلم: شعار بالأعلى + اسم الشيخ + صورة شخصية + زر إعدادات
/// + 4 أيقونات دائرية للمستويات (بدون البطاقة الذهبية)
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
        child: StreamBuilder<Map<String, int>>(
          stream: service.watchStudentCounts(user.uid),
          builder: (context, snapshot) {
            final counts = snapshot.data ?? {};

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
                                    todayText,
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

                  // ===== شعار المركز في الأعلى =====
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: CircularLogo(size: 108)),
                    ),
                  ),

                  // ===== اسم المركز =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 12, 24, 0),
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
                      padding:
                          const EdgeInsets.fromLTRB(16, 22, 16, 0),
                      child: SectionHeader(
                        title: 'المستويات التعليمية',
                        subtitle:
                            'اختر مستواك لإدارة طلابك ودروسك',
                      ),
                    ),
                  ),

                  // ===== أيقونات المستويات: 4 أيقونات في صف واحد =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(8, 6, 8, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final pathway in circlePathways)
                            _CircularPathwayItem(
                              pathway: pathway,
                              studentCount: counts[pathway.id] ?? 0,
                              onTap: () =>
                                  _openPathway(context, pathway),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 28)),
                ],
              ),
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

// ==================== عنصر المسار الدائري بالصورة ====================

class _CircularPathwayItem extends StatelessWidget {
  final PathwayInfo pathway;
  final int studentCount;
  final VoidCallback onTap;

  const _CircularPathwayItem({
    required this.pathway,
    required this.studentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageAsset = AppConstants.pathwayImageAsset(pathway.id);
    final isQuran = pathway.id == 'quran';
    final accent = isQuran ? AppColors.gold : AppColors.primary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              // الدائرة بالصورة المدموجة
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isQuran
                        ? AppColors.gold
                        : AppColors.goldSoft,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageAsset != null
                      ? Image.asset(
                          imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _fallbackIcon(isQuran),
                        )
                      : _fallbackIcon(isQuran),
                ),
              ),
              const SizedBox(height: 10),

              // اسم المستوى
              Text(
                pathway.name,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall
                    ?.copyWith(fontSize: 12.5, height: 1.25),
              ),
              const SizedBox(height: 4),

              // عدد الطلاب (بصيغة الجمع الصحيحة)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: studentCount > 0
                      ? (isQuran
                          ? AppColors.goldSurface
                          : AppColors.primarySurface)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  studentsCountLabel(studentCount),
                  style: TextStyle(
                    color: studentCount > 0
                        ? (isQuran
                            ? AppColors.goldDark
                            : AppColors.primaryDark)
                        : AppColors.inkMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(bool isQuran) {
    return Container(
      color: isQuran ? AppColors.goldSurface : AppColors.primarySurface,
      child: Icon(
        isQuran ? Icons.menu_book_rounded : Icons.school_rounded,
        color: isQuran ? AppColors.goldDark : AppColors.primary,
        size: 32,
      ),
    );
  }
}
