import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/lesson.dart';
import '../../services/report_pdf_service.dart';
import '../../services/reports_service.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';

/// شاشة تقارير الإدارة — 4 أقسام ← معلمو القسم ← دروس المعلم ← يومي/أسبوعي/شهري
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
    final pathways =
        AppConstants.pathways.where((p) => p.id != 'quran').toList();

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
            // ===== 4 أقسام بأيقونات دائرية (صف 2 × 2) =====
            for (var row = 0; row < 2; row++)
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
            const Text(
              'المعلمون الذين لديهم دروس في هذا القسم',
              style:
                  TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        // دروس القسم أولاً (تحدد من له دروس)، ثم أسماء المعلمين
        child: StreamBuilder<List<Lesson>>(
          stream: reportsService.watchPathwayLessons(pathway.id),
          builder: (context, lessonsSnap) {
            if (lessonsSnap.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل دروس القسم',
                onRetry: () {},
              );
            }
            if (!lessonsSnap.hasData) {
              return const ListSkeleton(itemCount: 3);
            }

            final lessons = lessonsSnap.data!;
            // مجمّعة حسب المعلم
            final byTeacher = <String, List<Lesson>>{};
            for (final l in lessons) {
              byTeacher.putIfAbsent(l.teacherId, () => []).add(l);
            }

            if (byTeacher.isEmpty) {
              return EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'لا توجد دروس في هذا القسم',
                message:
                    'لم يُعدّ أي معلم درساً في "${pathway.name}" بعد',
              );
            }

            return StreamBuilder<List<AppUser>>(
              stream: teachersService.watchTeachers(),
              builder: (context, teachersSnap) {
                final teachers = teachersSnap.data ?? [];
                final names = {
                  for (final t in teachers) t.uid: t.name,
                };

                final teacherIds = byTeacher.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: teacherIds.length,
                  itemBuilder: (context, index) {
                    final teacherId = teacherIds[index];
                    final teacherLessons = byTeacher[teacherId]!;
                    final name = names[teacherId] ?? 'معلم';
                    return _TeacherLessonsTile(
                      teacherName: name,
                      lessons: teacherLessons,
                      pathway: pathway,
                      reportsService: reportsService,
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
  final String teacherName;
  final List<Lesson> lessons;
  final PathwayInfo pathway;
  final ReportsService reportsService;

  const _TeacherLessonsTile({
    required this.teacherName,
    required this.lessons,
    required this.pathway,
    required this.reportsService,
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
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: InitialAvatar(name: teacherName),
          title: Text(teacherName, style: textTheme.titleSmall),
          subtitle: Text(
            lessons.length == 1
                ? 'درس واحد'
                : '${lessons.length} دروس',
            style: textTheme.bodySmall,
          ),
          children: [
            for (final lesson in lessons)
              _LessonTile(
                lesson: lesson,
                teacherName: teacherName,
                pathwayName: pathway.name,
                reportsService: reportsService,
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

  @override
  void initState() {
    super.initState();
    _future = widget.reportsService.buildLessonDailyReports(widget.lesson);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// الانتقال تلقائياً إلى بطاقة اليوم الحالي بعد البناء
  void _scrollToToday(List<LessonDayReport> reports) {
    final now = DateTime.now();
    LessonDayReport? today;
    for (final r in reports) {
      if (DateUtils.isSameDay(r.date, now)) today = r;
    }
    // إن لم يوجد اليوم الحالي ننتقل لأحدث بطاقة
    final target = today ?? (reports.isEmpty ? null : reports.last);
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
      ),
      body: WatermarkedBackground(
        child: FutureBuilder<List<LessonDayReport>>(
          future: _future,
          builder: (context, snapshot) {
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

            final reports = snapshot.data!;
            if (reports.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد تسجيلات يومية',
                message: 'لم يسجّل المعلم أي درس يومي بعد',
              );
            }

            // جهّز مفاتيح البطاقات
            _dayKeys.clear();
            for (final r in reports) {
              _dayKeys[r.recording.id] = GlobalKey();
            }

            // البطاقات الأسبوعية والشهرية
            final periods = widget.reportsService.buildPeriodCards(
              lesson: widget.lesson,
              dailyReports: reports,
            );

            _scrollToToday(reports);

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                // ===== التقارير اليومية =====
                SectionHeader(
                  title: 'التقرير اليومي',
                  subtitle: 'كل يوم في بطاقة — اضغط للتفاصيل',
                ),
                for (final report in reports)
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
                      dailyReports: reports,
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
                      dailyReports: reports,
                      lesson: widget.lesson,
                      teacherName: widget.teacherName,
                      pathwayName: widget.pathwayName,
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
                          '${report.recording.count} ${lesson.unitLabel}',
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
                        'المنجز: ${report.unitsAccomplished} وحدة • الحضور: $attendancePct%',
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
                    'من ${report.recording.from} إلى ${report.recording.to}'
                    ' (${report.recording.count} ${lesson.unitLabel})'
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
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.lineSoft,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 34,
                      getTitlesWidget: (v, _) => Text(
                        '${v.round()}%',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.inkMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          v == 0 ? 'الحضور' : 'الإنجاز',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: attendancePct.toDouble(),
                        color: AppColors.success,
                        width: 34,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: completionPct.toDouble(),
                        color: AppColors.gold,
                        width: 34,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                  '${report.unitsAccomplished} ${lesson.unitLabel}',
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
