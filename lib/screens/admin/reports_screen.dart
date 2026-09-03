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
import '../../services/mutun_service.dart';
import '../../services/quran_service.dart';
import '../../services/report_pdf_service.dart';
import '../../services/reports_service.dart';
import '../../services/students_service.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';

/// شاشة تقارير الإدارة — تبويبان:
/// 1) تقارير المعلمين: الأقسام ← معلمو القسم ونشاطهم (دروس/متون) ← يومي/أسبوعي/شهري
/// 2) تقارير الطلاب: الأقسام ← طلاب القسم ← متون الطالب ← بطاقات التسجيل اليومية/الأسبوعية/الشهرية
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TeachersService _teachersService = TeachersService();
  final ReportsService _reportsService = ReportsService();
  final StudentsService _studentsService = StudentsService();
  final MutunService _mutunService = MutunService();
  final QuranService _quranService = QuranService();

  @override
  Widget build(BuildContext context) {
    // كل الأقسام — باستثناء مسار القرآن الكريم
    final pathways = AppConstants.pathways
        .where((p) => p.id != 'quran')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التقارير'),
              Text(
                'تقارير المعلمين والطلاب',
                style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
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
              child: Center(child: CircularLogo(size: 42, elevated: false)),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.co_present_rounded, size: 20),
                text: 'تقارير المعلمين',
              ),
              Tab(
                icon: Icon(Icons.school_rounded, size: 20),
                text: 'تقارير الطلاب',
              ),
            ],
          ),
        ),
        body: WatermarkedBackground(
          child: TabBarView(
            children: [
              // ===== تبويب تقارير المعلمين — المحتوى الحالي كما هو =====
              _TeachersReportsTab(
                pathways: pathways,
                teachersService: _teachersService,
                reportsService: _reportsService,
              ),
              // ===== تبويب تقارير الطلاب — الجديد =====
              _StudentsReportsTab(
                pathways: pathways,
                studentsService: _studentsService,
                teachersService: _teachersService,
                reportsService: _reportsService,
                mutunService: _mutunService,
                quranService: _quranService,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== تبويب تقارير المعلمين (المحتوى الأصلي) ====================

class _TeachersReportsTab extends StatelessWidget {
  final List<PathwayInfo> pathways;
  final TeachersService teachersService;
  final ReportsService reportsService;

  const _TeachersReportsTab({
    required this.pathways,
    required this.teachersService,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
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
                      teachersService: teachersService,
                      reportsService: reportsService,
                    )
                  else
                    const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

// ==================== تبويب تقارير الطلاب (الجديد) ====================

class _StudentsReportsTab extends StatelessWidget {
  final List<PathwayInfo> pathways;
  final StudentsService studentsService;
  final TeachersService teachersService;
  final ReportsService reportsService;
  final MutunService mutunService;
  final QuranService quranService;

  const _StudentsReportsTab({
    required this.pathways,
    required this.studentsService,
    required this.teachersService,
    required this.reportsService,
    required this.mutunService,
    required this.quranService,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      children: [
        const SectionHeader(
          title: 'أقسام الطلاب',
          subtitle: 'اضغط على قسم لعرض طلابه وتقاريرهم',
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
                      teachersService: teachersService,
                      reportsService: reportsService,
                      subtitle: 'تقارير الطلاب',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PathwayStudentsScreen(
                            pathway: pathways[row * 2 + col],
                            studentsService: studentsService,
                            teachersService: teachersService,
                            reportsService: reportsService,
                            mutunService: mutunService,
                            quranService: quranService,
                          ),
                        ),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

// ==================== عنصر قسم (أيقونة دائرية) ====================

class _PathwayReportItem extends StatelessWidget {
  final PathwayInfo pathway;
  final TeachersService teachersService;
  final ReportsService reportsService;
  final String subtitle;
  final VoidCallback? onTap;

  const _PathwayReportItem({
    required this.pathway,
    required this.teachersService,
    required this.reportsService,
    this.subtitle = 'تقارير المعلمين',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageAsset = AppConstants.pathwayImageAsset(pathway.id);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap:
            onTap ??
            () {
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
                  border: Border.all(color: AppColors.goldSoft, width: 2.5),
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
                style: textTheme.titleSmall?.copyWith(
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: AppColors.primarySurface,
    child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 36),
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
              style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        // دمج مصادر النشاط: دروس + متون
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
                if (lessonsSnap.hasError || mutunSnap.hasError) {
                  return ErrorState(
                    message: 'حدث خطأ أثناء تحميل نشاط القسم',
                    onRetry: () {},
                  );
                }
                if (!lessonsSnap.hasData || !mutunSnap.hasData) {
                  return const ListSkeleton(itemCount: 3);
                }

                // مجمّعة حسب المعلم — من المصدرين
                final lessonsByTeacher = <String, List<Lesson>>{};
                for (final l in lessonsSnap.data!) {
                  lessonsByTeacher.putIfAbsent(l.teacherId, () => []).add(l);
                }
                final mutunByTeacher = <String, List<Matna>>{};
                for (final m in mutunSnap.data!) {
                  mutunByTeacher.putIfAbsent(m.teacherId, () => []).add(m);
                }

                // اتحاد معرفات المعلمين (بدون تكرار) ثم فرز أبجدي
                final teacherIds = {
                  ...lessonsByTeacher.keys,
                  ...mutunByTeacher.keys,
                }.toList();

                if (teacherIds.isEmpty) {
                  return EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'لا يوجد نشاط في هذا القسم',
                    message: 'لم يسجّل أي معلم نشاطاً في "${pathway.name}" بعد',
                  );
                }

                return StreamBuilder<List<AppUser>>(
                  stream: teachersService.watchTeachers(),
                  builder: (context, teachersSnap) {
                    final teachers = teachersSnap.data ?? [];
                    final names = {for (final t in teachers) t.uid: t.name};

                    teacherIds.sort(
                      (a, b) => (names[a] ?? 'م').compareTo(names[b] ?? 'م'),
                    );

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: teacherIds.length,
                      itemBuilder: (context, index) {
                        final teacherId = teacherIds[index];
                        final name = names[teacherId] ?? 'معلم';
                        return _TeacherLessonsTile(
                          teacherName: name,
                          lessons: lessonsByTeacher[teacherId] ?? const [],
                          mutun: mutunByTeacher[teacherId] ?? const [],
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
        ),
      ),
    );
  }
}

class _TeacherLessonsTile extends StatelessWidget {
  final String teacherName;
  final List<Lesson> lessons;
  final List<Matna> mutun;
  final PathwayInfo pathway;
  final ReportsService reportsService;

  const _TeacherLessonsTile({
    required this.teacherName,
    required this.lessons,
    required this.mutun,
    required this.pathway,
    required this.reportsService,
  });

  /// نص ملخص نشاط المعلم (دروس + متون)
  String get _activitySummary {
    final parts = <String>[];
    if (lessons.isNotEmpty) {
      parts.add(lessons.length == 1 ? 'درس واحد' : '${lessons.length} دروس');
    }
    if (mutun.isNotEmpty) {
      parts.add(mutun.length == 1 ? 'متن واحد' : '${mutun.length} متون');
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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: InitialAvatar(name: teacherName),
          title: Text(teacherName, style: textTheme.titleSmall),
          subtitle: Text(_activitySummary, style: textTheme.bodySmall),
          children: [
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

            if (lessons.isEmpty && mutun.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  'لا يوجد نشاط مسجّل لهذا المعلم',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
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
                      Text(lesson.typeLabel, style: textTheme.bodySmall),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: lesson.progress,
                          minHeight: 6,
                          backgroundColor: AppColors.lineSoft,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
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
    return reports.where((r) => DateUtils.isSameDay(r.date, date)).toList();
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
                fontSize: 12,
                color: AppColors.inkSecondary,
              ),
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
                  _future = widget.reportsService.buildLessonDailyReports(
                    widget.lesson,
                  );
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
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
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
                          onPressed: () => setState(() => _searchDate = null),
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
                      isToday: DateUtils.isSameDay(report.date, DateTime.now()),
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
                builder: (_) => DayDetailScreen(report: report, lesson: lesson),
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
                        horizontal: 10,
                        vertical: 5,
                      ),
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
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 14,
                      color: AppColors.inkMuted.withValues(alpha: 0.6),
                    ),
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
                      value: '${(report.completionRate * 100).round()}%',
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
              style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
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
          color: period.isCurrent ? AppColors.gold : AppColors.lineSoft,
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
                            child: Text(
                              period.title,
                              style: textTheme.titleSmall,
                            ),
                          ),
                          if (period.isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(20),
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
                      Text(period.subtitle, style: textTheme.bodySmall),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 21,
                          color: AppColors.error,
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
    final dateText = DateFormat('EEEE، d MMMM y', 'ar').format(report.date);
    final attendancePct = (report.attendanceRate * 100).round();
    final completionPct = (report.completionRate * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.recording.weekday),
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inkSecondary,
              ),
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
                    style: textTheme.titleMedium?.copyWith(color: Colors.white),
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
                      const Icon(
                        Icons.how_to_reg_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('حضور الطلاب', style: textTheme.titleSmall),
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
                        AppColors.success,
                      ),
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
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_off_outlined,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الطلاب الغائبون (${report.absentNames.length})',
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.error,
                          ),
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
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: AppColors.error,
                                ),
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
                    Icon(
                      Icons.celebration_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
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
                    Text(
                      'ملاحظات المعلم',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(report.recording.notes!, style: textTheme.bodyMedium),
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

  const _RatePie({required this.label, required this.pct, required this.color});

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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
      return !d.isBefore(widget.period.start) && !d.isAfter(widget.period.end);
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
                fontSize: 12,
                color: AppColors.inkSecondary,
              ),
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
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
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
                  isToday: DateUtils.isSameDay(report.date, DateTime.now()),
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
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 23,
                ),
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
                const Icon(
                  Icons.format_list_numbered_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المنجز من الدرس',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
              Text(
                'نسبة إنجاز الدرس',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),

          // نسب حضور الطلاب
          if (rates.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('نسبة حضور الطلاب خلال الفترة', style: textTheme.titleSmall),
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.success,
                          ),
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
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 13,
                  color: AppColors.inkMuted,
                ),
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
    return reports.where((r) => DateUtils.isSameDay(r.date, date)).toList();
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
                fontSize: 12,
                color: AppColors.inkSecondary,
              ),
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
                  _future = widget.reportsService.buildMutunDailyReports(
                    widget.matna,
                  );
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
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
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
                          onPressed: () => setState(() => _searchDate = null),
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
                      key: _dayKeys[DateFormat('y-M-d').format(report.date)],
                      report: report,
                      unitLabel: widget.matna.unitLabel,
                      completionLabel: 'حفظ تام',
                      title: widget.matna.name,
                      isToday: DateUtils.isSameDay(report.date, DateTime.now()),
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
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
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

// ==================== بطاقة يوم نشاط (متون) ====================

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
                        horizontal: 10,
                        vertical: 5,
                      ),
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
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 14,
                      color: AppColors.inkMuted.withValues(alpha: 0.6),
                    ),
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

// ==================== شاشة تفاصيل يوم النشاط (متون) ====================

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
    final dateText = DateFormat('EEEE، d MMMM y', 'ar').format(report.date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.weekdayLabel),
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inkSecondary,
              ),
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
                    style: textTheme.titleMedium?.copyWith(color: Colors.white),
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
                          child: Text(
                            entry.studentName,
                            style: textTheme.titleSmall,
                          ),
                        ),
                        if (entry.completesTotal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              completionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.linear_scale_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
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
                    if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notes_rounded,
                              size: 15,
                              color: AppColors.inkMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.notes!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkSecondary,
                                ),
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
          color: period.isCurrent ? AppColors.gold : AppColors.lineSoft,
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
                            child: Text(
                              period.title,
                              style: textTheme.titleSmall,
                            ),
                          ),
                          if (period.isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(20),
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
                      Text(period.subtitle, style: textTheme.bodySmall),
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
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 13,
                  color: AppColors.inkMuted.withValues(alpha: 0.6),
                ),
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
    final start = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );
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
                fontSize: 12,
                color: AppColors.inkSecondary,
              ),
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
                  isToday: DateUtils.isSameDay(report.date, DateTime.now()),
                ),

            // ===== ملخص الفترة في النهاية =====
            const SizedBox(height: 16),
            SectionHeader(
              title: isWeek ? 'ملخص الأسبوع' : 'ملخص الشهر',
              subtitle: 'المنجز + نسب المشاركة',
            ),
            _ActivityPeriodSummaryCard(period: period, unitLabel: unitLabel),
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
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 23,
                ),
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
                const Icon(
                  Icons.format_list_numbered_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المنجز خلال الفترة',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
            Text('نسبة مشاركة الطلاب خلال الفترة', style: textTheme.titleSmall),
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.success,
                          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.errorSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_busy_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
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
                    horizontal: 10,
                    vertical: 3,
                  ),
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
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  )
                : Column(
                    children: [
                      for (final a in absences.take(30))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.remove_circle_outline,
                                size: 15,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '${a.weekdayLabel}، ${DateFormat('d/M/y', 'ar').format(a.date)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkSecondary,
                                ),
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
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ==================== تدفق تقارير الطلاب (التبويب الثاني) ====================
// ============================================================================

// ==================== شاشة طلاب القسم (كل المعلمين) ====================

/// تعرض كل طلاب القسم عبر كل المعلمين — النقر على طالب ← متونه المسجلة
class PathwayStudentsScreen extends StatelessWidget {
  final PathwayInfo pathway;
  final StudentsService studentsService;
  final TeachersService teachersService;
  final ReportsService reportsService;
  final MutunService mutunService;
  final QuranService quranService;

  const PathwayStudentsScreen({
    super.key,
    required this.pathway,
    required this.studentsService,
    required this.teachersService,
    required this.reportsService,
    required this.mutunService,
    required this.quranService,
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
              'طلاب القسم وتقارير المتون',
              style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: StreamBuilder<List<Student>>(
          // شرط واحد فقط (pathwayId) — يجلب طلاب كل المعلمين في القسم
          stream: studentsService.watchPathwayStudentsForAdmin(
            pathwayId: pathway.id,
          ),
          builder: (context, studentsSnap) {
            if (studentsSnap.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل طلاب القسم',
                onRetry: () {},
              );
            }
            if (!studentsSnap.hasData) {
              return const ListSkeleton(itemCount: 6);
            }

            final students = studentsSnap.data!;

            if (students.isEmpty) {
              return EmptyState(
                icon: Icons.school_outlined,
                title: 'لا يوجد طلاب في هذا القسم',
                message: 'لم يُضف أي طالب إلى "${pathway.name}" بعد',
              );
            }

            // أسماء المعلمين لعرض معلم كل طالب
            return StreamBuilder<List<AppUser>>(
              stream: teachersService.watchTeachers(),
              builder: (context, teachersSnap) {
                final teachers = teachersSnap.data ?? [];
                final teacherNames = {for (final t in teachers) t.uid: t.name};

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _StudentReportTile(
                      student: student,
                      teacherName: teacherNames[student.teacherId] ?? 'معلم',
                      pathway: pathway,
                      studentsService: studentsService,
                      reportsService: reportsService,
                      mutunService: mutunService,
                      quranService: quranService,
                      teachersService: teachersService,
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

// ==================== بلاطة طالب في قائمة طلاب القسم ====================

class _StudentReportTile extends StatelessWidget {
  final Student student;
  final String teacherName;
  final PathwayInfo pathway;
  final StudentsService studentsService;
  final ReportsService reportsService;
  final MutunService mutunService;
  final QuranService quranService;
  final TeachersService teachersService;

  const _StudentReportTile({
    required this.student,
    required this.teacherName,
    required this.pathway,
    required this.studentsService,
    required this.reportsService,
    required this.mutunService,
    required this.quranService,
    required this.teachersService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentMutunScreen(
                student: student,
                teacherName: teacherName,
                pathway: pathway,
                studentsService: studentsService,
                reportsService: reportsService,
                mutunService: mutunService,
                quranService: quranService,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                InitialAvatar(name: student.name, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: textTheme.titleSmall),
                      const SizedBox(height: 3),
                      Text(
                        'المعلم: $teacherName',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: AppColors.inkMuted.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== شاشة متون الطالب ====================

/// تعرض المتون التي سُجّلت للطالب (المتون فقط وليس الدروس) —
/// النقر على متن ← بطاقات التسجيل اليومية + الأسبوعية/الشهرية الصفراء
class StudentMutunScreen extends StatelessWidget {
  final Student student;
  final String teacherName;
  final PathwayInfo pathway;
  final StudentsService studentsService;
  final ReportsService reportsService;
  final MutunService mutunService;
  final QuranService quranService;

  const StudentMutunScreen({
    super.key,
    required this.student,
    required this.teacherName,
    required this.pathway,
    required this.studentsService,
    required this.reportsService,
    required this.mutunService,
    required this.quranService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.name),
            Text(
              'المتون المسجلة للطالب — $teacherName',
              style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: StreamBuilder<List<MutunRecording>>(
          // كل تسجيلات الطالب — شرط واحد (studentId) + تجميع حسب المتن محليًا
          // التقارير الرسمية: تسجيلات المتون الرسمية فقط
          stream: mutunService.watchStudentRecordings(
            studentId: student.id,
            officialOnly: true,
          ),
          builder: (context, recSnap) {
            if (recSnap.hasError) {
              return ErrorState(
                message: 'حدث خطأ أثناء تحميل تسجيلات الطالب',
                onRetry: () {},
              );
            }
            if (!recSnap.hasData) {
              return const ListSkeleton(itemCount: 5);
            }

            final recordings = recSnap.data!;

            // تجميع حسب المتن
            final byMatna = <String, List<MutunRecording>>{};
            for (final r in recordings) {
              byMatna.putIfAbsent(r.matnaId, () => []).add(r);
            }

            if (byMatna.isEmpty) {
              return EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'لا توجد متون مسجلة',
                message: 'لم يسجّل المعلم أي حفظ للمتن لهذا الطالب بعد',
              );
            }

            // أسماء المتون من مجموعة mutun (شرط pathwayId مفرد)
            return StreamBuilder<List<Matna>>(
              stream: reportsService.watchPathwayMutun(pathway.id),
              builder: (context, matnaSnap) {
                final matnaList = matnaSnap.data ?? [];
                final matnaById = {for (final m in matnaList) m.id: m};

                // المتون التي لها تسجيلات فقط
                final matnaIds = byMatna.keys.toList()
                  ..sort((a, b) {
                    final an = (matnaById[a]?.name) ?? 'م';
                    final bn = (matnaById[b]?.name) ?? 'م';
                    return an.compareTo(bn);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  itemCount: matnaIds.length,
                  itemBuilder: (context, index) {
                    final matnaId = matnaIds[index];
                    final matna = matnaById[matnaId];
                    final recs = byMatna[matnaId]!;
                    return _StudentMatnaTile(
                      matna: matna,
                      matnaId: matnaId,
                      recordings: recs,
                      student: student,
                      pathway: pathway,
                      mutunService: mutunService,
                      quranService: quranService,
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

// ==================== بلاطة متن في قائمة متون الطالب ====================

class _StudentMatnaTile extends StatelessWidget {
  final Matna? matna;
  final String matnaId;
  final List<MutunRecording> recordings;
  final Student student;
  final PathwayInfo pathway;
  final MutunService mutunService;
  final QuranService quranService;
  final ReportsService reportsService;

  const _StudentMatnaTile({
    required this.matna,
    required this.matnaId,
    required this.recordings,
    required this.student,
    required this.pathway,
    required this.mutunService,
    required this.quranService,
    required this.reportsService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = matna?.name ?? 'متن';
    final unitLabel = matna?.unitLabel ?? 'بيت';
    final typeLabel = matna?.typeLabel ?? 'نظم';
    final totalCount = matna?.totalCount ?? 0;

    // آخر نقطة وصل إليها الطالب (تجاهل تسجيلات الغياب)
    final lastReached = recordings
        .where((r) => r.wasPresent)
        .fold(0.0, (max, r) => r.to > max ? r.to : max);
    final progress = totalCount > 0
        ? (lastReached / totalCount).clamp(0.0, 1.0)
        : 0.0;
    final completed = lastReached >= totalCount && totalCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: completed ? AppColors.goldSoft : AppColors.lineSoft,
          width: completed ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentMatnaReportScreen(
                matna: matna,
                matnaId: matnaId,
                recordings: recordings,
                student: student,
                quranService: quranService,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            completed
                                ? 'أتمّ المتن كاملاً 🎉'
                                : 'وصل إلى $unitLabel ${fmtNum(lastReached)} من ${fmtNum(totalCount.toDouble())} (${(progress * 100).round()}%)',
                            style: textTheme.bodySmall?.copyWith(
                              color: completed
                                  ? AppColors.goldDark
                                  : AppColors.inkSecondary,
                              fontWeight: completed
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
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

// ==================== شاشة بطاقات تقرير المتن للطالب ====================

/// بطاقات التسجيل: اليومية (الأحدث أعلى) + الصفراء الأسبوعية/الشهرية
/// + بطاقات غائب/لم يسمع + شاشة الرسمين الدائريين عند النقر على اليومية
class StudentMatnaReportScreen extends StatefulWidget {
  final Matna? matna;
  final String matnaId;
  final List<MutunRecording> recordings;
  final Student student;
  final QuranService quranService;

  const StudentMatnaReportScreen({
    super.key,
    required this.matna,
    required this.matnaId,
    required this.recordings,
    required this.student,
    required this.quranService,
  });

  @override
  State<StudentMatnaReportScreen> createState() =>
      _StudentMatnaReportScreenState();
}

class _StudentMatnaReportScreenState extends State<StudentMatnaReportScreen> {
  List<QuranRecording>? _quranRecordings;

  @override
  void initState() {
    super.initState();
    // جلب أوراد الطالب القرآنية للعرض في البطاقات والرسم الثاني
    _loadQuran();
  }

  void _loadQuran() {
    // التقارير الرسمية: الأوراد الرسمية فقط
    widget.quranService
        .watchStudentRecordings(
          studentId: widget.student.id,
          officialOnly: true,
        )
        .listen(
          (list) {
            if (mounted) setState(() => _quranRecordings = list);
          },
          onError: (Object e) {
            // القرآن عرض إضافي — لا يُفشل التقرير
            if (mounted) setState(() => _quranRecordings = []);
          },
        );
  }

  // ===== منطق إظهار البطاقة الصفراء: الجمعة 6 صباحاً أو بعدها =====

  /// هل الأسبوع المنتهي (المؤهل) صار مرئياً؟
  /// يظهر فقط بعد الجمعة 6:00 صباحاً من الأسبوع الجاري —
  /// أو أي أسبوع أقدم انتهى قبل الآن.
  bool _isWeekCardVisible(DateTime weekEnd) {
    final now = DateTime.now();
    final endOfDay = DateTime(
      weekEnd.year,
      weekEnd.month,
      weekEnd.day,
      23,
      59,
      59,
    );
    // أسبوع انتهى بالكامل قبل الآن → مرئي دائماً
    if (now.isAfter(endOfDay)) return true;
    // الأسبوع الجاري — يظهر فقط الجمعة الساعة 6 صباحاً أو بعدها
    return now.weekday == 5 && now.hour >= 6;
  }

  /// هل الشهر المنتهي (المؤهل) صار مرئياً؟
  /// يظهر فقط في آخر يوم من الشهر أو بعده.
  bool _isMonthCardVisible(DateTime monthEnd) {
    final now = DateTime.now();
    final endOfDay = DateTime(
      monthEnd.year,
      monthEnd.month,
      monthEnd.day,
      23,
      59,
      59,
    );
    return now.isAfter(endOfDay);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final matna = widget.matna;
    final name = matna?.name ?? 'متن';
    final unitLabel = matna?.unitLabel ?? 'بيت';
    final totalCount = (matna?.totalCount ?? 0).toDouble();

    final recordings = [...widget.recordings]
      // الأحدث أولاً — الأقدم في الأسفل
      ..sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return bt.compareTo(at);
      });

    if (recordings.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              Text(
                widget.student.name,
                style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'لا توجد تسجيلات',
          message: 'لم يُسجّل أي حفظ في هذا المتن بعد',
        ),
      );
    }

    // ===== بناء قائمة العناصر: بطاقات يومية + صفراء أسبوعية/شهرية =====
    final items = <Widget>[];

    // ترويسة المتن
    items.add(
      Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    matna?.typeLabel ?? 'نظم',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'الطالب: ${widget.student.name}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );

    // ===== تجميع التسجيلات حسب اليوم =====
    final byDay = <DateTime, List<MutunRecording>>{};
    for (final r in recordings) {
      final key = DateTime(r.date.year, r.date.month, r.date.day);
      byDay.putIfAbsent(key, () => []).add(r);
    }
    final days = byDay.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // الأحدث أولاً

    // ===== الأسابيع (السبت → الجمعة) =====
    final weekCards = <_YellowPeriodInfo>[];
    if (days.isNotEmpty) {
      var weekStart = days.last.subtract(
        Duration(days: (days.last.weekday % 7)),
      );
      int weekNumber = 1;
      // عدّ الأسابيع من أول تسجيل لترقيم صحيح
      final firstDate = days.last;
      var ws = firstDate.subtract(Duration(days: (firstDate.weekday % 7)));
      int n = 1;
      while (!ws.isAfter(days.first)) {
        ws = ws.add(const Duration(days: 7));
        n++;
      }
      weekNumber = n - 1;

      while (!weekStart.isAfter(days.first)) {
        final weekEnd = weekStart.add(const Duration(days: 6));
        final recsInWeek = recordings.where((r) {
          final d = DateTime(r.date.year, r.date.month, r.date.day);
          return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
        }).toList();

        if (recsInWeek.isNotEmpty && _isWeekCardVisible(weekEnd)) {
          weekCards.add(
            _YellowPeriodInfo(
              start: weekStart,
              end: weekEnd,
              recordings: recsInWeek,
              title: 'الأسبوع $weekNumber',
              isWeek: true,
            ),
          );
        }

        weekStart = weekStart.add(const Duration(days: 7));
        weekNumber++;
      }
    }

    // ===== الأشهر =====
    final monthCards = <_YellowPeriodInfo>[];
    if (days.isNotEmpty) {
      var cursor = DateTime(days.last.year, days.last.month);
      while (!cursor.isAfter(DateTime(days.first.year, days.first.month))) {
        final monthStart = DateTime(cursor.year, cursor.month);
        final monthEnd = DateTime(
          cursor.year,
          cursor.month + 1,
        ).subtract(const Duration(days: 1));
        final recsInMonth = recordings.where((r) {
          final d = DateTime(r.date.year, r.date.month, r.date.day);
          return !d.isBefore(monthStart) && !d.isAfter(monthEnd);
        }).toList();

        if (recsInMonth.isNotEmpty && _isMonthCardVisible(monthEnd)) {
          monthCards.add(
            _YellowPeriodInfo(
              start: monthStart,
              end: monthEnd,
              recordings: recsInMonth,
              title:
                  'شهر ${_monthArabicName(monthStart.month)} ${monthStart.year}',
              isWeek: false,
            ),
          );
        }

        cursor = DateTime(cursor.year, cursor.month + 1);
      }
    }

    // ===== دمج العناصر زمنياً: الأحدث في الأعلى =====
    // لكل يوم: بطاقة يومية + البطاقات الصفراء التي تنتهي فيها
    final allPeriods = [...weekCards, ...monthCards];
    // خريطة: تاريخ نهاية الفترة ← البطاقات المنتهية في ذلك اليوم
    final yellowByEndDay = <DateTime, List<_YellowPeriodInfo>>{};
    for (final p in allPeriods) {
      final key = DateTime(p.end.year, p.end.month, p.end.day);
      yellowByEndDay.putIfAbsent(key, () => []).add(p);
    }

    for (final day in days) {
      // البطاقات الصفراء التي تنتهي في هذا اليوم (تظهر فوق اليوميات)
      final yellows = yellowByEndDay[day];
      if (yellows != null) {
        for (final y in yellows) {
          items.add(
            _YellowPeriodCard(
              info: y,
              unitLabel: unitLabel,
              totalCount: totalCount,
              student: widget.student,
              quranRecordings: _quranRecordings,
            ),
          );
        }
      }

      // البطاقة اليومية
      final dayRecs = byDay[day]!;
      items.add(
        _StudentDailyCard(
          date: day,
          recordings: dayRecs,
          unitLabel: unitLabel,
          totalCount: totalCount,
          student: widget.student,
          quranRecordings: _quranRecordings,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _StudentDayChartsScreen(
                date: day,
                recordings: dayRecs,
                matna: widget.matna,
                student: widget.student,
                quranRecordings: _quranRecordings,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name),
            Text(
              '${widget.student.name} — بطاقات التسجيل',
              style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: items,
        ),
      ),
    );
  }

  static String _monthArabicName(int month) {
    const names = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return names[month - 1];
  }
}

/// معلومات فترة صفراء (أسبوع/شهر)
class _YellowPeriodInfo {
  final DateTime start;
  final DateTime end;
  final List<MutunRecording> recordings;
  final String title;
  final bool isWeek;

  const _YellowPeriodInfo({
    required this.start,
    required this.end,
    required this.recordings,
    required this.title,
    required this.isWeek,
  });
}

// ==================== البطاقة اليومية للطالب ====================

class _StudentDailyCard extends StatelessWidget {
  final DateTime date;
  final List<MutunRecording> recordings;
  final String unitLabel;
  final double totalCount;
  final Student student;
  final List<QuranRecording>? quranRecordings;
  final VoidCallback onTap;

  const _StudentDailyCard({
    required this.date,
    required this.recordings,
    required this.unitLabel,
    required this.totalCount,
    required this.student,
    required this.quranRecordings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText = DateFormat('d MMMM y', 'ar').format(date);
    final weekday = DateFormat('EEEE', 'ar').format(date);
    final isToday = _isSameDayLocal(date, DateTime.now());

    // حالة اليوم: غائب / لم يسمع / حاضر
    final anyAbsent = recordings.any((r) => r.isAbsent);
    final anyNotListened = recordings.any((r) => r.isNotListened);
    final flagColor = anyAbsent ? AppColors.error : AppColors.warning;
    final flagLabel = anyAbsent
        ? 'غائب'
        : anyNotListened
        ? 'لم يسمع'
        : null;

    // الورد القرآني لليوم
    final dayQuran = (quranRecordings ?? [])
        .where((q) => _isSameDayLocal(q.date, date))
        .toList();
    final quranPages = dayQuran.isEmpty
        ? 0.0
        : dayQuran.fold(0.0, (s, q) => s + q.count);

    // المقدار المنجز هذا اليوم (تجاهل الغياب)
    final units = recordings
        .where((r) => r.wasPresent)
        .fold(0.0, (s, r) => s + r.count);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: flagLabel != null
              ? flagColor.withValues(alpha: 0.5)
              : isToday
              ? AppColors.primary
              : AppColors.lineSoft,
          width: isToday || flagLabel != null ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primarySurface
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$weekday، $dateText',
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
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 14,
                      color: AppColors.inkMuted.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // شارة غائب / لم يسمع
                if (flagLabel != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: flagColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: flagColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          anyAbsent
                              ? Icons.event_busy_rounded
                              : Icons.hearing_disabled_rounded,
                          size: 18,
                          color: flagColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          flagLabel,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: flagColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'المنجز',
                      value: '${fmtNum(units)} $unitLabel',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.menu_book_rounded,
                      label: 'الورد القرآني',
                      value: dayQuran.isEmpty
                          ? '—'
                          : '${fmtNum(quranPages)} صفحة',
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

  static bool _isSameDayLocal(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ==================== البطاقة الصفراء الأسبوعية/الشهرية ====================

class _YellowPeriodCard extends StatelessWidget {
  final _YellowPeriodInfo info;
  final String unitLabel;
  final double totalCount;
  final Student student;
  final List<QuranRecording>? quranRecordings;

  const _YellowPeriodCard({
    required this.info,
    required this.unitLabel,
    required this.totalCount,
    required this.student,
    required this.quranRecordings,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final startText = DateFormat('d MMMM', 'ar').format(info.start);
    final endText = DateFormat('d MMMM y', 'ar').format(info.end);

    // المنجز خلال الفترة (تجاهل الغياب/لم يسمع)
    final units = info.recordings
        .where((r) => r.wasPresent)
        .fold(0.0, (s, r) => s + r.count);

    // آخر نقطة وصل إليها الطالب في المتن
    final lastReached = info.recordings
        .where((r) => r.wasPresent)
        .fold(0.0, (max, r) => r.to > max ? r.to : max);
    final remaining = totalCount > 0 ? totalCount - lastReached : 0.0;

    // الورد القرآني خلال الفترة
    final quranInPeriod = (quranRecordings ?? [])
        .where(
          (q) =>
              !q.date.isBefore(
                DateTime(info.start.year, info.start.month, info.start.day),
              ) &&
              !q.date.isAfter(
                DateTime(
                  info.end.year,
                  info.end.month,
                  info.end.day,
                  23,
                  59,
                  59,
                ),
              ),
        )
        .toList();
    final quranPages = quranInPeriod.isEmpty
        ? 0.0
        : quranInPeriod.fold(0.0, (s, q) => s + q.count);

    // أيام الغياب خلال الفترة
    final absentDays = info.recordings.where((r) => r.isAbsent).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => _showPeriodDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        info.isWeek
                            ? Icons.date_range_rounded
                            : Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تقرير ${info.title}',
                            style: textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$startText ← $endText',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        info.isWeek ? 'أسبوعي' : 'شهري',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      _YellowStatRow(
                        label:
                            'المنجز خلال ${info.isWeek ? 'الأسبوع' : 'الشهر'}',
                        value: '${fmtNum(units)} $unitLabel',
                        icon: Icons.task_alt_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      _YellowStatRow(
                        label: 'المتبقي من المتن',
                        value:
                            '${fmtNum(remaining > 0 ? remaining : 0)} $unitLabel',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.goldDark,
                      ),
                      const SizedBox(height: 8),
                      _YellowStatRow(
                        label: 'الورد القرآني',
                        value: '${fmtNum(quranPages)} صفحة',
                        icon: Icons.menu_book_rounded,
                        color: AppColors.primary,
                      ),
                      if (absentDays > 0) ...[
                        const SizedBox(height: 8),
                        _YellowStatRow(
                          label: 'أيام الغياب',
                          value: '$absentDays',
                          icon: Icons.event_busy_rounded,
                          color: AppColors.error,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPeriodDetails(BuildContext context) {
    // بطاقة تفصيلية عبر BottomSheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _YellowPeriodDetailsSheet(
        info: info,
        unitLabel: unitLabel,
        totalCount: totalCount,
        student: student,
        quranRecordings: quranRecordings,
      ),
    );
  }
}

// ==================== صف إحصائية في البطاقة الصفراء ====================

class _YellowStatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _YellowStatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ==================== لوحة تفاصيل الفترة الصفراء ====================

class _YellowPeriodDetailsSheet extends StatelessWidget {
  final _YellowPeriodInfo info;
  final String unitLabel;
  final double totalCount;
  final Student student;
  final List<QuranRecording>? quranRecordings;

  const _YellowPeriodDetailsSheet({
    required this.info,
    required this.unitLabel,
    required this.totalCount,
    required this.student,
    required this.quranRecordings,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final units = info.recordings
        .where((r) => r.wasPresent)
        .fold(0.0, (s, r) => s + r.count);
    final lastReached = info.recordings
        .where((r) => r.wasPresent)
        .fold(0.0, (max, r) => r.to > max ? r.to : max);
    final remaining = totalCount > 0 ? totalCount - lastReached : 0.0;
    final percent = totalCount > 0
        ? ((lastReached / totalCount).clamp(0.0, 1.0) * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: SingleChildScrollView(
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
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تقرير ${info.title}', style: textTheme.titleMedium),
                      Text(
                        '${student.name} — ${DateFormat('d MMMM y', 'ar').format(info.start)} ← ${DateFormat('d MMMM y', 'ar').format(info.end)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _YellowStatRow(
              label: 'المنجز خلال الفترة',
              value: '${fmtNum(units)} $unitLabel',
              icon: Icons.task_alt_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _YellowStatRow(
              label: 'آخر ما وصل إليه الطالب',
              value:
                  '${fmtNum(lastReached)} من ${fmtNum(totalCount)} $unitLabel',
              icon: Icons.flag_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _YellowStatRow(
              label: 'المتبقي من المتن',
              value: '${fmtNum(remaining > 0 ? remaining : 0)} $unitLabel',
              icon: Icons.pending_actions_rounded,
              color: AppColors.goldDark,
            ),
            const SizedBox(height: 10),
            _YellowStatRow(
              label: 'نسبة إتمام المتن',
              value: '$percent%',
              icon: Icons.percent_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(height: 18),

            // قائمة أيام الفترة
            Text('أيام الفترة:', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            ...info.recordings.map((r) {
              final dateText = DateFormat('d MMMM y', 'ar').format(r.date);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: r.isAbsent
                      ? AppColors.errorSurface
                      : r.isNotListened
                      ? AppColors.warningSurface
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    if (r.isAbsent || r.isNotListened)
                      Icon(
                        r.isAbsent
                            ? Icons.event_busy_rounded
                            : Icons.hearing_disabled_rounded,
                        size: 16,
                        color: r.isAbsent ? AppColors.error : AppColors.warning,
                      )
                    else
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${r.weekday}، $dateText',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      r.isAbsent
                          ? 'غائب'
                          : r.isNotListened
                          ? 'لم يسمع'
                          : '${fmtNum(r.count)} $unitLabel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: r.isAbsent
                            ? AppColors.error
                            : r.isNotListened
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ==================== شاشة الرسمين الدائريين (البطاقة اليومية) ====================

class _StudentDayChartsScreen extends StatelessWidget {
  final DateTime date;
  final List<MutunRecording> recordings;
  final Matna? matna;
  final Student student;
  final List<QuranRecording>? quranRecordings;

  const _StudentDayChartsScreen({
    required this.date,
    required this.recordings,
    required this.matna,
    required this.student,
    required this.quranRecordings,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateText = DateFormat('d MMMM y', 'ar').format(date);
    final weekday = DateFormat('EEEE', 'ar').format(date);
    final unitLabel = matna?.unitLabel ?? 'بيت';
    final totalCount = (matna?.totalCount ?? 0).toDouble();

    // ===== حالة اليوم =====
    final anyAbsent = recordings.any((r) => r.isAbsent);
    final anyNotListened = recordings.any((r) => r.isNotListened);

    // ===== الرسم الأول: المنجز / المتبقي =====
    final lastReached = recordings
        .where((r) => r.wasPresent)
        .fold(0.0, (max, r) => r.to > max ? r.to : max);
    final remaining = totalCount > 0 ? totalCount - lastReached : 0.0;
    final progressPercent = totalCount > 0
        ? ((lastReached / totalCount).clamp(0.0, 1.0) * 100).round()
        : 0;

    // ===== الرسم الثاني: الورد القرآني لليوم =====
    final dayQuran = (quranRecordings ?? [])
        .where(
          (q) =>
              q.date.year == date.year &&
              q.date.month == date.month &&
              q.date.day == date.day,
        )
        .toList();
    final quranPages = dayQuran.isEmpty
        ? 0.0
        : dayQuran.fold(0.0, (s, q) => s + q.count);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رسم بياني للحفظ'),
            Text(
              '$weekday، $dateText',
              style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
      body: WatermarkedBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة الطالب
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    InitialAvatar(name: student.name, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            matna?.name ?? 'متن',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // شارة الغياب إن وجدت
              if (anyAbsent || anyNotListened) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: anyAbsent
                        ? AppColors.errorSurface
                        : AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: anyAbsent
                          ? AppColors.error.withValues(alpha: 0.4)
                          : AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        anyAbsent
                            ? Icons.event_busy_rounded
                            : Icons.hearing_disabled_rounded,
                        color: anyAbsent ? AppColors.error : AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          anyAbsent
                              ? 'الطالب غائب هذا اليوم — سجّله المعلم'
                              : 'لم يسمع الطالب هذا اليوم — سجّله المعلم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: anyAbsent
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ===== الرسم الأول: المنجز/المتبقي =====
              _ChartCard(
                title: 'المنجز والمتبقي من المتن',
                subtitle:
                    'من ${fmtNum(lastReached)} من أصل ${fmtNum(totalCount)} $unitLabel',
                chart: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: PieChart(
                        PieChartData(
                          startDegreeOffset: 270,
                          sectionsSpace: 0,
                          centerSpaceRadius: 52,
                          sections: [
                            PieChartSectionData(
                              value: lastReached > 0 ? lastReached : 0.0001,
                              color: AppColors.primary,
                              radius: 16,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: remaining > 0 ? remaining : 0.0001,
                              color: AppColors.lineSoft,
                              radius: 16,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$progressPercent%',
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'منجز',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                legend: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(
                      color: AppColors.primary,
                      label:
                          'المنجز ${fmtNum(lastReached)} $unitLabel ($progressPercent%)',
                    ),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: AppColors.lineSoft,
                      label:
                          'المتبقي ${fmtNum(remaining > 0 ? remaining : 0)} $unitLabel (${100 - progressPercent}%)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ===== الرسم الثاني: الورد القرآني =====
              _ChartCard(
                title: 'الورد القرآني المسموع هذا اليوم',
                subtitle: dayQuran.isEmpty
                    ? 'لا يوجد ورد مسجّل هذا اليوم'
                    : dayQuran
                          .map(
                            (q) =>
                                'صفحات ${fmtNum(q.fromPage)} ← ${fmtNum(q.toPage)}',
                          )
                          .join(' • '),
                chart: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: PieChart(
                        PieChartData(
                          startDegreeOffset: 270,
                          sectionsSpace: 0,
                          centerSpaceRadius: 52,
                          sections: [
                            PieChartSectionData(
                              value: quranPages > 0 ? quranPages : 0.0001,
                              color: AppColors.gold,
                              radius: 16,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: (AppConstants.khatmaPages - quranPages) > 0
                                  ? (AppConstants.khatmaPages - quranPages)
                                  : 0.0001,
                              color: AppColors.lineSoft,
                              radius: 16,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fmtNum(quranPages),
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.goldDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'صفحة',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                legend: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(
                      color: AppColors.gold,
                      label: 'مسموع ${fmtNum(quranPages)} صفحة',
                    ),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: AppColors.lineSoft,
                      label: 'من أصل ${AppConstants.khatmaPages} صفحة (الختمة)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // تفاصيل التسجيلات اليومية
              if (recordings.where((r) => r.wasPresent).isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.lineSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تفاصيل الحفظ هذا اليوم',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      ...recordings
                          .where((r) => r.wasPresent)
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'من ${fmtNum(r.from)} إلى ${fmtNum(r.to)} (${fmtNum(r.count)} $unitLabel)',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (notesOf(recordings) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'ملاحظات: ${notesOf(recordings)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String? notesOf(List<MutunRecording> recs) {
    for (final r in recs) {
      if (r.notes != null && r.notes!.isNotEmpty) {
        return r.notes;
      }
    }
    return null;
  }
}

// ==================== بطاقة رسم بياني ====================

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget chart;
  final Widget legend;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.chart,
    required this.legend,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          Center(child: chart),
          const SizedBox(height: 16),
          legend,
        ],
      ),
    );
  }
}

// ==================== نقطة مفتاح الرسم ====================

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.inkSecondary),
        ),
      ],
    );
  }
}
