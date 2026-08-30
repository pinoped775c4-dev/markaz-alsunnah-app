import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/lesson.dart';
import '../../models/student.dart';
import '../../services/lessons_service.dart';
import '../../services/students_service.dart';
import '../../widgets/common_widgets.dart';

/// تبويب الدروس: إعداد أولي أو وضع يومي كامل
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

class _LessonsTabState extends State<LessonsTab> {
  final LessonsService _lessonsService = LessonsService();
  final StudentsService _studentsService = StudentsService();

  int _retryTick = 0;

  /// الدرس المُنشأ محليًا (تحديث متفائل) — يُعرض فورًا بعد إعداد الدرس
  /// قبل وصول أول snapshot من البث، حتى لا يبدو أن الإضافة "لم تُسجّل".
  Lesson? _optimisticLesson;

  /// نتيجة التشخيص اليدوي (جلب get مباشر) — تظهر تحت مؤشر التحميل
  /// لنعرف فورًا هل البيانات موجودة أم لا، وما الخطأ الحقيقي إن وُجد
  String? _autoDiagnosis;

  @override
  void initState() {
    super.initState();
    // جلب يدوي مباشر بالتوازي مع البث: إن نجح فالبيانات موجودة والبث
    // سيلحق بها، وإن فشل نكشف الخطأ الحقيقي فورًا بدل الانتظار الأعمى
    Future.delayed(const Duration(seconds: 2), _autoCheck);
  }

  Future<void> _autoCheck() async {
    if (!mounted || widget.teacherId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lessons')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get()
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final matching =
          snap.docs.where((d) => d.data()['pathwayId'] == widget.pathway.id);
      setState(() {
        if (snap.docs.isEmpty) {
          _autoDiagnosis = 'الاتصال سليم — لا توجد دروس مسجلة لهذا الحساب بعد.\n'
              'أنشئ درسك الأول من بطاقة الإعداد أدناه.';
        } else if (matching.isEmpty) {
          _autoDiagnosis = 'الاتصال سليم — لديك ${snap.docs.length} درسًا '
              'لكن لا يطابق أحدها هذا المسار (${widget.pathway.id}).';
        } else {
          _autoDiagnosis = 'البيانات موجودة (${matching.length} درس) '
              '— انتظر لحظة تحميل البث.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        if (msg.contains('permission')) {
          _autoDiagnosis = '❌ رفض الوصول من قاعدة البيانات (PERMISSION_DENIED).\n'
              'قواعد Firestore تمنع القراءة — يجب تعديلها من لوحة Firebase.';
        } else {
          _autoDiagnosis = 'تعذّر الفحص: $msg';
        }
      });
    }
  }

  /// بث الدرس مباشرة بلا مهلة زمنية — الاستعلام بسيط (شرط واحد)
  /// فيستجيب فورًا من Firestore أو من الكاش المحلي عند انقطاع النت.
  /// أي خطأ حقيقي (مثل رفق الصلاحيات) يظهر فورًا عبر snapshot.hasError.
  Stream<Lesson?> _lessonStream() {
    return _lessonsService.watchPathwayLesson(
      teacherId: widget.teacherId,
      pathwayId: widget.pathway.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    // حماية من الحالة التي تُفتح فيها الصفحة قبل اكتمال جلسة المعلم —
    // teacherId الفارغ كان يسبب استعلامًا معلقًا بلا نتيجة ولا خطأ
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

    // الاعتماد على _retryTick يجبر إعادة إنشاء الـ Stream عند إعادة المحاولة
    return KeyedSubtree(
      key: ValueKey(_retryTick),
      child: StreamBuilder<Lesson?>(
        stream: _lessonStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('LessonsTab stream error: ${snapshot.error}');
            final isPermission =
                snapshot.error.toString().contains('permission');
            return ErrorState(
              message: isPermission
                  ? 'تم رفض الوصول من قاعدة البيانات.\n'
                      'تأكد من قواعد أمان Firestore (تطلب تسجيل الدخول).\n\n'
                      'التفاصيل: ${snapshot.error}'
                  : 'تعذّر تحميل بيانات الدرس.\n'
                      'تحقق من الاتصال بالإنترنت ثم أعد المحاولة.\n\n'
                      'التفاصيل: ${snapshot.error}',
              onRetry: () => setState(() => _retryTick++),
            );
          }

          if (!snapshot.hasData) {
            return _LessonLoadingView(
              teacherId: widget.teacherId,
              pathwayId: widget.pathway.id,
              autoDiagnosis: _autoDiagnosis,
            );
          }

          final lesson = snapshot.data;

          // أول مرة: بطاقة الإعداد الأولي
          if (lesson == null) {
            // تحديث متفائل: إذا أنشأ المعلم الدرس للتوّ نعرض الوضع اليومي
            // فورًا حتى لو لم يصل snapshot البث بعد (كان هذا سبب "عدم الظهور")
            if (_optimisticLesson != null) {
              return _DailyLessonMode(
                pathway: widget.pathway,
                lesson: _optimisticLesson!,
                lessonsService: _lessonsService,
                studentsService: _studentsService,
              );
            }
            return _LessonSetupCard(
              pathway: widget.pathway,
              teacherId: widget.teacherId,
              service: _lessonsService,
              onLessonCreated: (created) {
                setState(() => _optimisticLesson = created);
              },
            );
          }

          // الوضع اليومي
          return _DailyLessonMode(
            pathway: widget.pathway,
            lesson: lesson,
            lessonsService: _lessonsService,
            studentsService: _studentsService,
          );
        },
      ),
    );
  }
}

// ==================== بطاقة الإعداد الأولي ====================

class _LessonSetupCard extends StatefulWidget {
  final PathwayInfo pathway;
  final String teacherId;
  final LessonsService service;
  final void Function(Lesson lesson) onLessonCreated;

  const _LessonSetupCard({
    required this.pathway,
    required this.teacherId,
    required this.service,
    required this.onLessonCreated,
  });

  @override
  State<_LessonSetupCard> createState() => _LessonSetupCardState();
}

class _LessonSetupCardState extends State<_LessonSetupCard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalController = TextEditingController();
  String _type = 'nazm';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await widget.service.setupLesson(
      teacherId: widget.teacherId,
      pathwayId: widget.pathway.id,
      name: _nameController.text,
      type: _type,
      totalCount: int.parse(_totalController.text.trim()),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // عرض متفائل فوري: نرفع الدرس المُنشأ للتاب الأب ليُظهر الوضع
      // اليومي فورًا — لا ننتظر وصول snapshot البث (كان سبب الخلل).
      if (result.lesson != null) {
        widget.onLessonCreated(result.lesson!);
      }
      showSuccessSnackBar(context, 'تم إعداد الدرس بنجاح، ابدأ بتسجيل الدروس اليومية');
    } else {
      showErrorSnackBar(context, result.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 88,
              height: 88,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.primaryBorder, width: 1.5),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  size: 42, color: AppColors.primary),
            ),
            Text(
              'إعداد درس المسار',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'عرّف الدرس الذي ستتابعه في "${widget.pathway.name}"\nثم ابدأ بتسجيل الحصص اليومية',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.lineSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // اسم الدرس
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدرس *',
                      hintText: 'مثال: متن الآجرومية',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'اسم الدرس مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // نوع الدرس
                  Text('نوع الدرس *', style: textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeOption(
                          label: 'نظم',
                          subtitle: 'يُقاس بالأبيات',
                          icon: Icons.format_list_numbered_rounded,
                          selected: _type == 'nazm',
                          onTap: () => setState(() => _type = 'nazm'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeOption(
                          label: 'نثر',
                          subtitle: 'يُقاس بالصفحات',
                          icon: Icons.article_outlined,
                          selected: _type == 'nathr',
                          onTap: () => setState(() => _type = 'nathr'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // العدد الإجمالي
                  TextFormField(
                    controller: _totalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          'العدد الإجمالي (${_type == 'nazm' ? 'الأبيات' : 'الصفحات'}) *',
                      prefixIcon:
                          const Icon(Icons.format_list_numbered_rtl_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'العدد الإجمالي مطلوب';
                      }
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) {
                        return 'أدخل رقماً صحيحاً أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ والبدء'),
            ),
          ],
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

// ==================== الوضع اليومي ====================

class _DailyLessonMode extends StatelessWidget {
  final PathwayInfo pathway;
  final Lesson lesson;
  final LessonsService lessonsService;
  final StudentsService studentsService;

  const _DailyLessonMode({
    required this.pathway,
    required this.lesson,
    required this.lessonsService,
    required this.studentsService,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ===== البطاقة الكبيرة الثابتة =====
        _BigLessonCard(lesson: lesson),
        const SizedBox(height: 16),

        // ===== زر إضافة درس يومي =====
        ElevatedButton.icon(
          onPressed: () => _showAddDailyLessonDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة درس يومي'),
        ),
        const SizedBox(height: 24),

        // ===== سجل الدروس =====
        SectionHeader(
          title: 'سجل الدروس اليومية',
          subtitle: 'الأحدث أولاً',
        ),

        StreamBuilder<List<LessonRecording>>(
          stream: lessonsService.watchRecordings(
            teacherId: lesson.teacherId,
            lessonId: lesson.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _MiniError(
                message: 'حدث خطأ أثناء تحميل السجل',
                onRetry: () {},
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final recordings = snapshot.data!;
            if (recordings.isEmpty) {
              return _HistoryEmpty(
                onAdd: () => _showAddDailyLessonDialog(context),
              );
            }

            return Column(
              children: recordings
                  .map((r) => _RecordingCard(
                        recording: r,
                        lesson: lesson,
                        service: lessonsService,
                        onEdit: () => _showEditRecordingDialog(context, r),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showAddDailyLessonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DailyLessonDialog(
        pathway: pathway,
        lesson: lesson,
        lessonsService: lessonsService,
        studentsService: studentsService,
      ),
    );
  }

  void _showEditRecordingDialog(
      BuildContext context, LessonRecording recording) {
    showDialog(
      context: context,
      builder: (_) => _DailyLessonDialog(
        pathway: pathway,
        lesson: lesson,
        lessonsService: lessonsService,
        studentsService: studentsService,
        editing: recording,
      ),
    );
  }
}

// ==================== البطاقة الكبيرة ====================

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

  const _DailyLessonDialog({
    required this.pathway,
    required this.lesson,
    required this.lessonsService,
    required this.studentsService,
    this.editing,
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
      _fromController.text = '${e.from}';
      _toController.text = '${e.to}';
      _notesController.text = e.notes ?? '';
    } else {
      // تعبئة "من" تلقائياً بالنقطة التالية غير المنجزة
      final nextFrom = widget.lesson.completedCount + 1;
      if (nextFrom <= widget.lesson.totalCount) {
        _fromController.text = '$nextFrom';
      }
    }
    _loadStudents();
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

  int? get _autoCount {
    final from = int.tryParse(_fromController.text.trim());
    final to = int.tryParse(_toController.text.trim());
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

    final from = int.parse(_fromController.text.trim());
    final to = int.parse(_toController.text.trim());

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
      Navigator.pop(context);
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
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'من (${widget.lesson.unitLabel}) *',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'مطلوب';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _toController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'إلى (${widget.lesson.unitLabel}) *',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'مطلوب';
                          final from =
                              int.tryParse(_fromController.text.trim());
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
                            count != null ? '$count' : '—',
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
                    '${recording.from} ← ${recording.to} (${recording.count} ${lesson.unitLabel})',
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
          'سيتم حذف هذا التسجيل وإرجاع ${recording.count} ${lesson.unitLabel} من العداد.\nهل أنت متأكد؟',
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

/// عرض تحميل دائري مع زر تشخيص مباشر يجلب البيانات يدويًا من Firestore
/// ويعرض النتيجة الفعلية على الشاشة — لكشف السبب الحقيقي لأي تعليق
class _LessonLoadingView extends StatefulWidget {
  final String teacherId;
  final String pathwayId;
  final String? autoDiagnosis;

  const _LessonLoadingView({
    required this.teacherId,
    required this.pathwayId,
    this.autoDiagnosis,
  });

  @override
  State<_LessonLoadingView> createState() => _LessonLoadingViewState();
}

class _LessonLoadingViewState extends State<_LessonLoadingView> {
  bool _showHint = false;
  bool _diagnosing = false;
  String? _diagnosis;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showHint = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// جلب يدوي مباشر (get) بدل البث — يكشف أي خطأ فورًا
  Future<void> _runDiagnosis() async {
    setState(() {
      _diagnosing = true;
      _diagnosis = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lessons')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get()
          .timeout(const Duration(seconds: 15));

      final matching =
          snap.docs.where((d) => d.data()['pathwayId'] == widget.pathwayId);

      setState(() {
        _diagnosing = false;
        if (snap.docs.isEmpty) {
          _diagnosis = '✅ الاتصال يعمل، لكن لا توجد دروس لهذا الحساب إطلاقًا.\n'
              'معرّف المعلم: ${widget.teacherId}\n'
              'عدد الدروس الكلي للحساب: 0';
        } else if (matching.isEmpty) {
          _diagnosis = '✅ الاتصال يعمل.\n'
              'دروس الحساب: ${snap.docs.length} — لكن لا يطابق أحدها هذا المسار.\n'
              'معرّف المسار المطلوب: ${widget.pathwayId}\n'
              'المسارات الموجودة: ${snap.docs.map((d) => d.data()['pathwayId']).join('، ')}';
        } else {
          _diagnosis = '✅ البيانات موجودة (${matching.length} درس مطابق)!\n'
              'المشكلة في البث فقط — أعد فتح الصفحة وستعمل.';
        }
      });
    } catch (e) {
      setState(() {
        _diagnosing = false;
        final msg = e.toString();
        if (msg.contains('permission')) {
          _diagnosis = '❌ رفض الوصول (PERMISSION_DENIED).\n'
              'قواعد Firestore تمنع القراءة — الحل: لوحة Firebase →\n'
              'Firestore → Rules → اجعلها تسمح للمستخدمين المسجلين.\n\n'
              'التفاصيل: $msg';
        } else if (msg.contains('index')) {
          _diagnosis = '❌ الفهرس المركب مفقود.\nالتفاصيل: $msg';
        } else {
          _diagnosis = '❌ خطأ في الجلب:\n$msg';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_showHint) ...[
              const SizedBox(height: 18),
              const Text(
                'يستغرق التحميل وقتاً أطول من المعتاد...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.inkMuted, height: 1.6),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _diagnosing ? null : _runDiagnosis,
                icon: _diagnosing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.troubleshoot_rounded, size: 18),
                label: Text(_diagnosing ? 'جارٍ الفحص...' : 'فحص المشكلة'),
              ),
            ],
            // نتيجة التشخيص التلقائي أو اليدوي — تكشف السبب الحقيقي فورًا
            Builder(builder: (context) {
              final text = _diagnosis ?? widget.autoDiagnosis;
              if (text == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: SelectableText(
                    text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, height: 1.7),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MiniError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MiniError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
