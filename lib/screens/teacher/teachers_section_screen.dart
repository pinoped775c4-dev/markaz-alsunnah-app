import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';
import 'teacher_account_screen.dart';

/// قسم "المعلمون" في حساب المشرف:
/// يعرض كل المعلمين المسجلين من قبل الإدارة، والنقر على أي معلم
/// يفتح حساب المعلم كاملاً (مستوياته: دروسه، متونه، وأوردته).
class TeachersSectionScreen extends StatelessWidget {
  const TeachersSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('المعلمون')),
      body: WatermarkedBackground(
        opacity: 0.04,
        child: StreamBuilder<List<AppUser>>(
          stream: TeachersService().watchTeachers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message:
                    'تعذّر تحميل قائمة المعلمين.\n'
                    'تحقق من الاتصال بالإنترنت ثم أعد المحاولة.',
                onRetry: () {},
              );
            }
            if (!snapshot.hasData) {
              return const ListSkeleton(itemCount: 4);
            }

            final teachers = snapshot.data!;
            if (teachers.isEmpty) {
              return const EmptyState(
                icon: Icons.groups_outlined,
                title: 'لا يوجد معلمون بعد',
                message:
                    'تُضيف الإدارة حسابات المعلمين من لوحة التحكم\n'
                    'وسوف تظهر هنا فور تسجيلها',
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {},
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: teachers.length,
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(AppRadius.lg),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeacherAccountScreen(
                              teacher: teacher,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              ProfileAvatar(
                                photoBase64: teacher.photoBase64,
                                name: teacher.name,
                                size: 46,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الشيخ ${teacher.name}',
                                      style: textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      teacher.specialization != null &&
                                              teacher.specialization!
                                                  .isNotEmpty
                                          ? teacher.specialization!
                                          : 'معلم — ${teacher.email}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          textTheme.bodySmall?.copyWith(
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // حالة الحساب
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: teacher.isActive
                                      ? AppColors.successSurface
                                      : AppColors.errorSurface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  teacher.isActive ? 'مفعّل' : 'معطّل',
                                  style: TextStyle(
                                    color: teacher.isActive
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.inkMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
