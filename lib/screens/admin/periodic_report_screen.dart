import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/mutun_wird_service.dart';
import '../../services/periodic_report_service.dart';
import '../../services/teachers_service.dart';
import '../../widgets/branding.dart';
import '../../widgets/common_widgets.dart';

// ==========================================
// شاشة معاينة وتصدير التقرير الدوري
// ==========================================
class PeriodicReportScreen extends StatefulWidget {
  final bool isWeekly;
  final bool isTeacherReport;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String teacherId;
  final String teacherName;
  final List<PathwayInfo> pathways;

  const PeriodicReportScreen({
    super.key,
    required this.isWeekly,
    required this.isTeacherReport,
    required this.periodStart,
    required this.periodEnd,
    required this.teacherId,
    required this.teacherName,
    required this.pathways,
  });

  @override
  State<PeriodicReportScreen> createState() => _PeriodicReportScreenState();
}

class _PeriodicReportScreenState extends State<PeriodicReportScreen> {
  final _service = PeriodicReportService();
  PeriodicReportData? _reportData;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final report = await _service.buildTeacherPeriodicReport(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        periodStart: widget.periodStart,
        periodEnd: widget.periodEnd,
        isWeekly: widget.isWeekly,
        pathways: widget.pathways,
      );

      if (mounted) {
        setState(() {
          _reportData = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ أثناء تحميل بيانات التقرير: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_reportData == null) return;
    setState(() => _isExporting = true);
    try {
      await NewReportPdfService.exportPeriodicPdf(_reportData!);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'فشل تصدير PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportWord() async {
    if (_reportData == null) return;
    setState(() => _isExporting = true);
    try {
      await NewReportPdfService.exportPeriodicWord(_reportData!);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'فشل تصدير Word: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final typeLabel = widget.isWeekly ? 'أسبوعي' : 'شهري';
    final reportLabel = widget.isTeacherReport ? 'المعلمين' : 'الطلاب';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التقرير ال$typeLabel — $reportLabel'),
            Text(
              _periodLabel,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
          ],
        ),
        actions: [
          if (!_isLoading && _reportData != null && !_isExporting) ...[
            IconButton(
              tooltip: 'تصدير PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              color: AppColors.error,
              onPressed: _exportPdf,
            ),
            IconButton(
              tooltip: 'تصدير Word',
              icon: const Icon(Icons.description_rounded),
              color: AppColors.primary,
              onPressed: _exportWord,
            ),
          ],
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: WatermarkedBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(message: _error!, onRetry: _loadReport)
                : _reportData == null
                    ? const EmptyState(
                        icon: Icons.description_outlined,
                        title: 'لا توجد بيانات',
                        message: 'لم يتم إنشاء التقرير',
                      )
                    : _buildReportPreview(textTheme),
      ),
      bottomNavigationBar: (!_isLoading && _reportData != null)
          ? _buildExportBar()
          : null,
    );
  }

  Widget _buildReportPreview(TextTheme textTheme) {
    final report = _reportData!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── ترويسة التقرير ─────────────────────────────────
        _ReportHeaderCard(report: report),
        const SizedBox(height: 16),

        if (report.pathways.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'لا توجد بيانات في هذه الفترة',
            message: 'لم تُسجَّل أي سجلات رسمية في الفترة المحددة',
          )
        else
          // ── مستويات التقرير ─────────────────────────────
          for (final pathway in report.pathways) ...[
            _PathwayReportCard(pathway: pathway),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildExportBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(
          top: BorderSide(color: AppColors.lineSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportWord,
              icon: const Icon(Icons.description_rounded),
              label: const Text('تصدير Word'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('تصدير PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _periodLabel {
    final start = DateFormat('d/M', 'ar').format(widget.periodStart);
    final end = DateFormat('d/M/yyyy', 'ar').format(widget.periodEnd);
    return '$start – $end';
  }
}

// ==========================================
// بطاقة ترويسة التقرير
// ==========================================
class _ReportHeaderCard extends StatelessWidget {
  final PeriodicReportData report;
  const _ReportHeaderCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final issueDateStr =
        DateFormat('d MMMM yyyy', 'ar').format(report.issueDate);

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          children: [
            // صف الترويسة العلوي
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  // يمين: تاريخ الإصدار
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'تاريخ الإصدار',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        issueDateStr,
                        style: textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // وسط: الشعار
                  CircularLogo(size: 58),
                  const Spacer(),
                  // يسار: اسم المركز
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مركز السنة',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'للعلوم الشرعية وتأهيل الدعاة',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        'شبوة - عتق',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.goldSoft,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // شريط عنوان التقرير
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black.withValues(alpha: 0.18),
              child: Text(
                '${report.typeLabel} — ${report.periodLabel}',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// بطاقة مستوى واحد في التقرير
// ==========================================
class _PathwayReportCard extends StatelessWidget {
  final PeriodicPathwayData pathway;
  const _PathwayReportCard({required this.pathway});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس المستوى
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              border: const Border(
                right: BorderSide(color: AppColors.primary, width: 3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pathway.pathwayName,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pathway.students.length} طالب',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── بطاقات الطلاب ──────────────────────────────
          for (final student in pathway.students) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            _StudentDataRow(student: student),
          ],

          // ── رسوم بيانية الحضور ─────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نسب الحضور',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in pathway.students) ...[
                  _AttendanceBar(student: s),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDataRow extends StatelessWidget {
  final PeriodicStudentData student;
  const _StudentDataRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = (student.attendancePercent * 100).round();
    final attendColor = student.attendancePercent >= 0.8
        ? AppColors.success
        : student.attendancePercent >= 0.6
            ? AppColors.warning
            : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // أفاتار الطالب
          InitialAvatar(name: student.student.name, radius: 20),
          const SizedBox(width: 10),
          // بيانات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.student.name,
                  style:
                      textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.auto_stories_rounded,
                      label: '${student.mutunAchieved} بيت/صفحة',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.menu_book_rounded,
                      label: '${student.quranPagesAchieved} ص',
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // نسبة الحضور
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$pct%',
                style: textTheme.titleSmall?.copyWith(
                  color: attendColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'حضور',
                style:
                    textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
              if (student.absentDays > 0)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'غاب ${student.absentDays}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontSize: 10,
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

class _AttendanceBar extends StatelessWidget {
  final PeriodicStudentData student;
  const _AttendanceBar({required this.student});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = student.attendancePercent.clamp(0.0, 1.0);
    final color = pct >= 0.8
        ? AppColors.success
        : pct >= 0.6
            ? AppColors.warning
            : AppColors.error;

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            student.student.name,
            style: textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppColors.lineSoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(pct * 100).round()}%',
          style: textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ==========================================
// منتقي فترة التقرير
// ==========================================

/// فتح منتقي الفترة للتقرير الأسبوعي/الشهري واختيار المعلم المسؤول
Future<void> openPeriodicReportPicker(
  BuildContext context, {
  required bool isWeekly,
  required bool isTeacherReport,
  required List<PathwayInfo> pathways,
}) async {
  // جلب المعلم المسؤول
  final wirdService = MutunWirdService();
  final teacherUid = await wirdService.getDesignatedTeacherUid();
  if (!context.mounted) return;

  if (teacherUid == null || teacherUid.isEmpty) {
    showErrorSnackBar(
        context, 'لم يُعيَّن معلم مسؤول عن المتون والأوراد بعد');
    return;
  }

  // جلب اسم المعلم
  final teachersService = TeachersService();
  final teachers = await teachersService.fetchActiveTeachers();
  final teacherName = teachers
      .where((t) => t.uid == teacherUid)
      .map((t) => t.name)
      .firstOrNull ?? 'المعلم المسؤول';

  if (!context.mounted) return;

  // اختيار الفترة
  final now = DateTime.now();
  DateTime periodStart;
  DateTime periodEnd;

  if (isWeekly) {
    // الأسبوع الماضي: السبت الماضي → الجمعة الماضية
    final daysSinceFriday = (now.weekday % 7); // 0 = الأحد
    final lastFriday = now.subtract(Duration(days: daysSinceFriday == 0 ? 1 : daysSinceFriday));
    periodEnd = DateTime(lastFriday.year, lastFriday.month, lastFriday.day, 23, 59, 59);
    periodStart = periodEnd.subtract(const Duration(days: 6));
    periodStart = DateTime(periodStart.year, periodStart.month, periodStart.day);
  } else {
    // الشهر الماضي
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    periodStart = lastMonth;
    periodEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
  }

  if (!context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PeriodicReportScreen(
        isWeekly: isWeekly,
        isTeacherReport: isTeacherReport,
        periodStart: periodStart,
        periodEnd: periodEnd,
        teacherId: teacherUid,
        teacherName: teacherName,
        pathways: pathways,
      ),
    ),
  );
}
