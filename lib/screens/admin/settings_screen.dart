import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/mutun_wird_service.dart';
import '../../services/settings_service.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';
import '../admin/teachers_screen.dart' show DesignateWirdTeacherDialogPublic;

// ==========================================
// شاشة الإعدادات الرئيسية للإدارة
// ==========================================
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final textTheme = Theme.of(context).textTheme;
    final isDark = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: CircularLogo(size: 38),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── قسم معلم المتون والأوراد ──────────────────────────
          _SectionTitle(
            icon: Icons.auto_stories_rounded,
            title: 'معلم المتون والأوراد',
            color: AppColors.primary,
          ),
          _MutunWirdSettingTile(),
          const SizedBox(height: 20),

          // ── قسم المظهر ───────────────────────────────────────
          _SectionTitle(
            icon: Icons.palette_rounded,
            title: 'المظهر',
            color: AppColors.gold,
          ),
          _SettingsCard(
            child: Column(
              children: [
                _ToggleTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'الوضع الداكن',
                  subtitle: 'تفعيل المظهر الداكن للتطبيق',
                  value: isDark,
                  onChanged: (v) {
                    settings.setThemeMode(
                        v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── قسم اللغة ───────────────────────────────────────
          _SectionTitle(
            icon: Icons.language_rounded,
            title: 'اللغة والتنسيق',
            color: AppColors.primary,
          ),
          _SettingsCard(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.translate_rounded,
                  title: 'لغة التطبيق',
                  value: 'العربية',
                ),
                const Divider(height: 1, indent: 52),
                _InfoTile(
                  icon: Icons.calendar_today_rounded,
                  title: 'تنسيق التاريخ',
                  value: 'هجري — ميلادي',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── قسم التقارير ─────────────────────────────────────
          _SectionTitle(
            icon: Icons.assessment_rounded,
            title: 'إعدادات التقارير',
            color: AppColors.primary,
          ),
          _SettingsCard(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'تصدير التقارير',
                  value: 'PDF وWord',
                ),
                const Divider(height: 1, indent: 52),
                _InfoTile(
                  icon: Icons.water_drop_outlined,
                  title: 'العلامة المائية',
                  value: 'شعار المركز (تلقائي)',
                ),
                const Divider(height: 1, indent: 52),
                _InfoTile(
                  icon: Icons.date_range_rounded,
                  title: 'التقرير الأسبوعي',
                  value: 'السبت – الجمعة',
                ),
                const Divider(height: 1, indent: 52),
                _InfoTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'التقرير الشهري',
                  value: 'بعد نهاية الشهر',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── قسم معلومات المركز ───────────────────────────────
          _SectionTitle(
            icon: Icons.info_rounded,
            title: 'معلومات المركز',
            color: AppColors.gold,
          ),
          _SettingsCard(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.school_rounded,
                  title: 'اسم المركز',
                  value: 'مركز السنة للعلوم الشرعية وتأهيل الدعاة',
                ),
                const Divider(height: 1, indent: 52),
                _InfoTile(
                  icon: Icons.location_on_rounded,
                  title: 'الموقع',
                  value: 'شبوة - عتق',
                ),
                const Divider(height: 1, indent: 52),
                _InfoTile(
                  icon: Icons.app_settings_alt_rounded,
                  title: 'إصدار التطبيق',
                  value: '1.0.0',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── زر تسجيل الخروج ─────────────────────────────────
          _SectionTitle(
            icon: Icons.account_circle_rounded,
            title: 'الحساب',
            color: AppColors.error,
          ),
          _SettingsCard(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    size: 20, color: AppColors.error),
              ),
              title: Text(
                'تسجيل الخروج',
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'الخروج من حساب الإدارة',
                style: textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.error),
              onTap: () => confirmLogout(context),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ==========================================
// بطاقة معلم المتون والأوراد في الإعدادات
// ==========================================
class _MutunWirdSettingTile extends StatelessWidget {
  const _MutunWirdSettingTile();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wirdService = MutunWirdService();

    return StreamBuilder<MutunWirdDesignation?>(
      stream: wirdService.watchDesignation(),
      builder: (context, snapshot) {
        final designation = snapshot.data;
        final hasTeacher = designation?.teacherUid.isNotEmpty ?? false;
        final teacherName = designation?.teacherName ?? "";

        return _SettingsCard(
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasTeacher
                        ? AppColors.primarySurface
                        : AppColors.errorSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasTeacher
                        ? Icons.verified_rounded
                        : Icons.person_off_rounded,
                    size: 20,
                    color: hasTeacher ? AppColors.primary : AppColors.error,
                  ),
                ),
                title: Text(
                  hasTeacher ? teacherName : 'لم يُحدَّد معلم',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasTeacher ? AppColors.ink : AppColors.error,
                  ),
                ),
                subtitle: Text(
                  hasTeacher
                      ? 'معلم المتون والأوراد الحالي'
                      : 'يجب تعيين معلم لتفعيل التسميع الرسمي',
                  style: textTheme.bodySmall,
                ),
                trailing: TextButton.icon(
                  onPressed: () => _showDesignateDialog(context, wirdService),
                  icon: Icon(
                    hasTeacher
                        ? Icons.swap_horiz_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text(hasTeacher ? 'تغيير' : 'تعيين'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        hasTeacher ? AppColors.primary : AppColors.primary,
                    backgroundColor: AppColors.primarySurface,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
              if (hasTeacher && designation?.history != null && designation!.history.length > 1) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 16, color: AppColors.inkMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'عدد المعلمين السابقين: ${designation.history.length - 1}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDesignateDialog(
      BuildContext context, MutunWirdService wirdService) async {
    // الحصول على قائمة المعلمين من teachers_service
    final teachersService = TeachersService();
    final teachers = await teachersService.fetchActiveTeachers();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => DesignateWirdTeacherDialogPublic(
        teachers: teachers,
        wirdService: wirdService,
      ),
    );
  }
}

// ==========================================
// مكونات UI مساعدة
// ==========================================
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: child,
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      title: Text(title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: textTheme.bodySmall),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      title: Text(title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: textTheme.bodySmall),
    );
  }
}
