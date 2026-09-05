import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/lesson.dart';
import '../../models/student.dart';
import '../../services/lessons_service.dart';
import '../../services/students_service.dart';
import '../../widgets/common_widgets.dart';

/// تبويب الدروس — قائمة بطاقات دروس متعددة (نمط المتون)
///
/// لكل مسار يستطيع المعلم إنشاء أكثر من درس عام؛ كل درس بطاقة تُنقر
/// فتفتح شاشة تفاصيل فيها سجل الدروس اليومية + الرسم البياني للمنجز.
class LessonsTab extends StatefulWidget {
  final PathwayInfo pathway;
  final String teacherId;

  const LessonsTab({
    super.key,
    required this.pathway,
    required this.teacherId,
  });

  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab>
    with AutomaticKeepAliveClientMixin {
  final LessonsService _lessonsService = LessonsService();
  final StudentsService _studentsService = StudentsService();

  int _retryTick = 0;

  /// درس مُنشأ محليًا (تحديث متفائل) — يُعرض فورًا بعد الإضافة
  /// قبل وصول أول snapshot من البث، حتى لا يبدو أن الإضافة "لم تُسجّل".
  Lesson? _optimisticLesson;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // حماية من الحالة التي تُفتح فيها الصفحة قبل اكتمال جلسة المعلم
    if (widget.teacherId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جارٍ تهيئة حساب المعلم...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_lesson_${widget.pathway.id}',
        onPressed: () => _showAddLessonDialog(context),
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text('إضافة درس',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: KeyedSubtree(
        key: ValueKey(_retryTick),
        child: StreamBuilder<List<Lesson>>(
          stream: _lessonsService.watchPathwayLessons(
            teacherId: widget.teacherId,
            pathwayId: widget.pathway.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('LessonsTab stream error: ${snapshot.error}');
              final isPermission =
                  snapshot.error.toString().contains('permission');
              return ErrorState(
                message: isPermission
                    ? 'تم رفض الوصول من قاعدة البيانات.\n'
                        'تأكد من قواعد أمان Firestore (تطلب تسجيل الدخول).'
                    : 'تعذّر تحميل بيانات الدروس.\n'
                        'تحقق من الاتصال بالإنترنت ثم أعد المحاولة.',
                onRetry: () => setState(() => _retryTick++),
              );
            }

            if (!snapshot.hasData) {
              return const ListSkeleton(itemCount: 4);
            }

            var lessons = snapshot.data!;

            // عرض متفائل: دُرس أُنشئ للتوّ لم يصله البث بعد — يُدمج مقدمًا
            if (_optimisticLesson != null &&
                !lessons.any((l) => l.id == _optimisticLesson!.id)) {
              lessons = [...lessons, _optimisticLesson!];
            }

            if (lessons.isEmpty) {
              return EmptyState(
                icon: Icons.menu_book_rounded,
                title: 'لا توجد دروس بعد',
                message:
                    'أضف دروس هذا المسار العام لتسجل فيها الدروس اليومية\n'
                    'مثال: كتاب التوحيد، الآجرومية، القواعد الأربع...',
                actionLabel: 'إضافة أول درس',
                onAction: () => _showAddLessonDialog(context),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => setState(() => _retryTick++),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                itemCount: lessons.length,
                itemBuilder: (context, index) => _LessonCard(
                  lesson: lessons[index],
                  pathway: widget.pathway,
                  lessonsService: _lessonsService,
                  studentsService: _studentsService,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddLessonDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddLessonDialog(
        service: _lessonsService,
        teacherId: widget.teacherId,
        pathway: widget.pathway,
        onCreated: (lesson) {
          if (mounted) setState(() => _optimisticLesson = lesson);
        },
      ),
    );
  }
}

// ==================== بطاقة الدرس في القائمة ====================

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final PathwayInfo pathway;
  final LessonsService lessonsService;
  final StudentsService studentsService;

  const _LessonCard({
    required this.lesson,
    required this.pathway,
    required this.lessonsService,
    required this.studentsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LessonDetailScreen(
                  lesson: lesson,
                  pathway: pathway,
                  lessonsService: lessonsService,
                  studentsService: studentsService,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: lesson.isNazm
                        ? AppColors.goldSurface
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    lesson.isNazm
                        ? Icons.format_list_numbered_rounded
                        : Icons.article_rounded,
                    color: lesson.isNazm
                        ? AppColors.gold
                        : AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.name,
                          style: textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        '${lesson.typeLabel} • ${lesson.totalCount} ${lesson.unitLabel} • المنجز ${lesson.completedCount}',
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${lesson.progressPercent}%',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // قائمة ثلاث نقاط بدل زر الحذف المباشر
                CardActionsMenu(
                  actions: [
                    CardMenuAction(
                      label: 'حذف الدرس',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: AppColors.inkMuted.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف الدرس',
      message: 'سيتم حذف "${lesson.name}" مع جميع الدروس اليومية '
          'وسجلات الحضور المرتبطة به.\nلا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف نهائي',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await lessonsService.deleteLesson(lesson);
    if (!context.mounted) return;

    if (result.success) {
      showSuccessSnackBar(context, 'تم حذف الدرس "${lesson.name}"');
    } else {
      showErrorSnackBar(context, result.errorMessage!);
    }
  }
}

// ==================== حوار إضافة درس عام ====================

class _AddLessonDialog extends StatefulWidget {
  final LessonsService service;
  final String teacherId;
  final PathwayInfo pathway;
  final ValueChanged<Lesson>? onCreated;

  const _AddLessonDialog({
    required this.service,
    required this.teacherId,
    required this.pathway,
    this.onCreated,
  });

  @override
  State<_AddLessonDialog> createState() => _AddLessonDialogState();
}

class _AddLessonDialogState extends State<_AddLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalController = TextEditingController();

  String _type = 'nazm';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.service.setupLesson(
      teacherId: widget.teacherId,
      pathwayId: widget.pathway.id,
      name: _nameController.text,
      type: _type,
      totalCount: int.parse(_totalController.text.trim()),
    );

    if (!mounted) return;

    if (result.success) {
      // عرض متفائل: نرفع الدرس المُنشأ للقائمة قبل إغلاق الحوار
      final created = result.lesson;
      Navigator.pop(context);
      if (created != null) {
        widget.onCreated?.call(created);
      }
      showSuccessSnackBar(
          context, 'تمت إضافة الدرس "${_nameController.text.trim()}"');
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
    final isNazm = _type == 'nazm';

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
                      child: const Icon(Icons.menu_book_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إضافة درس جديد',
                              style: textTheme.titleMedium),
                          Text(widget.pathway.name,
                              style: textTheme.bodySmall),
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
                    child: Text(_errorMessage!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.error)),
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدرس *',
                    hintText: 'مثال: كتاب التوحيد',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'اسم الدرس مطلوب'
                      : null,
                ),
                const SizedBox(height: 16),

                // نوع الدرس
                Text('نوع الدرس', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TypeOption(
                        label: 'نظم',
                        subtitle: 'يُحسب بالأبيات',
                        icon: Icons.format_list_numbered_rounded,
                        selected: _type == 'nazm',
                        onTap: () => setState(() => _type = 'nazm'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TypeOption(
                        label: 'نثر',
                        subtitle: 'يُحسب بالصفحات',
                        icon: Icons.article_outlined,
                        selected: _type == 'nathr',
                        onTap: () => setState(() => _type = 'nathr'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isNazm
                        ? 'عدد الأبيات الإجمالي *'
                        : 'عدد الصفحات الإجمالي *',
                    prefixIcon: const Icon(
                        Icons.format_list_numbered_rtl_rounded),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) {
                      return 'أدخل عدداً صحيحاً أكبر من صفر';
                    }
                    return null;
                  },
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
                            : const Text('حفظ الدرس'),
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

class _TypeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.inkMuted,
                size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: selected ? AppColors.primaryDark : AppColors.ink,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ==================== شاشة تفاصيل الدرس ====================

/// شاشة تفاصيل درس عام: البطاقة الكبرى + الرسم البياني للمنجز +
/// زر إضافة درس يومي + سجل الدروس اليومية.
class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  final PathwayInfo pathway;
  final LessonsService lessonsService;
  final StudentsService studentsService;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    required this.pathway,
    required this.lessonsService,
    required this.studentsService,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  /// التسجيلات المضافة/المعدّلة للتو — تُدمج فوق البث (العرض المتفائل)
  final Map<String, LessonRecording> _optimistic = {};

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _DailyLessonDialog(
        pathway: widget.pathway,
        lesson: widget.lesson,
        lessonsService: widget.lessonsService,
        studentsService: widget.studentsService,
        onSaved: (rec) {
          setState(() => _optimistic[rec.id] = rec);
        },
      ),
    );
  }

  void _openEditDialog(LessonRecording recording) {
    showDialog(
      context: context,
      builder: (ctx) => _DailyLessonDialog(
        pathway: widget.pathway,
        lesson: widget.lesson,
        lessonsService: widget.lessonsService,
        studentsService: widget.studentsService,
        editing: recording,
        onSaved: (rec) {
          setState(() => _optimistic[rec.id] = rec);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceAlt,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.lesson.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              widget.pathway.name,
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.inkMuted),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<LessonRecording>>(
        stream: widget.lessonsService.watchRecordings(
          teacherId: widget.lesson.teacherId,
          lessonId: widget.lesson.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: 'تعذّر تحميل سجل الدروس اليومية.\n${snapshot.error}',
              onRetry: () => setState(() {}),
            );
          }

          final recordings = <LessonRecording>[];
          if (snapshot.hasData) {
            final byId = {
              for (final r in snapshot.data!) r.id: r,
            };
            // العرض المتفائل: المحلية تتفوق على القادمة من البث
            _optimistic.forEach((id, rec) {
              byId[id] = rec;
            });
            recordings.addAll(byId.values);
            recordings.sort((a, b) => b.date.compareTo(a.date));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _BigLessonCard(lesson: widget.lesson),
              const SizedBox(height: 16),

              // الرسم البياني للمنجز (تراكمي)
              _ProgressChartCard(
                  lesson: widget.lesson, recordings: recordings),
              const SizedBox(height: 16),

              // زر إضافة درس يومي
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openAddDialog,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('إضافة درس يومي',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SectionHeader(
                title: 'سجل الدروس اليومية',
                subtitle:
                    '${recordings.length} درسًا مسجلًا • المنجز ${widget.lesson.completedCount} ${widget.lesson.unitLabel}',
              ),
              const SizedBox(height: 10),

              if (snapshot.connectionState == ConnectionState.waiting &&
                  recordings.isEmpty)
                const ListSkeleton(itemCount: 3)
              else if (recordings.isEmpty)
                _HistoryEmpty(onAdd: _openAddDialog)
              else
                ...recordings.map(
                  (rec) => _RecordingCard(
                    recording: rec,
                    lesson: widget.lesson,
                    service: widget.lessonsService,
                    onEdit: () => _openEditDialog(rec),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== الرسم البياني للمنجز (fl_chart) ====================

/// بطاقة الرسم البياني التراكمي: يوضح كم أُنجز من الدرس عبر الدروس اليومية.
class _ProgressChartCard extends StatelessWidget {
  final Lesson lesson;
  final List<LessonRecording> recordings;

  const _ProgressChartCard({required this.lesson, required this.recordings});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spots = <FlSpot>[];

    if (recordings.isNotEmpty) {
      // الأقدم أولًا لبناء التراكم
      final sorted = [...recordings]
        ..sort((a, b) => a.date.compareTo(b.date));

      double cumulative = 0;
      for (int i = 0; i < sorted.length; i++) {
        cumulative = sorted[i].to.toDouble();
        spots.add(FlSpot((i + 1).toDouble(), cumulative));
      }
    }

    final maxY = lesson.totalCount > 0
        ? lesson.totalCount.toDouble()
        : (spots.isNotEmpty ? spots.last.y + 1 : 10.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('المنجز عبر الدروس اليومية',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${lesson.progressPercent}%',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'الوصول إلى ${lesson.completedCount} من ${lesson.totalCount} ${lesson.unitLabel}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'سيظهر الرسم البياني بعد تسجيل أول درس يومي',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (spots.length).toDouble(),
                      minY: 0,
                      maxY: maxY * 1.05,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval:
                            maxY > 4 ? maxY / 4 : 1.0,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: AppColors.lineSoft,
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: maxY > 4 ? maxY / 4 : 1.0,
                            getTitlesWidget: (v, meta) => SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 6,
                              child: Text(
                                v.toInt().toString(),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.inkMuted),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 1,
                            getTitlesWidget: (v, meta) {
                              final idx = v.toInt() - 1;
                              if (idx < 0 ||
                                  idx >= spots.length ||
                                  v == 0) {
                                return const SizedBox.shrink();
                              }
                              final sorted = [...recordings]
                                ..sort((a, b) => a.date.compareTo(b.date));
                              final d = DateFormat('d/M', 'ar')
                                  .format(sorted[idx].date);
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 6,
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppColors.inkMuted),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            FlSpot(0, 0),
                            ...spots,
                          ],
                          isCurved: true,
                          preventCurveOverShooting: true,
                          barWidth: 3,
                          color: AppColors.primary,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.gold,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color:
                                AppColors.primary.withValues(alpha: 0.10),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                    '${s.y.toInt()} ${lesson.unitLabel}',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BigLessonCard extends StatelessWidget {
  final Lesson lesson;

  const _BigLessonCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  lesson.isNazm
                      ? Icons.format_list_numbered_rounded
                      : Icons.article_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.name,
                      style: textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${lesson.typeLabel} • ${lesson.totalCount} ${lesson.unitLabel}',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${lesson.progressPercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // شريط التقدم
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: lesson.progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.goldSoft),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressStat(
                label: 'المنجز',
                value: '${lesson.completedCount}',
              ),
              _ProgressStat(
                label: 'المتبقي',
                value: '${lesson.remainingCount}',
              ),
              _ProgressStat(
                label: 'الإجمالي',
                value: '${lesson.totalCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProgressStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
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
    );
  }
}

// ==================== حوار الدرس اليومي ====================

class _DailyLessonDialog extends StatefulWidget {
  final PathwayInfo pathway;
  final Lesson lesson;
  final LessonsService lessonsService;
  final StudentsService studentsService;
  final LessonRecording? editing;

  /// يُستدع فور نجاح الحفظ بالتسجيل المُنشأ/المُعدّل — للعرض المتفائل
  final ValueChanged<LessonRecording>? onSaved;

  const _DailyLessonDialog({
    required this.pathway,
    required this.lesson,
    required this.lessonsService,
    required this.studentsService,
    this.editing,
    this.onSaved,
  });

  @override
  State<_DailyLessonDialog> createState() => _DailyLessonDialogState();
}

class _DailyLessonDialogState extends State<_DailyLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  String? _errorMessage;

  // الحضور
  List<Student> _students = [];
  final Set<String> _presentIds = {};
  bool _studentsLoading = true;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.editing!;
      _selectedDate = e.date;
      _durationController.text = e.duration;
      _fromController.text = fmtNum(e.from);
      _toController.text = fmtNum(e.to);
      _notesController.text = e.notes ?? '';
    } else {
      // تعبئة "من" تلقائياً — الترقيم التلقائي للبيوت/الصفحات:
      // نبدأ من آخر "إلى" سُجّل فعلياً + 1 (مثال: أمس من 1 إلى 8 ← اليوم من 9).
      // نعتمد على أحدث تسجيل من قاعدة البيانات (لا على completedCount الذي
      // قد يكون قديماً في كائن الدرس الممرّر من القائمة).
      _prefillFrom();
    }
    _loadStudents();
  }

  /// جلب آخر تسجيل ووضع "من" = آخر "إلى" + 1 تلقائياً.
  /// إن لم توجد تسجيلات سابقة نبدأ من العداد الحالي + 1.
  Future<void> _prefillFrom() async {
    final lesson = widget.lesson;
    double nextFrom;
    try {
      final latest = await widget.lessonsService.fetchLatestRecording(
        teacherId: lesson.teacherId,
        lessonId: lesson.id,
      );
      if (latest != null && latest.to >= 0) {
        nextFrom = latest.to + 1;
      } else {
        nextFrom = (lesson.completedCount + 1).toDouble();
      }
    } catch (_) {
      nextFrom = (lesson.completedCount + 1).toDouble();
    }
    if (!mounted) return;
    // لا نطغى على قيمة كتبها المستخدم أثناء الجلب
    if (_fromController.text.trim().isEmpty && nextFrom > 0) {
      if (nextFrom <= lesson.totalCount || lesson.totalCount <= 0) {
        setState(() => _fromController.text = fmtNum(nextFrom));
      }
    }
  }

  Future<void> _loadStudents() async {
    try {
      // جلب مباشر get() — موثوق ولا يعلق مثل البث، فيظهر جدول الحضور فورًا
      final students = await widget.studentsService.fetchPathwayStudents(
        teacherId: widget.lesson.teacherId,
        pathwayId: widget.pathway.id,
      );
      if (!mounted) return;

      if (_isEditing) {
        // ملء مسبق من وثيقة الحضور المرتبطة بالتسجيل
        final presentIds = await widget.lessonsService
            .fetchPresentIds(widget.editing!.id);
        if (!mounted) return;
        setState(() {
          _students = students;
          if (presentIds != null) {
            _presentIds.addAll(presentIds);
          } else {
            // لا توجد وثيقة حضور — الكل حاضر افتراضياً
            _presentIds.addAll(students.map((s) => s.id));
          }
          _studentsLoading = false;
        });
      } else {
        setState(() {
          _students = students;
          // افتراضياً الكل حاضر
          _presentIds.addAll(students.map((s) => s.id));
          _studentsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _studentsLoading = false);
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final from = double.parse(_fromController.text.trim());
    final to = double.parse(_toController.text.trim());

    // تحقق: to لا يتجاوز الإجمالي
    final effectiveTotal = widget.lesson.totalCount;
    if (to > effectiveTotal) {
      setState(() => _errorMessage =
          'القيمة "إلى" ($to) تتجاوز إجمالي الدرس ($effectiveTotal)');
      return;
    }

    // تحقق: لا يتجاوز المتبقي (للإضافة فقط)
    if (!_isEditing && to > effectiveTotal) {
      setState(() => _errorMessage = 'تجاوزت نهاية الدرس');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final absentIds =
        _students.map((s) => s.id).where((id) => !_presentIds.contains(id)).toList();

    // دمج الزمن مع المدة في النص المحفوظ ليظهر في السجل والتقارير
    final timeText = _selectedTime.format(context);
    final durationText =
        '${_durationController.text.trim()} • $timeText';

    LessonOpResult result;
    if (_isEditing) {
      result = await widget.lessonsService.updateRecording(
        recording: widget.editing!,
        oldCount: widget.editing!.count,
        date: _selectedDate,
        duration: durationText,
        from: from,
        to: to,
        notes: _notesController.text,
        presentStudentIds: _presentIds.toList(),
        absentStudentIds: absentIds,
        currentCompleted: widget.lesson.completedCount,
      );
    } else {
      result = await widget.lessonsService.addDailyRecording(
        lesson: widget.lesson,
        date: _selectedDate,
        duration: durationText,
        from: from,
        to: to,
        notes: _notesController.text,
        presentStudentIds: _presentIds.toList(),
        absentStudentIds: absentIds,
      );
    }

    if (!mounted) return;

    if (result.success) {
      // عرض متفائل فوري: نمرّر التسجيل المُنشأ/المُعدّل قبل إغلاق الحوار
      final rec = result.recording;
      Navigator.pop(context);
      if (rec != null) {
        widget.onSaved?.call(rec);
      }
      showSuccessSnackBar(
        context,
        _isEditing ? 'تم تعديل التسجيل بنجاح' : 'تم تسجيل الدرس اليومي بنجاح',
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
    final weekday = LessonsService.weekdayOf(_selectedDate);
    final dateText =
        DateFormat('d MMMM y', 'ar').format(_selectedDate);
    final count = _autoCount;

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? 'تعديل درس يومي'
                                : 'إضافة درس يومي',
                            style: textTheme.titleMedium,
                          ),
                          Text(widget.lesson.name,
                              style: textTheme.bodySmall),
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
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(_errorMessage!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.error)),
                  ),
                  const SizedBox(height: 14),
                ],

                // اليوم + التاريخ
                Row(
                  children: [
                    Expanded(
                      child: _ReadOnlyField(
                        label: 'اليوم',
                        value: weekday,
                        icon: Icons.today_rounded,
                        hint: 'يتحدد تلقائياً من التاريخ',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: _ReadOnlyField(
                          label: 'التاريخ',
                          value: dateText,
                          icon: Icons.calendar_month_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // الزمن + المدة
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: _ReadOnlyField(
                          label: 'زمن الدرس',
                          value: _selectedTime.format(context),
                          icon: Icons.access_time_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'مدة الدرس *',
                          hintText: 'مثال: ساعة ونصف، 45 دقيقة...',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'مدة الدرس مطلوبة'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // من / إلى / العدد التلقائي
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fromController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'من (${widget.lesson.unitLabel}) *',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'مطلوب';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _toController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'إلى (${widget.lesson.unitLabel}) *',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'مطلوب';
                          final from =
                              double.tryParse(_fromController.text.trim());
                          if (from != null && n < from) {
                            return 'أقل من "من"';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: count != null
                            ? AppColors.primarySurface
                            : AppColors.surfaceAlt,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          Text(
                            count != null ? fmtNum(count) : '—',
                            style: textTheme.titleSmall?.copyWith(
                              color: count != null
                                  ? AppColors.primaryDark
                                  : AppColors.inkMuted,
                            ),
                          ),
                          Text('العدد',
                              style: textTheme.bodySmall
                                  ?.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ملاحظات
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),

                // الحضور
                Row(
                  children: [
                    Icon(Icons.how_to_reg_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('حضور الطلاب', style: textTheme.titleSmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'حاضر: ${_presentIds.length}/${_students.length}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_studentsLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        Center(child: CircularProgressIndicator()),
                  )
                else if (_students.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'لا يوجد طلاب في هذا المسار بعد. أضفهم من تبويب الطلاب.',
                      style: TextStyle(
                          color: AppColors.warning, fontSize: 12.5),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _students.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 14, endIndent: 14),
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final present = _presentIds.contains(student.id);
                        return _StudentAttendanceRow(
                          name: student.name,
                          present: present,
                          onPresent: () => setState(
                              () => _presentIds.add(student.id)),
                          onAbsent: () => setState(
                              () => _presentIds.remove(student.id)),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side:
                              const BorderSide(color: AppColors.line),
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
                            : Text(_isEditing
                                ? 'حفظ التعديل'
                                : 'حفظ الدرس'),
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

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? hint;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!,
              style: textTheme.bodySmall
                  ?.copyWith(fontSize: 10.5, color: AppColors.inkMuted)),
        ],
      ],
    );
  }
}

// ==================== بطاقة تسجيل مضغوطة ====================

class _RecordingCard extends StatelessWidget {
  final LessonRecording recording;
  final Lesson lesson;
  final LessonsService service;
  final VoidCallback? onEdit;

  const _RecordingCard({
    required this.recording,
    required this.lesson,
    required this.service,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText =
        DateFormat('d MMMM y', 'ar').format(recording.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${recording.weekday}، $dateText',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // قائمة ثلاث نقاط: تعديل + حذف
              CardActionsMenu(
                actions: [
                  if (onEdit != null)
                    CardMenuAction(
                      label: 'تعديل التسجيل',
                      icon: Icons.edit_outlined,
                      onTap: onEdit!,
                    ),
                  CardMenuAction(
                    label: 'حذف التسجيل',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                    onTap: () => _confirmDelete(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: recording.duration,
              ),
              _MetaChip(
                icon: Icons.format_list_numbered_rounded,
                label:
                    '${fmtNum(recording.from)} ← ${fmtNum(recording.to)} (${fmtNum(recording.count)} ${lesson.unitLabel})',
              ),
              _MetaChip(
                icon: Icons.how_to_reg_rounded,
                label:
                    'حاضر ${recording.presentCount}/${recording.totalStudents}',
                color: AppColors.success,
                bg: AppColors.successSurface,
              ),
            ],
          ),
          if (recording.notes != null &&
              recording.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                recording.notes!,
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف التسجيل',
      message:
          'سيتم حذف هذا التسجيل وإرجاع ${fmtNum(recording.count)} ${lesson.unitLabel} من العداد.\nهل أنت متأكد؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await service.deleteRecording(
        recording, lesson.completedCount);
    if (!context.mounted) return;

    if (result.success) {
      showSuccessSnackBar(context, 'تم حذف التسجيل');
    } else {
      showErrorSnackBar(context, result.errorMessage!);
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = AppColors.inkSecondary,
    this.bg = AppColors.surfaceAlt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==================== صف حضور الطالب (زرّان متنافيان) ====================

class _StudentAttendanceRow extends StatelessWidget {
  final String name;
  final bool present;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;

  const _StudentAttendanceRow({
    required this.name,
    required this.present,
    required this.onPresent,
    required this.onAbsent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                present ? AppColors.primarySurface : AppColors.line,
            child: Text(
              name.isNotEmpty ? name[0] : '؟',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: present
                    ? AppColors.primaryDark
                    : AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _AttendanceButton(
            label: 'حاضر',
            icon: Icons.check_rounded,
            selected: present,
            selectedColor: AppColors.success,
            onTap: onPresent,
          ),
          const SizedBox(width: 6),
          _AttendanceButton(
            label: 'غائب',
            icon: Icons.close_rounded,
            selected: !present,
            selectedColor: AppColors.error,
            onTap: onAbsent,
          ),
        ],
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedColor : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : AppColors.inkMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== حالات فرعية ====================

class _HistoryEmpty extends StatelessWidget {
  final VoidCallback onAdd;

  const _HistoryEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        children: [
          const Icon(Icons.history_toggle_off_rounded,
              size: 40, color: AppColors.inkMuted),
          const SizedBox(height: 10),
          Text(
            'لا توجد دروس مسجلة بعد',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'اضغط "إضافة درس يومي" للبدء',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
