import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';

/// ورقة الإعدادات — تُعرض كـ BottomSheet من أي شاشة
void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settings = context.watch<SettingsService>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // مقبض السحب
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text('الإعدادات', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 18),

            // ===== الوضع الليلي / النهاري =====
            _SettingTile(
              icon: settings.isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              title: 'المظهر',
              subtitle: settings.isDark ? 'ليلي' : 'نهاري',
              trailing: Switch(
                value: settings.isDark,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => context
                    .read<SettingsService>()
                    .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ),

            // ===== اللغة =====
            _SettingTile(
              icon: Icons.language_rounded,
              title: 'اللغة',
              subtitle: settings.isArabic ? 'العربية' : 'English',
              trailing: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.lineSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LangChip(
                      label: 'عربي',
                      selected: settings.isArabic,
                      onTap: () => context
                          .read<SettingsService>()
                          .setLocale(const Locale('ar')),
                    ),
                    _LangChip(
                      label: 'EN',
                      selected: !settings.isArabic,
                      onTap: () => context
                          .read<SettingsService>()
                          .setLocale(const Locale('en')),
                    ),
                  ],
                ),
              ),
            ),

            // ===== الحساب =====
            _SettingTile(
              icon: Icons.person_rounded,
              title: 'الحساب',
              subtitle: 'البيانات الشخصية وتسجيل الخروج',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AccountScreen()),
                );
              },
              trailing: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),
        title: Text(title,
            style: textTheme.titleSmall?.copyWith(fontSize: 14)),
        subtitle: Text(subtitle, style: textTheme.bodySmall),
        trailing: trailing,
      ),
    );
  }
}

// ==================== شاشة الحساب الكاملة ====================

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    // نلتقط مرجع الخدمة قبل أي فاصل غير متزامن
    final auth = context.read<AuthService>();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        // ضغط قوي ليبقى حجم Base64 صغيراً داخل Firestore (حد 1MB)
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 55,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 700 * 1024) {
        if (mounted) {
          showErrorSnackBar(context, 'الصورة كبيرة جداً، اختر صورة أصغر');
        }
        return;
      }
      if (!mounted) return;

      setState(() => _uploading = true);
      final ok = await auth.updateProfilePhoto(base64Encode(bytes));
      if (!mounted) return;
      setState(() => _uploading = false);

      if (ok) {
        showSuccessSnackBar(context, 'تم تحديث الصورة الشخصية');
      } else {
        showErrorSnackBar(context, 'تعذّر حفظ الصورة، حاول مجدداً');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploading = false);
        showErrorSnackBar(context, 'تعذّر اختيار الصورة');
      }
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploading = true);
    final ok =
        await context.read<AuthService>().updateProfilePhoto(null);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (ok) {
      showSuccessSnackBar(context, 'تمت إزالة الصورة الشخصية');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = context.watch<AuthService>().currentUser;

    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: WatermarkedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SizedBox(height: 14),

            // ===== الصورة الشخصية =====
            Center(
              child: Stack(
                children: [
                  ProfileAvatar(
                    photoBase64: user.photoBase64,
                    name: user.name,
                    size: 110,
                  ),
                  PositionedDirectional(
                    bottom: 0,
                    end: 0,
                    child: GestureDetector(
                      onTap: _uploading ? null : _pickPhoto,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 2.5),
                        ),
                        child: _uploading
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.photo_library_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(user.name, style: textTheme.titleMedium),
            ),
            Center(
              child: Text(
                user.isAdmin ? 'مدير المركز' : 'معلم',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined,
                    size: 18),
                label: Text(user.photoBase64 == null
                    ? 'إضافة صورة من المعرض'
                    : 'تغيير الصورة'),
              ),
            ),
            if (user.photoBase64 != null)
              Center(
                child: TextButton.icon(
                  onPressed: _uploading ? null : _removePhoto,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 17, color: AppColors.error),
                  label: const Text('إزالة الصورة',
                      style: TextStyle(color: AppColors.error)),
                ),
              ),

            const SizedBox(height: 12),

            // ===== بيانات الحساب =====
            const SectionHeader(title: 'بيانات الحساب'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.lineSoft),
              ),
              child: Column(
                children: [
                  _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'الاسم',
                      value: user.name),
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'البريد الإلكتروني',
                      value: user.email,
                      ltr: true),
                  if (user.specialization != null &&
                      user.specialization!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 52),
                    _InfoRow(
                        icon: Icons.school_outlined,
                        label: 'التخصص',
                        value: user.specialization!),
                  ],
                  if (user.phone != null &&
                      user.phone!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 52),
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'الهاتف',
                        value: user.phone!,
                        ltr: true),
                  ],
                  const Divider(height: 1, indent: 52),
                  _InfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'حالة الحساب',
                    value: user.isActive ? 'نشط' : 'معطّل',
                    valueColor: user.isActive
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ===== تسجيل الخروج =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: () async {
                  await confirmLogout(context);
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ltr;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.ltr = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              textDirection: ltr ? TextDirection.ltr : null,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
