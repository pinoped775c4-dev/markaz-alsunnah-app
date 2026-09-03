import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/quran.dart';
import '../../models/student.dart';
import '../../services/mutun_wird_service.dart';
import '../../services/quran_service.dart';
import '../../services/students_service.dart';
import '../../widgets/common_widgets.dart';

/// تبويب القرآن الكريم — متابعة الأوراد اليومية (صفحات 1–604، ختمة = 604)
class QuranTab extends StatefulWidget {
  final PathwayInfo pathway;
  final String teacherId;

  const QuranTab({super.key, required this.pathway, required this.teacherId});

  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab>
    with AutomaticKeepAliveClientMixin {
  final QuranService _quranService = QuranService();
  final StudentsService _studentsService = StudentsService();
  final MutunWirdService _wirdService = MutunWirdService();

  /// هل المعلم الحالي هو معلم المتون والأوراد المخصص من الإدارة؟
  bool? _isDesignated;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _wirdService.isDesignated(widget.teacherId).then((v) {
      if (mounted) setState(() => _isDesignated = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Student>>(
      stream: _studentsService.watchPathwayStudents(
        teacherId: widget.teacherId,
        pathwayId: widget.pathway.id,
      ),
      builder: (context, studentsSnap) {
        if (studentsSnap.hasError) {
          return ErrorState(
            message: 'حدث خطأ أثناء تحميل الطلاب',
            onRetry: () => setState(() {}),
          );
        }
        if (!studentsSnap.hasData) {
          return const ListSkeleton(itemCount: 4);
        }

        final students = studentsSnap.data!;
        if (students.isEmpty) {
          return const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'لا يوجد طلاب في هذا المسار',
            message:
                'أضف طلاباً في تبويب "الطلاب" أولاً\nلتتمكن من متابعة أورادهم القرآنية',
          );
        }

        return StreamBuilder<List<QuranRecording>>(
          stream: _quranService.watchPathwayRecordings(
            teacherId: widget.teacherId,
            pathwayId: widget.pathway.id,
          ),
          builder: (context, recSnap) {
            if (!recSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final recordings = recSnap.data!;
            final byStudent = <String, List<QuranRecording>>{};
            for (final r in recordings) {
              byStudent.putIfAbsent(r.studentId, () => []).add(r);
            }

            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: () async => setState(() {}),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final recs = byStudent[student.id] ?? [];
                  return _StudentQuranCard(
                    student: student,
                    summary: summarizeQuranProgress(recs),
                    recordings: recs,
                    pathwayId: widget.pathway.id,
                    teacherId: widget.teacherId,
                    isDesignated: _isDesignated,
                    quranService: _quranService,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== بطاقة تقدم طالب في القرآن ====================

class _StudentQuranCard extends StatelessWidget {
  final Student student;
  final QuranProgressSummary summary;
  final List<QuranRecording> recordings;
  final String pathwayId;
  final String teacherId;
  final bool? isDesignated;
  final QuranService quranService;

  const _StudentQuranCard({
    required this.student,
    required this.summary,
    required this.recordings,
    required this.pathwayId,
    required this.teacherId,
    this.isDesignated,
    required this.quranService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: InitialAvatar(name: student.name, radius: 22),
        title: Row(
          children: [
            Expanded(child: Text(student.name, style: textTheme.titleSmall)),
            if (summary.completedKhatmas > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.goldSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.completedKhatmas} ختمة',
                  style: const TextStyle(
                    color: AppColors.goldDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: summary.khatmaProgress,
                  minHeight: 7,
                  backgroundColor: AppColors.lineSoft,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                summary.recordingsCount == 0
                    ? 'لم يبدأ الورد بعد'
                    : summary.currentPage == 0
                    ? 'في بداية ختمة جديدة'
                    : 'وصل إلى صفحة ${summary.currentPage} من ${AppConstants.khatmaPages} (${summary.khatmaPercent}%)',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // زر تسجيل الورد — للمعلم المسؤول فقط
                if (isDesignated == true)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      foregroundColor: AppColors.goldDark,
                      backgroundColor: AppColors.goldSurface,
                      side: const BorderSide(color: AppColors.goldSoft),
                    ),
                    onPressed: () => _showAddWardDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('تسجيل ورد جديد'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'تسجيل الأوراد الرسمية — لمعلم المتون والأوراد فقط',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                if (recordings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...recordings
                      .take(15)
                      .map(
                        (r) => _WardTile(
                          recording: r,
                          onDelete: () => _deleteRecording(context, r),
                        ),
                      ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'لا توجد أوراد مسجلة لهذا الطالب بعد',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddWardDialog(
        student: student,
        teacherId: teacherId,
        pathwayId: pathwayId,
        service: quranService,
        suggestedFrom: summary.currentPage + 1,
      ),
    );
  }

  Future<void> _deleteRecording(BuildContext context, QuranRecording r) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف الورد',
      message:
          'سيتم حذف ورد ${r.weekday} (${fmtNum(r.count)} صفحة).\nهل أنت متأكد؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await quranService.deleteRecording(r.id);
    if (!context.mounted) return;

    if (result.success) {
      showSuccessSnackBar(context, 'تم حذف الورد');
    } else {
      showErrorSnackBar(context, result.errorMessage!);
    }
  }
}

// ==================== بلاطة ورد ====================

class _WardTile extends StatelessWidget {
  final QuranRecording recording;
  final VoidCallback onDelete;

  const _WardTile({required this.recording, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('d MMMM y', 'ar').format(recording.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.goldSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${recording.weekday}، $dateText',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (recording.completesKhatma) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ختمة 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'من صفحة ${fmtNum(recording.fromPage)} إلى ${fmtNum(recording.toPage)} (${fmtNum(recording.count)} صفحة)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSecondary,
                  ),
                ),
                if (recording.notes != null && recording.notes!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    recording.notes!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // قائمة ثلاث نقاط بدل زر الحذف المباشر
          CardActionsMenu(
            actions: [
              CardMenuAction(
                label: 'حذف التسجيل',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== حوار تسجيل ورد ====================

class _AddWardDialog extends StatefulWidget {
  final Student student;
  final String teacherId;
  final String pathwayId;
  final QuranService service;
  final int suggestedFrom;

  const _AddWardDialog({
    required this.student,
    required this.teacherId,
    required this.pathwayId,
    required this.service,
    required this.suggestedFrom,
  });

  @override
  State<_AddWardDialog> createState() => _AddWardDialogState();
}

class _AddWardDialogState extends State<_AddWardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.suggestedFrom <= AppConstants.khatmaPages) {
      _fromController.text = '${widget.suggestedFrom}';
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? get _autoCount {
    final from = double.tryParse(_fromController.text.trim());
    final to = double.tryParse(_toController.text.trim());
    if (from == null || to == null || to < from) return null;
    return to - from + 1;
  }

  bool get _isKhatma {
    final to = double.tryParse(_toController.text.trim());
    return to != null && to >= AppConstants.khatmaPages;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final from = double.parse(_fromController.text.trim());
    final to = double.parse(_toController.text.trim());

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.service.addWardRecording(
      teacherId: widget.teacherId,
      pathwayId: widget.pathwayId,
      studentId: widget.student.id,
      date: _selectedDate,
      fromPage: from,
      toPage: to,
      notes: _notesController.text,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(
        context,
        _isKhatma
            ? 'ما شاء الله! ${widget.student.name} أتمّ الختمة 🎉'
            : 'تم تسجيل ورد ${widget.student.name}',
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
    final weekday = QuranService.weekdayOf(_selectedDate);
    final dateText = DateFormat('d MMMM y', 'ar').format(_selectedDate);
    final count = _autoCount;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تسجيل ورد قرآني', style: textTheme.titleMedium),
                          Text(widget.student.name, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // التاريخ (يحدد اليوم تلقائياً)
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'التاريخ',
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$weekday، $dateText'),
                        const Icon(
                          Icons.edit_calendar_outlined,
                          size: 18,
                          color: AppColors.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // من / إلى (صفحات 1-604)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fromController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'من صفحة *',
                          hintText: '1',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null ||
                              n < 1 ||
                              n > AppConstants.khatmaPages) {
                            return '1–${AppConstants.khatmaPages}';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _toController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'إلى صفحة *',
                          hintText: '${AppConstants.khatmaPages}',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null ||
                              n < 1 ||
                              n > AppConstants.khatmaPages) {
                            return '1–${AppConstants.khatmaPages}';
                          }
                          final from = double.tryParse(
                            _fromController.text.trim(),
                          );
                          if (from != null && n < from) {
                            return 'أقل من "من"';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                if (count != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isKhatma
                          ? AppColors.goldSurface
                          : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _isKhatma
                          ? '🎉 ${fmtNum(count)} صفحة — إتمام ختمة كاملة!'
                          : 'المقدار: ${fmtNum(count)} صفحة (محسوب تلقائياً)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isKhatma
                            ? AppColors.goldDark
                            : AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    hintText: 'مثال: تسميع ممتاز، يحتاج مراجعة...',
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                        ),
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
                            : const Text('حفظ الورد'),
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
