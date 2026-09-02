import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';

/// شاشة إدارة المعلمين — تصميم احترافي بجودة الإنتاج
class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  final TeachersService _service = TeachersService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filter(List<AppUser> teachers) {
    if (_searchQuery.isEmpty) return teachers;
    final q = _searchQuery.toLowerCase();
    return teachers.where((t) {
      return t.name.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q) ||
          (t.specialization?.toLowerCase().contains(q) ?? false) ||
          (t.phone?.contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إدارة المعلمين'),
            Text(
              'إضافة ومتابعة معلمي المركز',
              style:
                  TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => confirmLogout(context),
          ),
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: Center(
                child: CircularLogo(size: 42, elevated: false)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTeacherDialog(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('إضافة معلم جديد',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: WatermarkedBackground(
        child: StreamBuilder<List<AppUser>>(
          stream: _service.watchTeachers(),
          builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: 'حدث خطأ أثناء تحميل قائمة المعلمين',
              onRetry: () => setState(() {}),
            );
          }

          if (!snapshot.hasData) {
            return const ListSkeleton(itemCount: 5);
          }

          final allTeachers = snapshot.data!;
          final filtered = _filter(allTeachers);
          final activeCount = allTeachers.where((t) => t.isActive).length;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => setState(() {}),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // بطاقة الإحصائيات الموحدة
                SliverToBoxAdapter(
                  child: _StatsCard(
                    total: allTeachers.length,
                    active: activeCount,
                    disabled: allTeachers.length - activeCount,
                  ),
                ),

                // حقل البحث
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم أو البريد أو التخصص...',
                        prefixIcon:
                            const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                if (allTeachers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'لا يوجد معلمون بعد',
                      message:
                          'ابدأ بإضافة أول معلم ليتمكن من إدارة طلابه\nوتسجيل دروسه اليومية',
                      actionLabel: 'إضافة أول معلم',
                      onAction: () => _showAddTeacherDialog(context),
                    ),
                  )
                else if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'لا توجد نتائج مطابقة',
                      message: 'جرّب كلمة بحث مختلفة',
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _TeacherCard(teacher: filtered[index]),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
          },
        ),
      ),
    );
  }

  void _showAddTeacherDialog(BuildContext context) {
    final adminUid =
        context.read<AuthService>().currentUser?.uid ?? '';
    showDialog(
      context: context,
      builder: (_) =>
          _AddTeacherDialog(service: _service, adminUid: adminUid),
    );
  }
}

// ==================== بطاقة الإحصائيات ====================

class _StatsCard extends StatelessWidget {
  final int total;
  final int active;
  final int disabled;

  const _StatsCard({
    required this.total,
    required this.active,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
              value: total, label: 'الإجمالي', icon: Icons.groups_rounded),
          _divider(),
          _StatItem(
              value: active,
              label: 'نشط',
              icon: Icons.check_circle_rounded),
          _divider(),
          _StatItem(
              value: disabled, label: 'معطّل', icon: Icons.block_rounded),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 44,
        color: Colors.white.withValues(alpha: 0.25),
      );
}

class _StatItem extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;

  const _StatItem(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== بطاقة المعلم ====================

class _TeacherCard extends StatelessWidget {
  final AppUser teacher;

  const _TeacherCard({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText = teacher.createdAt != null
        ? DateFormat('d MMMM y', 'ar').format(teacher.createdAt!)
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(name: teacher.name, muted: !teacher.isActive),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          teacher.name,
                          style: textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      teacher.isActive
                          ? const StatusChip.active()
                          : const StatusChip.disabled(),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.alternate_email_rounded,
                          size: 14, color: AppColors.inkMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          teacher.email,
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (teacher.specialization != null ||
                      teacher.phone != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (teacher.specialization != null)
                          teacher.specialization!,
                        if (teacher.phone != null) teacher.phone!,
                      ].join('  •  '),
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (dateText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'انضم في $dateText',
                      style: textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.inkMuted),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              onSelected: (value) => _onAction(context, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        teacher.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_rounded,
                        size: 20,
                        color: teacher.isActive
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      Text(teacher.isActive
                          ? 'تعطيل الحساب'
                          : 'تفعيل الحساب'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_rounded,
                          size: 20, color: AppColors.primary),
                      SizedBox(width: 12),
                      Text('إعادة تعيين كلمة المرور'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded,
                          size: 20, color: AppColors.error),
                      SizedBox(width: 12),
                      Text('حذف الحساب نهائيًا',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final service = TeachersService();

    if (action == 'toggle') {
      final isActive = teacher.isActive;
      final confirmed = await showConfirmDialog(
        context,
        title: isActive ? 'تعطيل حساب المعلم' : 'تفعيل حساب المعلم',
        message: isActive
            ? 'سيتم منع "${teacher.name}" من تسجيل الدخول.\nهل أنت متأكد؟'
            : 'سيتم تفعيل حساب "${teacher.name}" والسماح له بالدخول.',
        confirmLabel: isActive ? 'تعطيل' : 'تفعيل',
        isDestructive: isActive,
      );
      if (!confirmed || !context.mounted) return;

      final result = await service.setTeacherStatus(teacher.uid, !isActive);
      if (!context.mounted) return;

      if (result.success) {
        showSuccessSnackBar(
          context,
          isActive
              ? 'تم تعطيل حساب ${teacher.name}'
              : 'تم تفعيل حساب ${teacher.name}',
        );
      } else {
        showErrorSnackBar(context, result.errorMessage!);
      }
    } else if (action == 'reset') {
      final newPassword = await showDialog<String>(
        context: context,
        builder: (_) => _ResetPasswordDialog(teacherName: teacher.name),
      );
      if (newPassword == null || newPassword.isEmpty || !context.mounted) {
        return;
      }

      final result = await service.resetTeacherPassword(
        uid: teacher.uid,
        newPassword: newPassword,
      );
      if (!context.mounted) return;

      if (result.success) {
        showSuccessSnackBar(
          context,
          'تم تعيين كلمة المرور الجديدة للمعلم "${teacher.name}".\n'
          'أبلغه بها ليتمكن من تسجيل الدخول.',
        );
      } else {
        showErrorSnackBar(context, result.errorMessage!);
      }
    } else if (action == 'delete') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'حذف حساب المعلم نهائيًا',
        message:
            'سيتم حذف حساب "${teacher.name}" وجميع بياناته نهائيًا:\n'
            'الطلاب، الدروس، التسجيلات اليومية، سجلات الحضور، المتون والقرآن.\n\n'
            '⚠️ هذا الإجراء لا يمكن التراجع عنه!',
        confirmLabel: 'حذف نهائي',
        isDestructive: true,
      );
      if (!confirmed || !context.mounted) return;

      // مؤشر تحميل أثناء الحذف (قد يستغرق ثوانيَ لكثرة البيانات)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جارٍ حذف الحساب وجميع بياناته...'),
                ],
              ),
            ),
          ),
        ),
      );

      final result = await service.deleteTeacherAccount(teacher.uid);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // إغلاق مؤشر التحميل

      if (result.success) {
        showSuccessSnackBar(
            context, 'تم حذف حساب ${teacher.name} وجميع بياناته');
      } else {
        showErrorSnackBar(context, result.errorMessage!);
      }
    }
  }
}

// ==================== حوار إضافة معلم ====================

class _AddTeacherDialog extends StatefulWidget {
  final TeachersService service;
  final String adminUid;

  const _AddTeacherDialog(
      {required this.service, required this.adminUid});

  @override
  State<_AddTeacherDialog> createState() => _AddTeacherDialogState();
}

class _AddTeacherDialogState extends State<_AddTeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specializationController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _specializationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.service.createTeacher(
      adminUid: widget.adminUid,
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      specialization: _specializationController.text,
      phone: _phoneController.text,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(
        context,
        'تم إنشاء حساب المعلم "${_nameController.text.trim()}" بنجاح',
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إضافة معلم جديد',
                              style: textTheme.titleMedium),
                          Text(
                            'سيُنشأ حساب دخول للمعلم فوراً',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الاسم مطلوب'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: ui.TextDirection.ltr,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني *',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'البريد الإلكتروني مطلوب';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v.trim())) {
                      return 'صيغة البريد الإلكتروني غير صحيحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textDirection: ui.TextDirection.ltr,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور المؤقتة *',
                    helperText: '8 أحرف على الأقل',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'كلمة المرور مطلوبة';
                    }
                    if (v.length < 8) {
                      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _specializationController,
                  decoration: const InputDecoration(
                    labelText: 'التخصص (اختياري)',
                    hintText: 'مثال: الفقه، التوحيد، القرآن...',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: ui.TextDirection.ltr,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: AppColors.line),
                          foregroundColor: AppColors.inkSecondary,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إنشاء الحساب'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ==================== حوار إعادة تعيين كلمة المرور ====================

class _ResetPasswordDialog extends StatefulWidget {
  final String teacherName;

  const _ResetPasswordDialog({required this.teacherName});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _passwordController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('إعادة تعيين كلمة المرور'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ضع كلمة المرور الجديدة للمعلم "${widget.teacherName}"،\n'
              'ثم أبلغه بها ليتمكن من تسجيل الدخول.',
              style: TextStyle(color: AppColors.inkSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textDirection: ui.TextDirection.ltr,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'كلمة المرور مطلوبة';
                }
                if (v.trim().length < 8) {
                  return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textDirection: ui.TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'تأكيد كلمة المرور مطلوب';
                }
                if (v.trim() != _passwordController.text.trim()) {
                  return 'كلمتا المرور غير متطابقتين';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded),
          label: const Text('حفظ كلمة المرور'),
        ),
      ],
    );
  }
}
