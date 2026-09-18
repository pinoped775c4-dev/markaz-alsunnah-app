import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/student.dart';
import '../../services/students_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';

/// شاشة إدارة الطلاب — للإدارة فقط:
/// عرض المستويات الأربعة، وعند اختيار مستوى تظهر قائمة طلابه
/// مع أيقونة إضافة طالب جديدة.
class StudentsAdminScreen extends StatefulWidget {
  const StudentsAdminScreen({super.key});

  @override
  State<StudentsAdminScreen> createState() => _StudentsAdminScreenState();
}

class _StudentsAdminScreenState extends State<StudentsAdminScreen> {
  final StudentsService _service = StudentsService();

  /// المستوى المحدد حاليًا — null يعني عرض المستويات الأربعة
  PathwayInfo? _selectedPathway;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectedPathway != null
            ? IconButton(
                tooltip: 'رجوع للمستويات',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    setState(() => _selectedPathway = null),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedPathway?.name ?? 'إدارة الطلاب'),
            Text(
              _selectedPathway != null
                  ? 'طلاب المستوى — إضافة وحذف وتعديل'
                  : 'اختر مستوى لإدارة طلابه',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: Center(child: CircularLogo(size: 42, elevated: false)),
          ),
        ],
      ),
      body: WatermarkedBackground(
        child: _selectedPathway == null
            ? _buildPathwaysView()
            : _buildStudentsList(_selectedPathway!),
      ),
      // أيقونة إضافة تظهر فقط داخل مستوى محدد
      floatingActionButton: _selectedPathway != null
          ? FloatingActionButton.extended(
              heroTag: 'admin_add_student_${_selectedPathway!.id}',
              onPressed: () => _showAddStudentDialog(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'إضافة طالب',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  // ==================== عرض المستويات الأربعة ====================

  Widget _buildPathwaysView() {
    return StreamBuilder<Map<String, int>>(
      stream: _service.watchStudentCounts(),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? {};

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => setState(() {}),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SectionHeader(
                title: 'المستويات التعليمية',
                subtitle: 'الطلاب مشتركون بين جميع المعلمين في كل مستوى',
              ),
              const SizedBox(height: 12),
              // المستويات الأربعة فقط — بدون قسم القرآن المنفصل
              // (كل طالب يُتابع قرآنه ضمن مستواه التعليمي)
              for (final pathway in AppConstants.pathways
                  .where((p) => p.id != 'quran'))
                _PathwayCard(
                  pathway: pathway,
                  studentCount: counts[pathway.id] ?? 0,
                  onTap: () =>
                      setState(() => _selectedPathway = pathway),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==================== قائمة طلاب المستوى ====================

  Widget _buildStudentsList(PathwayInfo pathway) {
    return StreamBuilder<List<Student>>(
      stream: _service.watchPathwayStudentsForAdmin(
        pathwayId: pathway.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: 'حدث خطأ أثناء تحميل قائمة الطلاب',
            onRetry: () => setState(() {}),
          );
        }

        if (!snapshot.hasData) {
          return const ListSkeleton(itemCount: 5);
        }

        final students = snapshot.data!;

        if (students.isEmpty) {
          return EmptyState(
            icon: Icons.school_outlined,
            title: 'لا يوجد طلاب في هذا المستوى',
            message:
                'اضغط على زر "إضافة طالب" لإضافة أول طالب إلى "${pathway.name}"',
            actionLabel: 'إضافة أول طالب',
            onAction: () => _showAddStudentDialog(context),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: students.length,
            itemBuilder: (context, index) => _AdminStudentCard(
              student: students[index],
              service: _service,
            ),
          ),
        );
      },
    );
  }

  // ==================== حوار إضافة طالب ====================

  void _showAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddStudentAdminDialog(
        service: _service,
        pathway: _selectedPathway!,
      ),
    );
  }
}

// ==================== بطاقة المستوى ====================

class _PathwayCard extends StatelessWidget {
  final PathwayInfo pathway;
  final int studentCount;
  final VoidCallback onTap;

  const _PathwayCard({
    required this.pathway,
    required this.studentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isQuran = pathway.id == 'quran';
    final imageAsset = AppConstants.pathwayImageAsset(pathway.id);
    final accent = isQuran ? AppColors.gold : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // صورة المستوى الدائرية
              Container(
                width: 56,
                height: 56,
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
                          errorBuilder: (_, __, ___) => _fallbackIcon(isQuran),
                        )
                      : _fallbackIcon(isQuran),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pathway.name,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pathway.description,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: accent.withValues(alpha: 0.7),
                textDirection: ui.TextDirection.ltr,
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
        size: 26,
      ),
    );
  }
}

// ==================== بطاقة الطالب (للإدارة) ====================

class _AdminStudentCard extends StatelessWidget {
  final Student student;
  final StudentsService service;

  const _AdminStudentCard({required this.student, required this.service});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enrolledText = student.enrolledAt != null
        ? DateFormat('d MMMM y', 'ar').format(student.enrolledAt!)
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialAvatar(name: student.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: textTheme.titleSmall),
                if (student.phone != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 14, color: AppColors.inkMuted),
                      const SizedBox(width: 4),
                      Text(
                        student.phone!,
                        style: textTheme.bodySmall,
                        textDirection: ui.TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
                if (student.notes != null &&
                    student.notes!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    student.notes!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (enrolledText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'التحق في $enrolledText',
                    style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          CardActionsMenu(
            actions: [
              CardMenuAction(
                label: 'حذف الطالب',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف الطالب',
      message:
          'سيتم حذف "${student.name}" نهائياً مع جميع سجلاته.\nلا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف نهائي',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await service.deleteStudent(student.id);
    if (!context.mounted) return;

    if (result.success) {
      showSuccessSnackBar(context, 'تم حذف الطالب "${student.name}"');
    } else {
      showErrorSnackBar(context, result.errorMessage!);
    }
  }
}

// ==================== حوار إضافة طالب (إدارة) ====================

class _AddStudentAdminDialog extends StatefulWidget {
  final StudentsService service;
  final PathwayInfo pathway;

  const _AddStudentAdminDialog({
    required this.service,
    required this.pathway,
  });

  @override
  State<_AddStudentAdminDialog> createState() =>
      _AddStudentAdminDialogState();
}

class _AddStudentAdminDialogState extends State<_AddStudentAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.service.addStudent(
      pathwayId: widget.pathway.id,
      pathwayName: widget.pathway.name,
      name: _nameController.text,
      phone: _phoneController.text,
      notes: _notesController.text,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(
        context,
        'تمت إضافة الطالب "${_nameController.text.trim()}"',
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
                      child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إضافة طالب جديد',
                              style: textTheme.titleMedium),
                          Text(
                            widget.pathway.name,
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
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.error),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الطالب *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'اسم الطالب مطلوب'
                      : null,
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
                const SizedBox(height: 14),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
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
                            : const Text('إضافة الطالب'),
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
