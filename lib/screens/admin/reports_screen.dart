import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/lesson.dart';
import '../../models/matna.dart';
import '../../models/quran.dart';
import '../../models/student.dart';
import '../../services/report_pdf_service.dart';
import '../../services/reports_service.dart';
import '../../services/students_service.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';

/// شاشة تقارير الإدارة — الأقسام ← معلمو القسم ونشاطهم (دروس/متون/قرآن) ← يومي/أسبوعي/شهري
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TeachersService _teachersService = TeachersService();
  final ReportsService _reportsService = ReportsService();

  @override
  Widget build(BuildContext context) {
    // كل الأقسام — بما فيها مسار القرآن الكريم
    final pathways = AppConstants.pathways;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التقارير'),
            Text(
              'اختر قسماً لعرض تقارير معلميه',
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
      body: WatermarkedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
          children: [
            const SectionHeader(
              title: 'الأقسام التعليمية',
              subtitle: 'اضغط على قسم لعرض معلميه وتقاريرهم',
            ),
            const SizedBox(height: 4),
            // ===== الأقسام بأيقونات دائرية (صفوف × عمودان) =====
            for (var row = 0; row * 2 < pathways.length; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < 2; col++)
                      if (row * 2 + col < pathways.length)
                        _PathwayReportItem(
                          pathway: pathways[row * 2 + col],
                          teachersService: _teachersService,
                          reportsService: _reportsService,
                        )
                      else
                        const Expanded(child: SizedBox()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== عنصر قسم (أيقونة دائرية) ====================

class _PathwayReportItem extends StatelessWidget {
  final PathwayInfo pathway;
  final TeachersService teachersService;
  final ReportsService reportsService;

  const _PathwayReportItem({
    required this.pathway,
    required this.teachersService,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageAsset = AppConstants.pathwayImageAsset(pathway.id);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PathwayTeachersScreen(
                pathway: pathway,
                teachersService: teachersService,
                reportsService: reportsService,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.goldSoft, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageAsset != null
                      ? Image.asset(
                          imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(),
                        )
                      : _fallback(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                pathway.name,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall
                    ?.copyWith(fontSize: 13, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(
                'تقارير المعلمين',
                style: textTheme.bodySmall
                    ?.copyWith(fontSize: 10.5, color: AppColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.primarySurface,
        child: const Icon(Icons.school_rounded,
            color: AppColors.primary, size: 36),
      );
}

// ==================== شاشة معلمي القسم ====================

class PathwayTeachersScreen extends StatelessWidget {
  final PathwayInfo pathway;
  final TeachersService teachersService;
  final ReportsService reportsService;

  const PathwayTeachersScreen({
    super.key,
    required this.pathway,
    required this.teachersService,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pathway.name),
            Text(
              'معلمو القسم ونشاطهم في هذا القسم',
              style:
                  TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        // دمج مصادر النشاط: دروس + متون + تسجيلات قرآن
        child: StreamBuilder<List<Lesson>>(
          stream: pathway.hasLessons
              ? reportsService.watchPathwayLessons(pathway.id)
              : Stream.value(const <Lesson>[]),
          builder: (context, lessonsSnap) {
            return StreamBuilder<List<Matna>>(
              stream: pathway.hasMutun
                  ? reportsService.watchPathwayMutun(pathway.id)
                  : Stream.value(const <Matna>[]),
              builder: (context, mutunSnap) {
                return StreamBuilder<List<QuranRecording>>(
                  stream: pathway.hasQuran
                      ? reportsService
                          .watchPathwayQuranRecordings(pathway.id)
                      : Stream.value(const <QuranRecording>[]),
                  builder: (context, quranSnap) {
                    if (lessonsSnap.hasError ||
                        mutunSnap.hasError ||
                        quranSnap.hasError) {
                      return ErrorState(
                        message: 'حدث خطأ أثناء تحميل نشاط القسم',
                        onRetry: () {},
                      );
                    }
                    if (!lessonsSnap.hasData ||
                        !mutunSnap.hasData ||
                        !quranSnap.hasData) {
                      return const ListSkeleton(itemCount: 3);
                    }

                    // مجمّعة حسب المعلم — من المصادر الثلاثة
                    final lessonsByTeacher = <String, List<Lesson>>{};
                    for (final l in lessonsSnap.data!) {
                      lessonsByTeacher
                          .putIfAbsent(l.teacherId, () => [])
                          .add(l);
                    }
                    final mutunByTeacher = <String, List<Matna>>{};
                    for (final m in mutunSnap.data!) {
                      mutunByTeacher
                          .putIfAbsent(m.teacherId, () => [])
                          .add(m);
                    }
                    final quranByTeacher = <String, List<QuranRecording>>{};
                    for (final r in quranSnap.data!) {
                      quranByTeacher
                          .putIfAbsent(r.teacherId, () => [])
                          .add(r);
                    }

                    // اتحاد معرفات المعلمين (بدون تكرار) ثم فرز أبجدي
                    final teacherIds = {
                      ...lessonsByTeacher.keys,
                      ...mutunByTeacher.keys,
                      ...quranByTeacher.keys,
                    }.toList();

                    if (teacherIds.isEmpty) {
                      return EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'لا يوجد نشاط في هذا القسم',
                        message:
                            'لم يسجّل أي معلم نشاطاً في "${pathway.name}" بعد',
                      );
                    }

                    return StreamBuilder<List<AppUser>>(
                      stream: teachersService.watchTeachers(),
                      builder: (context, teachersSnap) {
                        final teachers = teachersSnap.data ?? [];
                        final names = {
                          for (final t in teachers) t.uid: t.name,
                        };

                        teacherIds.sort((a, b) =>
                            (names[a] ?? 'م')
                                .compareTo(names[b] ?? 'م'));

                        return ListView.builder(
                          padding:
                              const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: teacherIds.length,
                          itemBuilder: (context, index) {
                            final teacherId = teacherIds[index];
                            final name = names[teacherId] ?? 'معلم';
                            return _TeacherLessonsTile(
                              teacherId: teacherId,
                              teacherName: name,
                              lessons:
                                  lessonsByTeacher[teacherId] ?? const [],
                              mutun:
                                  mutunByTeacher[teacherId] ?? const [],
                              quranRecordings:
                                  quranByTeacher[teacherId] ?? const [],
                              pathway: pathway,
                              reportsService: reportsService,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TeacherLessonsTile extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final List<Lesson> lessons;
  final List<Matna> mutun;
  final List<QuranRecording> quranRecordings;
  final PathwayInfo pathway;
  final ReportsService reportsService;

  const _TeacherLessonsTile({
    required this.teacherId,
    required this.teacherName,
    required this.lessons,
    required this.mutun,
    required this.quranRecordings,
    required this.pathway,
    required this.reportsService,
  });

  /// نص ملخص نشاط المعلم (دروس + متون + قرآن)
  String get _activitySummary {
    final parts = <String>[];
    if (lessons.isNotEmpty) {
      parts.add(lessons.length == 1
          ? 'درس واحد'
          : '${lessons.length} دروس');
    }
    if (mutun.isNotEmpty) {
      parts.add(mutun.length == 1
          ? 'متن واحد'
          : '${mutun.length} متون');
    }
    if (quranRecordings.isNotEmpty) {
      parts.add('قرآن');
    }
    if (parts.isEmpty) return 'لا يوجد نشاط';
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: InitialAvatar(name: teacherName),
          title: Text(teacherName, style: textTheme.titleSmall),
          subtitle: Text(_activitySummary, style: textTheme.bodySmall),
          children: [
            // ===== زر طلاب المعلم (المهمة 3) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherStudentsScreen(
                      teacherId: teacherId,
                      teacherName: teacherName,
                      pathway: pathway,
                      reportsService: reportsService,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تقارير الطلاب',
                          style: textTheme.titleSmall
                              ?.copyWith(fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_left_rounded,
                          size: 22, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),

            // ===== الدروس =====
            for (final lesson in lessons)
              _LessonTile(
                lesson: lesson,
                teacherName: teacherName,
                pathwayName: pathway.name,
                reportsService: reportsService,
              ),

            // ===== المتون =====
            for (final matna in mutun)
              _MutunTile(
                matna: matna,
                teacherName: teacherName,
                pathwayName: pathway.name,
                reportsService: reportsService,
              ),

            // ===== القرآن (تقرير واحد لكل معلم في المسار) =====
            if (quranRecordings.isNotEmpty)
              _QuranTile(
                teacherId: teacherId,
                teacherName: teacherName,
                pathway: pathway,
                reportsService: reportsService,
              ),

            if (lessons.isEmpty && mutun.isEmpty && quranRecordings.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  'لا يوجد نشاط مسجّل لهذا المعلم',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ==================== بطاقة درس داخل المعلم ====================

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final String teacherName;
  final String pathwayName;
  final ReportsService reportsService;

  const _LessonTile({
    required this.lesson,
    required this.teacherName,
    required this.pathwayName,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LessonReportScreen(
                  lesson: lesson,
                  teacherName: teacherName,
                  pathwayName: pathwayName,
                  reportsService: reportsService,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    lesson.isNazm
                        ? Icons.format_list_numbered_rounded
                        : Icons.article_rounded,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.name, style: textTheme.titleSmall),
                      const SizedBox(height: 3),
                      Text(
                        lesson.typeLabel,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: lesson.progress,
                          minHeight: 6,
                          backgroundColor: AppColors.lineSoft,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  '${lesson.progressPercent}%',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== شاشة تقرير الدرس (يومي + أسبوعي + شهري) ====================

class LessonReportScreen extends StatefulWidget {
  final Lesson lesson;
  final String teacherName;
  final String pathwayName;
  final ReportsService reportsService;

  const LessonReportScreen({
    super.key,
    required this.lesson,
    required this.teacherName,
    required this.pathwayName,
    required this.reportsService,
  });

  @override
  State<LessonReportScreen> createState() => _LessonReportScreenState();
}

class _LessonReportScreenState extends State<LessonReportScreen> {
  final ScrollController _scrollController = ScrollController();

  // مفاتيح البطاقات اليومية للانتقال التلقائي إلى اليوم الحالي
  final Map<String, GlobalKey> _dayKeys = {};

  Future<List<LessonDayReport>>? _future;

  // أيام غياب المعلم (المهمة 4) — تُحمّل مرة واحدة مع التقرير
  Future<List<TeacherAbsence>>? _absencesFuture;

  // البحث بالتاريخ — null يعني عرض كل الدروس اليومية
  DateTime? _searchDate;

  @override
  void initState() {
    super.initState();
    _future = widget.reportsService.buildLessonDailyReports(widget.lesson);
    _absencesFuture = widget.reportsService.buildTeacherAbsenceDays(
      teacherId: widget.lesson.teacherId,
      pathwayId: widget.lesson.pathwayId,
      lessonId: widget.lesson.id,
    );
  }

  /// نافذة اختيار تاريخ البحث عن الدروس اليومية
  Future<void> _pickSearchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _searchDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'ابحث عن دروس يوم معيّن',
      cancelText: 'إلغاء',
      confirmText: 'بحث',
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    setState(() => _searchDate = picked);
  }

  /// قاعدة ظهور التقارير الأسبوعية/الشهرية لحساب الإدارة:
  /// - الأسبوعي: يظهر يوم الجمعة بعد الساعة 6 صباحاً أو بعد نهاية الأسبوع
  /// - الشهري: يظهر فقط بعد نهاية الشهر
  /// - زر PDF للأسبوع/الشهر الحالي الجاري لا يظهر أبداً قبل انتهاء الفترة
  static ({List<PeriodCard> weeks, List<PeriodCard> months}) _adminPeriods(
    ({List<PeriodCard> weeks, List<PeriodCard> months}) periods,
  ) {
    final now = DateTime.now();

    // الأسبوعي: المنتهي دائماً يظهر؛ الجاري يظهر فقط يوم الجمعة 6 صباحاً أو بعده
    final visibleWeeks = periods.weeks.where((w) {
      if (!w.isCurrent) return true; // منتهٍ — يظهر
      return now.weekday == 5 && now.hour >= 6; // جمعة 6 صباحاً أو بعدها
    }).toList();

    // الشهري: المنتهي فقط (بطاقة الشهر الجاري isCurrent لا تظهر أبداً)
    final visibleMonths = periods.months.where((m) => !m.isCurrent).toList();

    return (weeks: visibleWeeks, months: visibleMonths);
  }

  /// فلترة الدروس اليومية بحسب تاريخ البحث المختار
  static List<LessonDayReport> _filterByDate(
    List<LessonDayReport> reports,
    DateTime? date,
  ) {
    if (date == null) return reports;
    return reports
        .where((r) => DateUtils.isSameDay(r.date, date))
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// الانتقال تلقائياً إلى بطاقة اليوم الحالي بعد البناء
  /// (يُستدعى فقط في وضع العرض الكامل — الأحدث في الأعلى)
  void _scrollToToday(List<LessonDayReport> reportsDesc) {
    final now = DateTime.now();
    LessonDayReport? today;
    for (final r in reportsDesc) {
      if (DateUtils.isSameDay(r.date, now)) today = r;
    }
    // الأحدث أولًا (تصاعدي معكوس) — اليوم الحالي في القمة، وإلا أول بطاقة
    final target = today ?? (reportsDesc.isEmpty ? null : reportsDesc.first);
    if (target == null) return;

    final key = _dayKeys[target.recording.id];
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.lesson.name),
            Text(
              '${widget.teacherName} • ${widget.pathwayName}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: [
          // زر البحث بالتاريخ
          IconButton(
            tooltip: _searchDate == null
                ? 'بحث بالتاريخ'
                : 'إلغاء البحث بالتاريخ',
            onPressed: () {
              if (_searchDate != null) {
                setState(() => _searchDate = null);
              } else {
                _pickSearchDate();
              }
            },
            icon: _searchDate == null
                ? const Icon(Icons.calendar_month_outlined)
                : const Icon(Icons.filter_alt_off_rounded),
          ),
          IconButton(
            tooltip: 'بحث بالتاريخ',
            onPressed: _pickSearchDate,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: WatermarkedBackground(
        child: FutureBuilder<List<LessonDayReport>>(
          future: _future,
          builder: (context, snapshot) {
            final textTheme = Theme.of(context).textTheme;
            if (snapshot.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل التقرير',
                onRetry: () => setState(() {
                  _future = widget.reportsService
                      .buildLessonDailyReports(widget.lesson);
                }),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // ترتيب تنازلي: الأحدث في الأعلى والأقدم في الأسفل
            final reportsDesc = snapshot.data!.reversed.toList();
            if (reportsDesc.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد تسجيلات يومية',
                message: 'لم يسجّل المعلم أي درس يومي بعد',
              );
            }

            // فلترة الدروس اليومية بحسب تاريخ البحث (إن وُجد)
            final visibleReports = _filterByDate(reportsDesc, _searchDate);

            // جهّز مفاتيح البطاقات
            _dayKeys.clear();
            for (final r in visibleReports) {
              _dayKeys[r.recording.id] = GlobalKey();
            }

            // البطاقات الأسبوعية والشهرية — بقاعدة ظهور الإدارة:
            // لا تظهر إلا بعد انتهاء الفترة (جمعة 6ص للأسبوعي، نهاية الشهر للشهري)
            final periods = _adminPeriods(
              widget.reportsService.buildPeriodCards(
                lesson: widget.lesson,
                dailyReports: snapshot.data!,
              ),
            );

            if (_searchDate == null) _scrollToToday(visibleReports);

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                // ===== شريط البحث بالتاريخ =====
                if (_searchDate != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نتائج البحث: ${DateFormat('d MMMM y', 'ar').format(_searchDate!)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _searchDate = null),
                          child: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                  ),
                ],

                // ===== التقارير اليومية =====
                SectionHeader(
                  title: _searchDate == null
                      ? 'التقرير اليومي'
                      : 'نتائج البحث — ${visibleReports.length} درس',
                  subtitle: _searchDate == null
                      ? 'الأحدث في الأعلى — اضغط للتفاصيل'
                      : 'دروس يوم ${DateFormat('d/M/y', 'ar').format(_searchDate!)}',
                ),
                if (visibleReports.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج',
                    message: 'لا يوجد درس يومي في هذا التاريخ',
                  )
                else
                  for (final report in visibleReports)
                    _DailyReportCard(
                      key: _dayKeys[report.recording.id],
                      report: report,
                      lesson: widget.lesson,
                      isToday: DateUtils.isSameDay(
                          report.date, DateTime.now()),
                    ),

                // ===== التقارير الأسبوعية =====
                if (periods.weeks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'التقارير الأسبوعية',
                    subtitle: 'كل أسبوع منتهٍ في بطاقة — مع تصدير PDF',
                  ),
                  for (final week in periods.weeks)
                    _PeriodCardTile(
                      period: week,
                      icon: Icons.date_range_rounded,
                      dailyReports: reportsDesc,
                      lesson: widget.lesson,
                      teacherName: widget.teacherName,
                      pathwayName: widget.pathwayName,
                    ),
                ],

                // ===== التقارير الشهرية =====
                if (periods.months.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'التقارير الشهرية',
                    subtitle: 'كل شهر منتهٍ في بطاقة — مع تصدير PDF',
                  ),
                  for (final month in periods.months)
                    _PeriodCardTile(
                      period: month,
                      icon: Icons.calendar_month_rounded,
                      dailyReports: reportsDesc,
                      lesson: widget.lesson,
                      teacherName: widget.teacherName,
                      pathwayName: widget.pathwayName,
                    ),
                ],

                // ===== أيام غياب المعلم (المهمة 4) =====
                if (_searchDate == null)
                  FutureBuilder<List<TeacherAbsence>>(
                    future: _absencesFuture,
                    builder: (context, absSnap) {
                      if (!absSnap.hasData || absSnap.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          _TeacherAbsenceSection(absences: absSnap.data!),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ==================== بطاقة التقرير اليومي ====================

class _DailyReportCard extends StatelessWidget {
  final LessonDayReport report;
  final Lesson lesson;
  final bool isToday;

  const _DailyReportCard({
    super.key,
    required this.report,
    required this.lesson,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText = DateFormat('d MMMM y', 'ar').format(report.date);
    final attendancePct = (report.attendanceRate * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isToday ? AppColors.primary : AppColors.lineSoft,
          width: isToday ? 1.6 : 1,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
                builder: (_) => DayDetailScreen(
                  report: report,
                  lesson: lesson,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primarySurface
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${report.recording.weekday}، $dateText',
                        style: textTheme.bodySmall?.copyWith(
                          color: isToday
                              ? AppColors.primaryDark
                              : AppColors.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'اليوم',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color:
                            AppColors.inkMuted.withValues(alpha: 0.6)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.how_to_reg_rounded,
                      label: 'الحضور',
                      value: '$attendancePct%',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'المنجز',
                      value:
                          '${fmtNum(report.recording.count)} ${lesson.unitLabel}',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.trending_up_rounded,
                      label: 'الإنجاز',
                      value:
                          '${(report.completionRate * 100).round()}%',
                      color: AppColors.gold,
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== بطاقة الفترة (أسبوع/شهر) مع تصدير PDF ====================

class _PeriodCardTile extends StatefulWidget {
  final PeriodCard period;
  final IconData icon;
  final List<LessonDayReport> dailyReports;
  final Lesson lesson;
  final String teacherName;
  final String pathwayName;

  const _PeriodCardTile({
    required this.period,
    required this.icon,
    required this.dailyReports,
    required this.lesson,
    required this.teacherName,
    required this.pathwayName,
  });

  @override
  State<_PeriodCardTile> createState() => _PeriodCardTileState();
}

class _PeriodCardTileState extends State<_PeriodCardTile> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      await ReportPdfService.exportPeriodPdf(
        period: widget.period,
        lesson: widget.lesson,
        dailyReports: widget.dailyReports,
        teacherName: widget.teacherName,
        pathwayName: widget.pathwayName,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'تعذّر إنشاء ملف PDF، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final period = widget.period;
    final report = period.report;
    final attendancePct = report.attendanceRates.values.isEmpty
        ? 0
        : (report.attendanceRates.values.fold(0.0, (s, v) => s + v) /
                report.attendanceRates.length *
                100)
            .round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: period.isCurrent
              ? AppColors.gold
              : AppColors.lineSoft,
          width: period.isCurrent ? 1.6 : 1,
        ),
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
                builder: (_) => PeriodDetailScreen(
                  period: period,
                  lesson: widget.lesson,
                  dailyReports: widget.dailyReports,
                  teacherName: widget.teacherName,
                  pathwayName: widget.pathwayName,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: period.isCurrent
                        ? AppColors.goldSurface
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    widget.icon,
                    color: period.isCurrent
                        ? AppColors.goldDark
                        : AppColors.primary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(period.title,
                                style: textTheme.titleSmall),
                          ),
                          if (period.isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'جديد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(period.subtitle,
                          style: textTheme.bodySmall),
                      const SizedBox(height: 5),
                      Text(
                        'المنجز: ${fmtNum(report.unitsAccomplished)} وحدة • الحضور: $attendancePct%',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // زر تصدير PDF
                IconButton(
                  tooltip: 'تصدير PDF للطباعة',
                  visualDensity: VisualDensity.compact,
                  onPressed: _exporting ? null : _exportPdf,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded,
                          size: 21, color: AppColors.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== شاشة تفاصيل اليوم ====================

class DayDetailScreen extends StatelessWidget {
  final LessonDayReport report;
  final Lesson lesson;

  const DayDetailScreen({
    super.key,
    required this.report,
    required this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText =
        DateFormat('EEEE، d MMMM y', 'ar').format(report.date);
    final attendancePct = (report.attendanceRate * 100).round();
    final completionPct =
        (report.completionRate * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.recording.weekday),
            Text(
              dateText,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // ===== ملخص الدرس =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.name,
                    style: textTheme.titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'من ${fmtNum(report.recording.from)} إلى ${fmtNum(report.recording.to)}'
                    ' (${fmtNum(report.recording.count)} ${lesson.unitLabel})'
                    ' • المدة: ${report.recording.duration}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ===== الرسم البياني =====
            _RatesChartCard(
              attendancePct: attendancePct,
              completionPct: completionPct,
            ),
            const SizedBox(height: 14),

            // ===== نسبة حضور الطلاب =====
            Container(
              padding: const EdgeInsets.all(16),
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
                      const Icon(Icons.how_to_reg_rounded,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text('حضور الطلاب',
                          style: textTheme.titleSmall),
                      const Spacer(),
                      Text(
                        '${report.presentCount}/${report.totalStudents}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: report.attendanceRate,
                      minHeight: 9,
                      backgroundColor: AppColors.lineSoft,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ===== الغائبون =====
            if (report.absentNames.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_off_outlined,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'الطلاب الغائبون (${report.absentNames.length})',
                          style: textTheme.titleSmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in report.absentNames)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.error
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.close_rounded,
                                    size: 13,
                                    color: AppColors.error),
                                const SizedBox(width: 4),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.celebration_rounded,
                        color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'حضور كامل — لا يوجد غائبون في هذا اليوم',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ===== ملاحظات =====
            if (report.recording.notes != null &&
                report.recording.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.lineSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ملاحظات المعلم',
                        style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(report.recording.notes!,
                        style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// رسم بياني لنسبتي الحضور والإنجاز
class _RatesChartCard extends StatelessWidget {
  final int attendancePct;
  final int completionPct;

  const _RatesChartCard({
    required this.attendancePct,
    required this.completionPct,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        children: [
          Text('ملخص بياني', style: textTheme.titleSmall),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RatePie(
                  label: 'الحضور',
                  pct: attendancePct,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RatePie(
                  label: 'الإنجاز',
                  pct: completionPct,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// مخطط دائري لنسبة مئوية واحدة مع النسبة في المنتصف
class _RatePie extends StatelessWidget {
  final String label;
  final int pct;
  final Color color;

  const _RatePie({
    required this.label,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = pct < 0 ? 0 : (pct > 100 ? 100 : pct);
    final textTheme = Theme.of(context).textTheme;
    final remaining = 100.0 - clamped;

    return Column(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: 270,
                  sectionsSpace: 0,
                  centerSpaceRadius: 34,
                  sections: [
                    PieChartSectionData(
                      value: clamped.toDouble(),
                      color: color,
                      radius: 12,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: remaining <= 0 ? 0.0001 : remaining,
                      color: AppColors.lineSoft,
                      radius: 12,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$clamped%',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ==================== شاشة تفاصيل الفترة (أسبوع/شهر) ====================

class PeriodDetailScreen extends StatefulWidget {
  final PeriodCard period;
  final Lesson lesson;
  final List<LessonDayReport> dailyReports;
  final String teacherName;
  final String pathwayName;

  const PeriodDetailScreen({
    super.key,
    required this.period,
    required this.lesson,
    required this.dailyReports,
    required this.teacherName,
    required this.pathwayName,
  });

  @override
  State<PeriodDetailScreen> createState() => _PeriodDetailScreenState();
}

class _PeriodDetailScreenState extends State<PeriodDetailScreen> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      await ReportPdfService.exportPeriodPdf(
        period: widget.period,
        lesson: widget.lesson,
        dailyReports: widget.dailyReports,
        teacherName: widget.teacherName,
        pathwayName: widget.pathwayName,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'تعذّر إنشاء ملف PDF، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodDays = widget.dailyReports.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return !d.isBefore(widget.period.start) &&
          !d.isAfter(widget.period.end);
    }).toList();

    final isWeek = widget.period.id.startsWith('week');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.period.title),
            Text(
              widget.period.subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: [
          // زر تصدير PDF
          IconButton(
            tooltip: 'تصدير PDF للطباعة',
            onPressed: _exporting ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
          ),
        ],
      ),
      body: WatermarkedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // ===== التقارير اليومية للفترة =====
            const SectionHeader(
              title: 'التقارير اليومية',
              subtitle: 'اضغط على أي يوم لعرض تفاصيله',
            ),
            if (periodDays.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text(
                  'لا توجد تسجيلات يومية في هذه الفترة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              )
            else
              for (final report in periodDays)
                _DailyReportCard(
                  report: report,
                  lesson: widget.lesson,
                  isToday: DateUtils.isSameDay(
                      report.date, DateTime.now()),
                ),

            // ===== ملخص الفترة في النهاية =====
            const SizedBox(height: 16),
            SectionHeader(
              title: isWeek ? 'ملخص الأسبوع' : 'ملخص الشهر',
              subtitle: 'المنجز + نسب الحضور',
            ),
            _PeriodSummaryCard(period: widget.period, lesson: widget.lesson),
          ],
        ),
      ),
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  final PeriodCard period;
  final Lesson lesson;

  const _PeriodSummaryCard({required this.period, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final report = period.report;

    final rates = report.attendanceRates.entries.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.goldSoft, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الملخص
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(period.title, style: textTheme.titleSmall),
                    Text(period.subtitle, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // المنجز
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered_rounded,
                    color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المنجز من الدرس',
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${fmtNum(report.unitsAccomplished)} ${lesson.unitLabel}',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // نسبة إنجاز الدرس
          Row(
            children: [
              Text('نسبة إنجاز الدرس',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${(report.completionRate * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: report.completionRate,
              minHeight: 9,
              backgroundColor: AppColors.lineSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.gold),
            ),
          ),

          // نسب حضور الطلاب
          if (rates.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('نسبة حضور الطلاب خلال الفترة',
                style: textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final entry in rates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          minHeight: 8,
                          backgroundColor: AppColors.lineSoft,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  AppColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(entry.value * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ==================== بطاقة متن داخل المعلم ====================

class _MutunTile extends StatelessWidget {
  final Matna matna;
  final String teacherName;
  final String pathwayName;
  final ReportsService reportsService;

  const _MutunTile({
    required this.matna,
    required this.teacherName,
    required this.pathwayName,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MutunReportScreen(
                  matna: matna,
                  teacherName: teacherName,
                  pathwayName: pathwayName,
                  reportsService: reportsService,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    matna.isNazm
                        ? Icons.format_list_numbered_rounded
                        : Icons.article_rounded,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(matna.name, style: textTheme.titleSmall),
                      const SizedBox(height: 3),
                      Text(
                        '${matna.typeLabel} • ${matna.totalCount} ${matna.unitLabel}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 13, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== بطاقة القرآن داخل المعلم ====================

class _QuranTile extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final PathwayInfo pathway;
  final ReportsService reportsService;

  const _QuranTile({
    required this.teacherId,
    required this.teacherName,
    required this.pathway,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuranReportScreen(
                  teacherId: teacherId,
                  teacherName: teacherName,
                  pathway: pathway,
                  reportsService: reportsService,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.goldSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppColors.goldDark, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('القرآن الكريم — الأوراد والختمات',
                          style: textTheme.titleSmall),
                      const SizedBox(height: 3),
                      Text(
                        pathway.isQuranOnly
                            ? 'متابعة الأوراد والختمات'
                            : 'ورد القرآن في هذا القسم',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 13, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== شاشة تقرير المتن (يومي + أسبوعي + شهري) ====================

class MutunReportScreen extends StatefulWidget {
  final Matna matna;
  final String teacherName;
  final String pathwayName;
  final ReportsService reportsService;

  const MutunReportScreen({
    super.key,
    required this.matna,
    required this.teacherName,
    required this.pathwayName,
    required this.reportsService,
  });

  @override
  State<MutunReportScreen> createState() => _MutunReportScreenState();
}

class _MutunReportScreenState extends State<MutunReportScreen> {
  final ScrollController _scrollController = ScrollController();

  // مفاتيح البطاقات اليومية للانتقال التلقائي إلى اليوم الحالي
  final Map<String, GlobalKey> _dayKeys = {};

  Future<MutunReportData>? _future;

  // البحث بالتاريخ — null يعني عرض كل التسجيلات اليومية
  DateTime? _searchDate;

  @override
  void initState() {
    super.initState();
    _future = widget.reportsService.buildMutunDailyReports(widget.matna);
  }

  /// نافذة اختيار تاريخ البحث عن التسجيلات اليومية
  Future<void> _pickSearchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _searchDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'ابحث عن تسجيلات يوم معيّن',
      cancelText: 'إلغاء',
      confirmText: 'بحث',
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    setState(() => _searchDate = picked);
  }

  /// فلترة التسجيلات اليومية بحسب تاريخ البحث المختار
  static List<ActivityDayReport> _filterByDate(
    List<ActivityDayReport> reports,
    DateTime? date,
  ) {
    if (date == null) return reports;
    return reports
        .where((r) => DateUtils.isSameDay(r.date, date))
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// الانتقال تلقائياً إلى بطاقة اليوم الحالي بعد البناء
  void _scrollToToday(List<ActivityDayReport> reportsDesc) {
    final now = DateTime.now();
    ActivityDayReport? today;
    for (final r in reportsDesc) {
      if (DateUtils.isSameDay(r.date, now)) today = r;
    }
    final target = today ?? (reportsDesc.isEmpty ? null : reportsDesc.first);
    if (target == null) return;

    final key = _dayKeys[DateFormat('y-M-d').format(target.date)];
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.matna.name),
            Text(
              '${widget.teacherName} • ${widget.pathwayName}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: [
          // زر البحث بالتاريخ
          IconButton(
            tooltip: _searchDate == null
                ? 'بحث بالتاريخ'
                : 'إلغاء البحث بالتاريخ',
            onPressed: () {
              if (_searchDate != null) {
                setState(() => _searchDate = null);
              } else {
                _pickSearchDate();
              }
            },
            icon: _searchDate == null
                ? const Icon(Icons.calendar_month_outlined)
                : const Icon(Icons.filter_alt_off_rounded),
          ),
          IconButton(
            tooltip: 'بحث بالتاريخ',
            onPressed: _pickSearchDate,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: WatermarkedBackground(
        child: FutureBuilder<MutunReportData>(
          future: _future,
          builder: (context, snapshot) {
            final textTheme = Theme.of(context).textTheme;
            if (snapshot.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل التقرير',
                onRetry: () => setState(() {
                  _future = widget.reportsService
                      .buildMutunDailyReports(widget.matna);
                }),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            if (data.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد تسجيلات يومية',
                message: 'لم يسجّل المعلم أي متابعة لهذا المتن بعد',
              );
            }

            // ترتيب تنازلي: الأحدث في الأعلى والأقدم في الأسفل
            final reportsDesc = data.days.reversed.toList();

            // فلترة التسجيلات اليومية بحسب تاريخ البحث (إن وُجد)
            final visibleReports = _filterByDate(reportsDesc, _searchDate);

            // جهّز مفاتيح البطاقات
            _dayKeys.clear();
            for (final r in visibleReports) {
              _dayKeys[DateFormat('y-M-d').format(r.date)] = GlobalKey();
            }

            // البطاقات الأسبوعية والشهرية — بقاعدة ظهور الإدارة نفسها
            final periods = _LessonReportScreenState._adminPeriods(
              widget.reportsService.buildActivityPeriodCards(
                days: data.days,
                completionBase: widget.matna.totalCount.toDouble(),
              ),
            );

            if (_searchDate == null) _scrollToToday(visibleReports);

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                // ===== ملخص تقدم المتن =====
                if (_searchDate == null) _MutunProgressCard(data: data),

                // ===== شريط البحث بالتاريخ =====
                if (_searchDate != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نتائج البحث: ${DateFormat('d MMMM y', 'ar').format(_searchDate!)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _searchDate = null),
                          child: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                  ),
                ],

                // ===== التقارير اليومية =====
                SectionHeader(
                  title: _searchDate == null
                      ? 'التقرير اليومي'
                      : 'نتائج البحث — ${visibleReports.length} يوم',
                  subtitle: _searchDate == null
                      ? 'الأحدث في الأعلى — اضغط للتفاصيل'
                      : 'تسجيلات يوم ${DateFormat('d/M/y', 'ar').format(_searchDate!)}',
                ),
                if (visibleReports.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج',
                    message: 'لا توجد تسجيلات في هذا التاريخ',
                  )
                else
                  for (final report in visibleReports)
                    _ActivityDayCard(
                      key: _dayKeys[DateFormat('y-M-d')
                          .format(report.date)],
                      report: report,
                      unitLabel: widget.matna.unitLabel,
                      completionLabel: 'حفظ تام',
                      title: widget.matna.name,
                      isToday: DateUtils.isSameDay(
                          report.date, DateTime.now()),
                    ),

                // ===== التقارير الأسبوعية =====
                if (periods.weeks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'التقارير الأسبوعية',
                    subtitle: 'كل أسبوع منتهٍ في بطاقة',
                  ),
                  for (final week in periods.weeks)
                    _ActivityPeriodCardTile(
                      period: week,
                      icon: Icons.date_range_rounded,
                      days: data.days,
                      unitLabel: widget.matna.unitLabel,
                      completionLabel: 'حفظ تام',
                      title: widget.matna.name,
                    ),
                ],

                // ===== التقارير الشهرية =====
                if (periods.months.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'التقارير الشهرية',
                    subtitle: 'كل شهر منتهٍ في بطاقة',
                  ),
                  for (final month in periods.months)
                    _ActivityPeriodCardTile(
                      period: month,
                      icon: Icons.calendar_month_rounded,
                      days: data.days,
                      unitLabel: widget.matna.unitLabel,
                      completionLabel: 'حفظ تام',
                      title: widget.matna.name,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ==================== بطاقة ملخص تقدم المتن ====================

class _MutunProgressCard extends StatelessWidget {
  final MutunReportData data;

  const _MutunProgressCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final matna = data.matna;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            matna.name,
            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${matna.typeLabel} • وصل الطلاب إلى ${fmtNum(data.reached)}'
            ' من ${fmtNum(matna.totalCount.toDouble())} ${matna.unitLabel}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: data.progress,
                    minHeight: 9,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${data.progressPercent}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== شاشة تقرير القرآن (يومي + أسبوعي + شهري) ====================

class QuranReportScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final PathwayInfo pathway;
  final ReportsService reportsService;

  const QuranReportScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.pathway,
    required this.reportsService,
  });

  @override
  State<QuranReportScreen> createState() => _QuranReportScreenState();
}

class _QuranReportScreenState extends State<QuranReportScreen> {
  final ScrollController _scrollController = ScrollController();

  // مفاتيح البطاقات اليومية للانتقال التلقائي إلى اليوم الحالي
  final Map<String, GlobalKey> _dayKeys = {};

  Future<QuranReportData>? _future;

  // البحث بالتاريخ — null يعني عرض كل الأوراد اليومية
  DateTime? _searchDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.reportsService.buildTeacherQuranDailyReports(
      teacherId: widget.teacherId,
      pathwayId: widget.pathway.id,
    );
  }

  /// نافذة اختيار تاريخ البحث عن الأوراد اليومية
  Future<void> _pickSearchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _searchDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'ابحث عن أوراد يوم معيّن',
      cancelText: 'إلغاء',
      confirmText: 'بحث',
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    setState(() => _searchDate = picked);
  }

  /// فلترة الأوراد اليومية بحسب تاريخ البحث المختار
  static List<ActivityDayReport> _filterByDate(
    List<ActivityDayReport> reports,
    DateTime? date,
  ) {
    if (date == null) return reports;
    return reports
        .where((r) => DateUtils.isSameDay(r.date, date))
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// الانتقال تلقائياً إلى بطاقة اليوم الحالي بعد البناء
  void _scrollToToday(List<ActivityDayReport> reportsDesc) {
    final now = DateTime.now();
    ActivityDayReport? today;
    for (final r in reportsDesc) {
      if (DateUtils.isSameDay(r.date, now)) today = r;
    }
    final target = today ?? (reportsDesc.isEmpty ? null : reportsDesc.first);
    if (target == null) return;

    final key = _dayKeys[DateFormat('y-M-d').format(target.date)];
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('القرآن الكريم'),
            Text(
              '${widget.teacherName} • ${widget.pathway.name}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: [
          // زر البحث بالتاريخ
          IconButton(
            tooltip: _searchDate == null
                ? 'بحث بالتاريخ'
                : 'إلغاء البحث بالتاريخ',
            onPressed: () {
              if (_searchDate != null) {
                setState(() => _searchDate = null);
              } else {
                _pickSearchDate();
              }
            },
            icon: _searchDate == null
                ? const Icon(Icons.calendar_month_outlined)
                : const Icon(Icons.filter_alt_off_rounded),
          ),
          IconButton(
            tooltip: 'بحث بالتاريخ',
            onPressed: _pickSearchDate,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: WatermarkedBackground(
        child: FutureBuilder<QuranReportData>(
          future: _future,
          builder: (context, snapshot) {
            final textTheme = Theme.of(context).textTheme;
            if (snapshot.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل التقرير',
                onRetry: () => setState(_load),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            if (data.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد تسجيلات يومية',
                message: 'لم يسجّل المعلم أي ورد قرآني بعد',
              );
            }

            // ترتيب تنازلي: الأحدث في الأعلى والأقدم في الأسفل
            final reportsDesc = data.days.reversed.toList();

            // فلترة الأوراد اليومية بحسب تاريخ البحث (إن وُجد)
            final visibleReports = _filterByDate(reportsDesc, _searchDate);

            // جهّز مفاتيح البطاقات
            _dayKeys.clear();
            for (final r in visibleReports) {
              _dayKeys[DateFormat('y-M-d').format(r.date)] = GlobalKey();
            }

            // البطاقات الأسبوعية والشهرية — بقاعدة ظهور الإدارة نفسها
            // (القرآن بلا نسبة إنجاز — completionBase = 0)
            final periods = _LessonReportScreenState._adminPeriods(
              widget.reportsService.buildActivityPeriodCards(
                days: data.days,
                completionBase: 0,
              ),
            );

            // ملخص تقدم الطلاب مرتّب أبجديًا بالاسم
            final summaries = data.studentSummaries.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));

            if (_searchDate == null) _scrollToToday(visibleReports);

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                // ===== ملخص الأوراد والختمات =====
                if (_searchDate == null)
                  _QuranHeaderCard(data: data),

                // ===== شريط البحث بالتاريخ =====
                if (_searchDate != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نتائج البحث: ${DateFormat('d MMMM y', 'ar').format(_searchDate!)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _searchDate = null),
                          child: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                  ),
                ],

                // ===== التقارير اليومية =====
                SectionHeader(
                  title: _searchDate == null
                      ? 'التقرير اليومي'
                      : 'نتائج البحث — ${visibleReports.length} يوم',
                  subtitle: _searchDate == null
                      ? 'الأحدث في الأعلى — اضغط للتفاصيل'
                      : 'أوراد يوم ${DateFormat('d/M/y', 'ar').format(_searchDate!)}',
                ),
                if (visibleReports.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج',
                    message: 'لا توجد أوراد في هذا التاريخ',
                  )
                else
                  for (final report in visibleReports)
                    _ActivityDayCard(
                      key: _dayKeys[DateFormat('y-M-d')
                          .format(report.date)],
                      report: report,
                      unitLabel: 'صفحة',
                      completionLabel: 'ختمة',
                      title: 'ورد القرآن الكريم',
                      isToday: DateUtils.isSameDay(
                          report.date, DateTime.now()),
                    ),

                // ===== ملخص تقدم الطلاب =====
                if (_searchDate == null && summaries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'ملخص تقدم الطلاب',
                    subtitle: 'الختمات المكتملة وموضع القراءة الحالي',
                  ),
                  for (final entry in summaries)
                    _StudentQuranSummaryTile(
                      name: entry.key,
                      summary: entry.value,
                    ),
                ],

                // ===== التقارير الأسبوعية =====
                if (periods.weeks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'التقارير الأسبوعية',
                    subtitle: 'كل أسبوع منتهٍ في بطاقة',
                  ),
                  for (final week in periods.weeks)
                    _ActivityPeriodCardTile(
                      period: week,
                      icon: Icons.date_range_rounded,
                      days: data.days,
                      unitLabel: 'صفحة',
                      completionLabel: 'ختمة',
                      title: 'ورد القرآن الكريم',
                    ),
                ],

                // ===== التقارير الشهرية =====
                if (periods.months.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    title: 'التقارير الشهرية',
                    subtitle: 'كل شهر منتهٍ في بطاقة',
                  ),
                  for (final month in periods.months)
                    _ActivityPeriodCardTile(
                      period: month,
                      icon: Icons.calendar_month_rounded,
                      days: data.days,
                      unitLabel: 'صفحة',
                      completionLabel: 'ختمة',
                      title: 'ورد القرآن الكريم',
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ==================== بطاقة ملخص الأوراد والختمات ====================

class _QuranHeaderCard extends StatelessWidget {
  final QuranReportData data;

  const _QuranHeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: Colors.white, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'القرآن الكريم — الأوراد والختمات',
                      style: textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmtNum(data.totalPagesRead),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'صفحة مقروءة',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.completedKhatmas}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ختمة مكتملة',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== بطاقة ملخص تقدم طالب في القرآن ====================

class _StudentQuranSummaryTile extends StatelessWidget {
  final String name;
  final QuranProgressSummary summary;

  const _StudentQuranSummaryTile({
    required this.name,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
              InitialAvatar(name: name, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name, style: textTheme.titleSmall),
              ),
              if (summary.completedKhatmas > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    summary.completedKhatmas == 1
                        ? 'ختمة'
                        : '${summary.completedKhatmas} ختمات',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: summary.khatmaProgress,
                    minHeight: 7,
                    backgroundColor: AppColors.lineSoft,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Text(
                  'صفحة ${summary.currentPage} من ${AppConstants.khatmaPages}',
                  textAlign: TextAlign.end,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== بطاقة يوم نشاط (متون/قرآن) ====================

class _ActivityDayCard extends StatelessWidget {
  final ActivityDayReport report;
  final String unitLabel;
  final String completionLabel;
  final String title;
  final bool isToday;

  const _ActivityDayCard({
    super.key,
    required this.report,
    required this.unitLabel,
    required this.completionLabel,
    required this.title,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText = DateFormat('d MMMM y', 'ar').format(report.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isToday ? AppColors.primary : AppColors.lineSoft,
          width: isToday ? 1.6 : 1,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
                builder: (_) => _ActivityDayDetailScreen(
                  report: report,
                  unitLabel: unitLabel,
                  completionLabel: completionLabel,
                  title: title,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primarySurface
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${report.weekdayLabel}، $dateText',
                        style: textTheme.bodySmall?.copyWith(
                          color: isToday
                              ? AppColors.primaryDark
                              : AppColors.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'اليوم',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color:
                            AppColors.inkMuted.withValues(alpha: 0.6)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.how_to_reg_rounded,
                      label: 'الطلاب',
                      value: '${report.studentsCount}',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'المنجز',
                      value: '${fmtNum(report.units)} $unitLabel',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    report.hasCompletion
                        ? _MiniStat(
                            icon: Icons.workspace_premium_rounded,
                            label: completionLabel,
                            value: 'تم',
                            color: AppColors.gold,
                          )
                        : _MiniStat(
                            icon: Icons.receipt_long_rounded,
                            label: 'التسجيلات',
                            value: '${report.entries.length}',
                            color: AppColors.gold,
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

// ==================== شاشة تفاصيل يوم النشاط (متون/قرآن) ====================

class _ActivityDayDetailScreen extends StatelessWidget {
  final ActivityDayReport report;
  final String unitLabel;
  final String completionLabel;
  final String title;

  const _ActivityDayDetailScreen({
    required this.report,
    required this.unitLabel,
    required this.completionLabel,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText =
        DateFormat('EEEE، d MMMM y', 'ar').format(report.date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.weekdayLabel),
            Text(
              dateText,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // ===== ملخص النشاط =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report.studentsCount} طلاب • المنجز: ${fmtNum(report.units)} $unitLabel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ===== سجلات الطلاب =====
            const SectionHeader(
              title: 'سجلات الطلاب',
              subtitle: 'من / إلى • العدد • الملاحظات',
            ),
            for (final entry in report.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: entry.completesTotal
                        ? AppColors.goldSoft
                        : AppColors.lineSoft,
                    width: entry.completesTotal ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InitialAvatar(name: entry.studentName, radius: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(entry.studentName,
                              style: textTheme.titleSmall),
                        ),
                        if (entry.completesTotal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              completionLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.linear_scale_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'من ${fmtNum(entry.from)} إلى ${fmtNum(entry.to)}'
                            ' (${fmtNum(entry.count)} $unitLabel)',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.notes != null &&
                        entry.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes_rounded,
                                size: 15, color: AppColors.inkMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.notes!,
                                style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== بطاقة فترة النشاط (أسبوع/شهر) — بلا PDF ====================

class _ActivityPeriodCardTile extends StatelessWidget {
  final PeriodCard period;
  final IconData icon;
  final List<ActivityDayReport> days;
  final String unitLabel;
  final String completionLabel;
  final String title;

  const _ActivityPeriodCardTile({
    required this.period,
    required this.icon,
    required this.days,
    required this.unitLabel,
    required this.completionLabel,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final report = period.report;
    final attendancePct = report.attendanceRates.values.isEmpty
        ? 0
        : (report.attendanceRates.values.fold(0.0, (s, v) => s + v) /
                report.attendanceRates.length *
                100)
            .round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: period.isCurrent
              ? AppColors.gold
              : AppColors.lineSoft,
          width: period.isCurrent ? 1.6 : 1,
        ),
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
                builder: (_) => _ActivityPeriodDetailScreen(
                  period: period,
                  days: days,
                  unitLabel: unitLabel,
                  completionLabel: completionLabel,
                  title: title,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: period.isCurrent
                        ? AppColors.goldSurface
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: period.isCurrent
                        ? AppColors.goldDark
                        : AppColors.primary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(period.title,
                                style: textTheme.titleSmall),
                          ),
                          if (period.isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'جديد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(period.subtitle,
                          style: textTheme.bodySmall),
                      const SizedBox(height: 5),
                      Text(
                        'المنجز: ${fmtNum(report.unitsAccomplished)} $unitLabel • الحضور: $attendancePct%',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: AppColors.inkMuted
                        .withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== شاشة تفاصيل فترة النشاط (أسبوع/شهر) ====================

class _ActivityPeriodDetailScreen extends StatelessWidget {
  final PeriodCard period;
  final List<ActivityDayReport> days;
  final String unitLabel;
  final String completionLabel;
  final String title;

  const _ActivityPeriodDetailScreen({
    required this.period,
    required this.days,
    required this.unitLabel,
    required this.completionLabel,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final start =
        DateTime(period.start.year, period.start.month, period.start.day);
    final end = DateTime(period.end.year, period.end.month, period.end.day);
    final periodDays = days
        .where((r) => !r.date.isBefore(start) && !r.date.isAfter(end))
        .toList();

    final isWeek = period.id.startsWith('week');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(period.title),
            Text(
              period.subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // ===== التقارير اليومية للفترة =====
            const SectionHeader(
              title: 'التقارير اليومية',
              subtitle: 'اضغط على أي يوم لعرض تفاصيله',
            ),
            if (periodDays.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text(
                  'لا توجد تسجيلات يومية في هذه الفترة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              )
            else
              for (final report in periodDays)
                _ActivityDayCard(
                  report: report,
                  unitLabel: unitLabel,
                  completionLabel: completionLabel,
                  title: title,
                  isToday: DateUtils.isSameDay(
                      report.date, DateTime.now()),
                ),

            // ===== ملخص الفترة في النهاية =====
            const SizedBox(height: 16),
            SectionHeader(
              title: isWeek ? 'ملخص الأسبوع' : 'ملخص الشهر',
              subtitle: 'المنجز + نسب المشاركة',
            ),
            _ActivityPeriodSummaryCard(
              period: period,
              unitLabel: unitLabel,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== بطاقة ملخص فترة النشاط ====================

class _ActivityPeriodSummaryCard extends StatelessWidget {
  final PeriodCard period;
  final String unitLabel;

  const _ActivityPeriodSummaryCard({
    required this.period,
    required this.unitLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final report = period.report;
    final rates = report.attendanceRates.entries.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.goldSoft, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الملخص
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(period.title, style: textTheme.titleSmall),
                    Text(period.subtitle, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // المنجز
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered_rounded,
                    color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المنجز خلال الفترة',
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${fmtNum(report.unitsAccomplished)} $unitLabel',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // عدد التسجيلات
          Row(
            children: [
              Text(
                'عدد التسجيلات',
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${report.recordingsCount}',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),

          // نسب مشاركة الطلاب
          if (rates.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('نسبة مشاركة الطلاب خلال الفترة',
                style: textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final entry in rates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          minHeight: 8,
                          backgroundColor: AppColors.lineSoft,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  AppColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(entry.value * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}


// ==================== المهمة 3: طلاب المعلم + تقرير الطالب ====================

/// شاشة قائمة طلاب المعلم في المسار — مدخل تقارير الطلاب
class TeacherStudentsScreen extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final PathwayInfo pathway;
  final ReportsService reportsService;

  const TeacherStudentsScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.pathway,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طلاب ${pathway.name}'),
            Text(
              '$teacherName • اضغط على طالب لعرض تقريره',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: FutureBuilder<List<Student>>(
          // جلب موثوق مرة واحدة — لا نحتاج بثًا حيًا هنا
          future: StudentsService().fetchPathwayStudents(
            teacherId: teacherId,
            pathwayId: pathway.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل الطلاب',
                onRetry: () {},
              );
            }
            if (!snapshot.hasData) {
              return const ListSkeleton(itemCount: 5);
            }
            final students = snapshot.data!;
            if (students.isEmpty) {
              return const EmptyState(
                icon: Icons.group_outlined,
                title: 'لا يوجد طلاب',
                message: 'لم يُضف طلاب لهذا المعلم في هذا القسم بعد',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return _StudentTile(
                  student: student,
                  teacherName: teacherName,
                  pathway: pathway,
                  reportsService: reportsService,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// بطاقة طالب في القائمة
class _StudentTile extends StatelessWidget {
  final Student student;
  final String teacherName;
  final PathwayInfo pathway;
  final ReportsService reportsService;

  const _StudentTile({
    required this.student,
    required this.teacherName,
    required this.pathway,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentReportScreen(
              student: student,
              teacherName: teacherName,
              pathwayName: pathway.name,
              reportsService: reportsService,
            ),
          ),
        ),
        leading: InitialAvatar(name: student.name),
        title: Text(student.name, style: textTheme.titleSmall),
        subtitle: Text(
          student.status == 'active'
              ? 'اضغط لعرض تقرير النشاط الكامل'
              : 'طالب غير مُفعّل — اضغط لعرض التقرير',
          style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
        trailing: const Icon(Icons.keyboard_arrow_left_rounded,
            color: AppColors.gold),
      ),
    );
  }
}

/// شاشة تقرير الطالب — تجمع نشاطه من الدروس والمتون والقرآن
class StudentReportScreen extends StatefulWidget {
  final Student student;
  final String teacherName;
  final String pathwayName;
  final ReportsService reportsService;

  const StudentReportScreen({
    super.key,
    required this.student,
    required this.teacherName,
    required this.pathwayName,
    required this.reportsService,
  });

  @override
  State<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends State<StudentReportScreen> {
  Future<StudentReport>? _future;
  DateTime? _searchDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.reportsService.buildStudentReport(widget.student);
    });
  }

  Future<void> _pickSearchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _searchDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'ابحث عن نشاط يوم معيّن',
      cancelText: 'إلغاء',
      confirmText: 'بحث',
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    setState(() => _searchDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.student.name),
            Text(
              '${widget.teacherName} • ${widget.pathwayName}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _searchDate == null
                ? 'بحث بالتاريخ'
                : 'إلغاء البحث بالتاريخ',
            onPressed: () {
              if (_searchDate != null) {
                setState(() => _searchDate = null);
              } else {
                _pickSearchDate();
              }
            },
            icon: _searchDate == null
                ? const Icon(Icons.calendar_month_outlined)
                : const Icon(Icons.filter_alt_off_rounded),
          ),
          IconButton(
            tooltip: 'بحث بالتاريخ',
            onPressed: _pickSearchDate,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: WatermarkedBackground(
        child: FutureBuilder<StudentReport>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل تقرير الطالب',
                onRetry: _load,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final report = snapshot.data!;
            if (report.isEmpty) {
              return const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'لا يوجد نشاط',
                message: 'لم يُسجّل لهذا الطالب أي نشاط بعد',
              );
            }

            // فلترة بالتاريخ
            final visible = _searchDate == null
                ? report.activities
                : report.activities
                    .where((a) => DateUtils.isSameDay(a.date, _searchDate!))
                    .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                // ===== بطاقة رأس التقرير =====
                _StudentReportHeader(report: report),
                const SizedBox(height: 12),

                // ===== شريط البحث بالتاريخ =====
                if (_searchDate != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نتائج البحث: ${DateFormat('d MMMM y', 'ar').format(_searchDate!)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _searchDate = null),
                          child: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                  ),
                ],

                SectionHeader(
                  title: _searchDate == null
                      ? 'سجل النشاط'
                      : 'نتائج البحث — ${visible.length} نشاط',
                  subtitle: _searchDate == null
                      ? 'الأحدث في الأعلى — دروس ومتون وقرآن'
                      : 'نشاط يوم ${DateFormat('d/M/y', 'ar').format(_searchDate!)}',
                ),
                if (visible.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج',
                    message: 'لا يوجد نشاط للطالب في هذا التاريخ',
                  )
                else
                  for (final entry in visible)
                    _StudentActivityTile(entry: entry),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// رأس تقرير الطالب — تدرج أخضر مع إحصاءات الأنشطة الثلاثة
class _StudentReportHeader extends StatelessWidget {
  final StudentReport report;

  const _StudentReportHeader({required this.report});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = report.student;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(name: s.name, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      s.pathwayName,
                      style: textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderStatBox(
                  label: 'وحدات الدروس',
                  value: fmtNum(report.lessonUnits),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderStatBox(
                  label: 'وحدات المتون',
                  value: fmtNum(report.matnUnits),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderStatBox(
                  label: 'صفحات القرآن',
                  value: fmtNum(report.quranPages),
                ),
              ),
            ],
          ),
          if (report.lessonDays > 0) ...[
            const SizedBox(height: 12),
            Text(
              'الحضور في الدروس: ${report.lessonPresentDays} من ${report.lessonDays} يوم — ${(report.attendanceRate * 100).round()}%',
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

/// صندوق إحصاء صغير داخل تدرج رأس التقرير
class _HeaderStatBox extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة نشاط واحد للطالب (درس حضور/غياب — متن — ورد قرآن)
class _StudentActivityTile extends StatelessWidget {
  final StudentActivityEntry entry;

  const _StudentActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText = DateFormat('d/M/y', 'ar').format(entry.date);

    // لون وشارة حسب نوع النشاط
    final Color tint;
    final Color tintSurface;
    if (entry.kind == StudentActivityKind.lesson) {
      tint = entry.wasPresent ? AppColors.success : AppColors.error;
      tintSurface = entry.wasPresent
          ? AppColors.successSurface
          : AppColors.errorSurface;
    } else if (entry.kind == StudentActivityKind.matn) {
      tint = AppColors.primary;
      tintSurface = AppColors.primarySurface;
    } else {
      tint = AppColors.goldDark;
      tintSurface = AppColors.goldSurface;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tintSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(entry.kind.icon, size: 22, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title,
                      style: textTheme.titleSmall?.copyWith(fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.weekdayLabel}، $dateText • من ${fmtNum(entry.from)} إلى ${fmtNum(entry.to)} (${fmtNum(entry.count)})',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                  if (entry.notes != null &&
                      entry.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ملاحظة: ${entry.notes}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // شارة الحضور/الغياب للدروس
            if (entry.kind == StudentActivityKind.lesson)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tintSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tint.withValues(alpha: 0.25)),
                ),
                child: Text(
                  entry.wasPresent ? 'حاضر' : 'غائب',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              )
            // شارة إتمام المتن كاملًا
            else if (entry.kind == StudentActivityKind.matn &&
                entry.completionBase > 0 &&
                entry.to >= entry.completionBase)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'حفظ تام',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== المهمة 4: أيام غياب المعلم ====================

/// قسم أيام الغياب داخل شاشة تقرير الدرس
class _TeacherAbsenceSection extends StatelessWidget {
  final List<TeacherAbsence> absences;

  const _TeacherAbsenceSection({required this.absences});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس القسم
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.errorSurface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_busy_rounded,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أيام لم يسجّل فيها المعلم الدرس',
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${absences.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // الأيام (سطر لكل غياب — الأحدث أولاً)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: absences.isEmpty
                ? Text(
                    'لا يوجد غياب — سجّل المعلم دروسه في كل الأيام المتوقعة',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.inkMuted),
                  )
                : Column(
                    children: [
                      for (final a in absences.take(30))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_circle_outline,
                                  size: 15, color: AppColors.error),
                              const SizedBox(width: 7),
                              Text(
                                '${a.weekdayLabel}، ${DateFormat('d/M/y', 'ar').format(a.date)}',
                                style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkSecondary),
                              ),
                              const Spacer(),
                              const Text(
                                'غائب',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (absences.length > 30)
                        Text(
                          '… و${absences.length - 30} يومًا أقدم',
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
