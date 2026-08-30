import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/student.dart';
import '../../services/auth_service.dart';
import '../../services/students_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';
import 'lessons_tab.dart';
import 'mutun_tab.dart';
import 'quran_tab.dart';

/// شاشة تفاصيل المسار الفاخرة: 4 تبويبات (الطلاب | الدروس | المتون | القرآن)
class PathwayDetailScreen extends StatelessWidget {
  final PathwayInfo pathway;

  const PathwayDetailScreen({super.key, required this.pathway});

  @override
  Widget build(BuildContext context) {
    final teacherId =
        context.watch<AuthService>().currentUser?.uid ?? '';
    final isQuran = pathway.id == 'quran';
    final accent = isQuran ? AppColors.gold : AppColors.primary;
    final imageAsset = AppConstants.pathwayImageAsset(pathway.id);

    // تبويبات بأيقونات مناسبة: طلاب / كتاب مفتوح / كتب متراصة / مصحف على حامل
    Tab buildTab(IconData icon, String text) => Tab(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(fontSize: 11.5)),
            ],
          ),
        );

    final tabs = pathway.isQuranOnly
        ? [buildTab(Icons.auto_stories_rounded, 'القرآن')]
        : [
            buildTab(Icons.groups_rounded, 'الطلاب'),
            buildTab(Icons.menu_book_rounded, 'الدروس'),
            buildTab(Icons.library_books_rounded, 'المتون'),
            buildTab(Icons.auto_stories_rounded, 'القرآن'),
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
                () => StudentsTab(pathway: pathway, teacherId: teacherId)),
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
          title: Row(
            children: [
              // أيقونة المسار: نفس صورة الصفحة الرئيسية داخل دائرة
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isQuran
                        ? AppColors.gold
                        : AppColors.goldSoft,
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
                            size: 23,
                          ),
                        )
                      : Icon(
                          isQuran
                              ? Icons.menu_book_rounded
                              : Icons.school_rounded,
                          color: accent,
                          size: 23,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pathway.name,
                        style: const TextStyle(fontSize: 17)),
                    Text(
                      pathway.description,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSecondary,
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
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.lineSoft)),
              ),
              child: TabBar(tabs: tabs),
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

// ==================== تبويب الطلاب ====================

class StudentsTab extends StatefulWidget {
  final PathwayInfo pathway;
  final String teacherId;

  const StudentsTab({
    super.key,
    required this.pathway,
    required this.teacherId,
  });

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final StudentsService _service = StudentsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_student_${widget.pathway.id}',
        onPressed: () => _showAddStudentDialog(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('إضافة طالب',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<Student>>(
        stream: _service.watchPathwayStudents(
          teacherId: widget.teacherId,
          pathwayId: widget.pathway.id,
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
              title: 'لا يوجد طلاب في هذا المسار',
              message:
                  'ابدأ بإضافة طلابك في مسار "${widget.pathway.name}"',
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
              itemBuilder: (context, index) => _StudentCard(
                student: students[index],
                service: _service,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddStudentDialog(
        service: _service,
        teacherId: widget.teacherId,
        pathway: widget.pathway,
      ),
    );
  }
}

// ==================== بطاقة الطالب ====================

class _StudentCard extends StatelessWidget {
  final Student student;
  final StudentsService service;

  const _StudentCard({required this.student, required this.service});

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
          // قائمة ثلاث نقاط بدل زر الحذف المباشر
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

// ==================== حوار إضافة طالب ====================

class _AddStudentDialog extends StatefulWidget {
  final StudentsService service;
  final String teacherId;
  final PathwayInfo pathway;

  const _AddStudentDialog({
    required this.service,
    required this.teacherId,
    required this.pathway,
  });

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
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
      teacherId: widget.teacherId,
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
                          side: const BorderSide(
                              color: AppColors.line),
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

