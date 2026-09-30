import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/students_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/pathway_circle_item.dart';
import 'pathway_detail_screen.dart';

/// قسم "الطلاب" في حساب المشرف:
/// متابعة المستويات التعليمية ببطاقات شبكية؛ النقر يفتح تفاصيل المستوى.
class StudentsSectionScreen extends StatelessWidget {
  const StudentsSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final service = StudentsService();
    // 4 مستويات فقط (بنفس منطق الصفحة الرئيسية)
    final circlePathways =
        AppConstants.pathways.where((p) => p.id != 'quran').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب')),
      body: WatermarkedBackground(
        opacity: 0.04,
        child: StreamBuilder<Map<String, int>>(
          stream: service.watchStudentCounts(user?.uid),
          builder: (context, snapshot) {
            final counts = snapshot.data ?? {};

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {},
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  // شعار المركز
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(child: CircularLogo(size: 96)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    child: Text(
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
                  ),
                  Text(
                    AppConstants.centerLocation,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.goldDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 18),

                  // عنوان القسم
                  SectionHeader(
                    title: 'المستويات التعليمية',
                    subtitle: 'اختر مستوى لمتابعة طلابه ودروسه',
                  ),

                  // بطاقات المستويات — عمودان على الهاتف وثلاثة على الشاشة العريضة.
                  SectionItemGrid(
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PathwayDetailScreen(
                                pathway: pathway,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
