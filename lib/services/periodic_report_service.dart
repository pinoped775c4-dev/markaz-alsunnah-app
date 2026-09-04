import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../models/matna.dart';
import '../models/quran.dart';
import '../models/student.dart';

// ==================== نماذج التقارير الدورية ====================

/// بيانات طالب واحد في التقرير الدوري
class PeriodicStudentData {
  final Student student;

  // منجز الأبيات/الصفحات من المتون
  final int mutunAchieved;
  final int mutunTotal; // إجمالي وحدات المتن

  // منجز صفحات الورد القرآني
  final int quranPagesAchieved;

  // حضور
  final int presentDays;
  final int totalDays;
  final List<String> absentNames; // أسماء أيام الغياب (للمعلمين)

  const PeriodicStudentData({
    required this.student,
    this.mutunAchieved = 0,
    this.mutunTotal = 0,
    this.quranPagesAchieved = 0,
    this.presentDays = 0,
    this.totalDays = 0,
    this.absentNames = const [],
  });

  double get attendancePercent =>
      totalDays == 0 ? 0 : (presentDays / totalDays).clamp(0, 1);

  int get absentDays => totalDays - presentDays;
}

/// بيانات مستوى واحد في التقرير الدوري
class PeriodicPathwayData {
  final String pathwayId;
  final String pathwayName;
  final List<PeriodicStudentData> students;

  const PeriodicPathwayData({
    required this.pathwayId,
    required this.pathwayName,
    required this.students,
  });
}

/// بيانات تقرير دوري كامل (أسبوعي أو شهري)
class PeriodicReportData {
  final bool isWeekly; // true=أسبوعي, false=شهري
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime issueDate;
  final List<PeriodicPathwayData> pathways;
  final String teacherName; // اسم المعلم (للتقارير المعلمين)
  final bool isTeacherReport; // true=تقرير معلمين, false=تقرير طلاب

  const PeriodicReportData({
    required this.isWeekly,
    required this.periodStart,
    required this.periodEnd,
    required this.pathways,
    required this.teacherName,
    this.isTeacherReport = true,
    DateTime? issueDate,
  }) : issueDate = issueDate ?? periodEnd;

  String get periodLabel {
    final start = DateFormat('d MMMM', 'ar').format(periodStart);
    final end = DateFormat('d MMMM yyyy', 'ar').format(periodEnd);
    return isWeekly ? 'الأسبوع: $start – $end' : 'شهر ${DateFormat('MMMM yyyy', 'ar').format(periodStart)}';
  }

  String get typeLabel => isWeekly ? 'التقرير الأسبوعي' : 'التقرير الشهري';
}

// ==================== خدمة جمع بيانات التقارير الدورية ====================

class PeriodicReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// جلب بيانات تقرير دوري للمعلم المسؤول
  /// [teacherId] = UID المعلم المسؤول
  /// [periodStart] / [periodEnd] = نطاق الفترة
  Future<PeriodicReportData> buildTeacherPeriodicReport({
    required String teacherId,
    required String teacherName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required bool isWeekly,
    required List<PathwayInfo> pathways,
  }) async {
    final pathwayDataList = <PeriodicPathwayData>[];

    for (final pathway in pathways) {
      // 1. جلب الطلاب (شرط واحد + فلترة محلية)
      final studentsSnap = await _firestore
          .collection('students')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      final students = studentsSnap.docs
          .map((d) => Student.fromFirestore(d))
          .where((s) => s.pathwayId == pathway.id && s.isActive)
          .toList();

      if (students.isEmpty) continue;

      // 2. جلب تسجيلات المتون الرسمية للمعلم في هذه الفترة
      final mutunSnap = await _firestore
          .collection('mutun_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      final mutunRecs = mutunSnap.docs
          .map((d) => MutunRecording.fromFirestore(d))
          .where((r) =>
              r.pathwayId == pathway.id &&
              r.isOfficial &&
              !r.date.isBefore(periodStart) &&
              !r.date.isAfter(periodEnd))
          .toList();

      // 3. جلب تسجيلات الورد القرآني الرسمية
      final quranSnap = await _firestore
          .collection('quran_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      final quranRecs = quranSnap.docs
          .map((d) => QuranRecording.fromFirestore(d))
          .where((r) =>
              r.pathwayId == pathway.id &&
              r.isOfficial &&
              !r.date.isBefore(periodStart) &&
              !r.date.isAfter(periodEnd))
          .toList();

      // 4. جلب سجلات الدروس (الحضور) — من lesson_recordings
      final lessonsSnap = await _firestore
          .collection('lesson_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      // مجموعة كل التاريخ للدروس في الفترة
      final lessonDates = lessonsSnap.docs
          .where((d) {
            final ts = d.data()['date'];
            if (ts == null) return false;
            final date = (ts as Timestamp).toDate();
            return d.data()['pathwayId'] == pathway.id &&
                !date.isBefore(periodStart) &&
                !date.isAfter(periodEnd);
          })
          .map((d) => (d.data()['date'] as Timestamp).toDate())
          .toSet();
      final totalLessonDays = lessonDates.length;

      // 5. بناء بيانات كل طالب
      final studentDataList = <PeriodicStudentData>[];
      for (final student in students) {
        // منجز المتون
        final studentMutun = mutunRecs
            .where((r) => r.studentId == student.id && r.wasPresent)
            .toList();
        final mutunAchieved = studentMutun.fold(0.0, (s, r) => s + r.count).round();

        // منجز الورد القرآني
        final studentQuran = quranRecs
            .where((r) => r.studentId == student.id)
            .toList();
        final quranAchieved = studentQuran.fold(0.0, (s, r) => s + r.count).round();

        // حضور (من تسجيلات المتون — present = حضر، absent = غاب)
        final studentMutunAll = mutunRecs
            .where((r) => r.studentId == student.id)
            .toList();
        final presentDays = studentMutunAll
            .where((r) => r.wasPresent)
            .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
            .toSet()
            .length;
        final absentDays = studentMutunAll
            .where((r) => r.isAbsent || r.isNotListened)
            .map((r) => DateFormat('EEEE d/M', 'ar').format(r.date))
            .toList();

        studentDataList.add(PeriodicStudentData(
          student: student,
          mutunAchieved: mutunAchieved,
          mutunTotal: 0, // لا نحسب الإجمالي هنا
          quranPagesAchieved: quranAchieved,
          presentDays: presentDays,
          totalDays: totalLessonDays > 0 ? totalLessonDays : studentMutunAll.length,
          absentNames: absentDays,
        ));
      }

      if (studentDataList.isNotEmpty) {
        pathwayDataList.add(PeriodicPathwayData(
          pathwayId: pathway.id,
          pathwayName: pathway.name,
          students: studentDataList,
        ));
      }
    }

    return PeriodicReportData(
      isWeekly: isWeekly,
      periodStart: periodStart,
      periodEnd: periodEnd,
      pathways: pathwayDataList,
      teacherName: teacherName,
      isTeacherReport: true,
    );
  }
}

// ==================== مولّد PDF الجديد ====================

class NewReportPdfService {
  static const _primaryColor = PdfColor.fromInt(0xFF0E7C5B);
  static const _goldColor = PdfColor.fromInt(0xFFC09A3E);
  static const _inkColor = PdfColor.fromInt(0xFF14201C);
  static const _inkSecondary = PdfColor.fromInt(0xFF5C6B65);
  static const _lineSoft = PdfColor.fromInt(0xFFEEF2F0);
  static const _primarySurface = PdfColor.fromInt(0xFFE8F5F0);
  static const _errorColor = PdfColor.fromInt(0xFFD84A4A);
  static const _successColor = PdfColor.fromInt(0xFF1F9D63);
  static const _warningColor = PdfColor.fromInt(0xFFE39A2D);

  /// تصدير تقرير دوري كـ PDF — يفتح واجهة المشاركة
  static Future<void> exportPeriodicPdf(PeriodicReportData report) async {
    final pdfBytes = await _buildPdf(report);
    final fileName =
        '${report.isWeekly ? "weekly" : "monthly"}_report_${DateFormat('yyyy_MM_dd').format(report.issueDate)}.pdf';

    await _shareFile(pdfBytes, fileName, 'application/pdf');
  }

  /// تصدير تقرير دوري كـ Word (HTML .doc)
  static Future<void> exportPeriodicWord(PeriodicReportData report) async {
    final html = _buildWordHtml(report);
    final bytes = Uint8List.fromList(html.codeUnits);
    final fileName =
        '${report.isWeekly ? "weekly" : "monthly"}_report_${DateFormat('yyyy_MM_dd').format(report.issueDate)}.doc';

    await _shareFile(bytes, fileName, 'application/msword');
  }

  static Future<void> _shareFile(
      Uint8List bytes, String fileName, String mimeType) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: mimeType)]);
    } catch (e) {
      debugPrint('NewReportPdfService._shareFile error: $e');
    }
  }

  // ========== بناء PDF ==========

  static Future<Uint8List> _buildPdf(PeriodicReportData report) async {
    // تحميل الخط العربي
    final fontData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final arabicFont = pw.Font.ttf(fontData);

    // تحميل الشعار
    final logoBytes =
        await rootBundle.load(AppConstants.logoAsset);
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final pdf = pw.Document();

    // بناء محتوى كل مستوى في صفحة منفصلة
    for (final pathway in report.pathways) {
      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => [
            _buildWatermarkStack(logoImage,
                pw.Column(
                  children: [
                    _buildHeader(report, arabicFont, logoImage),
                    pw.SizedBox(height: 14),
                    _buildPathwaySection(pathway, report, arabicFont),
                    pw.SizedBox(height: 8),
                    _buildFooter(report, arabicFont),
                  ],
                )),
          ],
        ),
      );
    }

    // إذا لا يوجد أي مستوى — صفحة واحدة فارغة بالترويسة
    if (report.pathways.isEmpty) {
      pdf.addPage(
        pw.Page(
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont),
          build: (ctx) => _buildWatermarkStack(logoImage,
              pw.Column(
                children: [
                  _buildHeader(report, arabicFont, logoImage),
                  pw.SizedBox(height: 40),
                  pw.Center(
                    child: pw.Text(
                      'لا توجد بيانات في هذه الفترة',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 14,
                        color: _inkSecondary,
                      ),
                    ),
                  ),
                ],
              )),
        ),
      );
    }

    return pdf.save();
  }

  /// ترويسة الصفحة: شعار المركز + اسم المركز يسار + تاريخ الإصدار يمين
  static pw.Widget _buildHeader(
      PeriodicReportData report, pw.Font font, pw.MemoryImage logo) {
    final issueDateStr =
        DateFormat('d MMMM yyyy', 'ar').format(report.issueDate);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // السطر الأول: تاريخ الإصدار يمين + اسم المركز يسار
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // يمين: تاريخ الإصدار
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'تاريخ الإصدار',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: _inkSecondary,
                  ),
                ),
                pw.Text(
                  issueDateStr,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            // وسط: الشعار
            pw.Image(logo, width: 70, height: 70),
            // يسار: اسم المركز
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'مركز السنة للعلوم الشرعية',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                pw.Text(
                  'وتأهيل الدعاة',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                pw.Text(
                  'شبوة - عتق',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: _goldColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        // خط فاصل بلون المركز
        pw.Container(
          height: 2,
          color: _primaryColor,
        ),
        pw.SizedBox(height: 6),
        // عنوان التقرير
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _primaryColor,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            '${report.typeLabel} — ${report.periodLabel}',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// قسم مستوى واحد مع بياناته
  static pw.Widget _buildPathwaySection(
      PeriodicPathwayData pathway, PeriodicReportData report, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // عنوان المستوى
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _primarySurface,
            border: pw.Border(
              right: pw.BorderSide(color: _primaryColor, width: 4),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                pathway.pathwayName,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                '${pathway.students.length} طالب',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: _inkSecondary,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        // جدول الطلاب
        _buildStudentsTable(pathway.students, font),
        pw.SizedBox(height: 12),
        // الرسوم البيانية (أشرطة تقدم)
        _buildPathwayCharts(pathway.students, font),
      ],
    );
  }

  /// جدول بيانات الطلاب
  static pw.Widget _buildStudentsTable(
      List<PeriodicStudentData> students, pw.Font font) {
    final headerStyle = pw.TextStyle(
      font: font,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(font: font, fontSize: 9, color: _inkColor);

    return pw.Table(
      border: pw.TableBorder.all(color: _lineSoft, width: 0.5),
      children: [
        // رأس الجدول
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primaryColor),
          children: [
            _tableCell('اسم الطالب', headerStyle, isHeader: true),
            _tableCell('المنجز (بيت/صفحة)', headerStyle, isHeader: true),
            _tableCell('الورد القرآني', headerStyle, isHeader: true),
            _tableCell('الحضور %', headerStyle, isHeader: true),
            _tableCell('أيام الغياب', headerStyle, isHeader: true),
          ],
        ),
        // بيانات الطلاب
        for (int i = 0; i < students.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : _lineSoft,
            ),
            children: [
              _tableCell(students[i].student.name, cellStyle),
              _tableCell('${students[i].mutunAchieved}', cellStyle),
              _tableCell('${students[i].quranPagesAchieved} ص', cellStyle),
              _tableCell(
                '${(students[i].attendancePercent * 100).round()}%',
                cellStyle.copyWith(
                  color: students[i].attendancePercent >= 0.8
                      ? _successColor
                      : students[i].attendancePercent >= 0.6
                          ? _warningColor
                          : _errorColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              _tableCell('${students[i].absentDays}', cellStyle),
            ],
          ),
      ],
    );
  }

  static pw.Widget _tableCell(String text, pw.TextStyle style,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: style,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// رسوم بيانية (أشرطة تقدم) للطلاب
  static pw.Widget _buildPathwayCharts(
      List<PeriodicStudentData> students, pw.Font font) {
    if (students.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'نسب الحضور',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 6),
        for (final s in students) ...[
          pw.Row(
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text(
                  s.student.name,
                  style: pw.TextStyle(font: font, fontSize: 8, color: _inkColor),
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.SizedBox(width: 6),
              // شريط التقدم
              pw.Expanded(
                child: pw.Stack(
                  children: [
                    // الخلفية
                    pw.Container(
                      height: 12,
                      decoration: pw.BoxDecoration(
                        color: _lineSoft,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                    ),
                    // التقدم
                    pw.Container(
                      width: 150 * s.attendancePercent.clamp(0.0, 1.0),
                      height: 12,
                      decoration: pw.BoxDecoration(
                        color: s.attendancePercent >= 0.8
                            ? _successColor
                            : s.attendancePercent >= 0.6
                                ? _warningColor
                                : _errorColor,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                '${(s.attendancePercent * 100).round()}%',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: s.attendancePercent >= 0.8
                      ? _successColor
                      : s.attendancePercent >= 0.6
                          ? _warningColor
                          : _errorColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
        ],
        pw.SizedBox(height: 6),
        // شريط المنجز من المتون
        pw.Text(
          'المنجز من المتون والأوراد',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _goldColor,
          ),
        ),
        pw.SizedBox(height: 6),
        for (final s in students) ...[
          pw.Row(
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text(
                  s.student.name,
                  style: pw.TextStyle(font: font, fontSize: 8, color: _inkColor),
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    // منجز المتون
                    pw.Container(
                      width: (s.mutunAchieved / (students.map((x) => x.mutunAchieved).reduce((a, b) => a > b ? a : b) + 1)) * 100,
                      height: 10,
                      color: _primaryColor,
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      '${s.mutunAchieved}ب',
                      style: pw.TextStyle(font: font, fontSize: 7, color: _primaryColor),
                    ),
                    pw.SizedBox(width: 8),
                    // منجز الورد
                    pw.Container(
                      width: (s.quranPagesAchieved / (students.map((x) => x.quranPagesAchieved).reduce((a, b) => a > b ? a : b) + 1)) * 80,
                      height: 10,
                      color: _goldColor,
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      '${s.quranPagesAchieved}ص',
                      style: pw.TextStyle(font: font, fontSize: 7, color: _goldColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
        ],
      ],
    );
  }

  /// تذييل الصفحة
  static pw.Widget _buildFooter(PeriodicReportData report, pw.Font font) {
    return pw.Column(
      children: [
        pw.Container(height: 1, color: _lineSoft),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'تقرير ${report.isTeacherReport ? "المعلمين" : "الطلاب"} — ${AppConstants.centerName}',
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: _inkSecondary,
              ),
            ),
            pw.Text(
              'شبوة - عتق',
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: _inkSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// العلامة المائية + المحتوى في Stack
  static pw.Widget _buildWatermarkStack(
      pw.MemoryImage logo, pw.Widget content) {
    return pw.Stack(
      children: [
        // العلامة المائية في الخلفية
        pw.Positioned.fill(
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.055,
              child: pw.Image(logo, width: 380, height: 380),
            ),
          ),
        ),
        // المحتوى في المقدمة
        content,
      ],
    );
  }

  // ========== بناء Word (HTML .doc) ==========

  static String _buildWordHtml(PeriodicReportData report) {
    final issueDateStr =
        DateFormat('d MMMM yyyy', 'ar').format(report.issueDate);

    final pathwaysHtml = report.pathways.map((pathway) {
      final rows = pathway.students.map((s) {
        final attendColor = s.attendancePercent >= 0.8
            ? '#1F9D63'
            : s.attendancePercent >= 0.6
                ? '#E39A2D'
                : '#D84A4A';
        return '''
          <tr>
            <td style="padding:6px 10px;border:1px solid #EEF2F0;">${s.student.name}</td>
            <td style="padding:6px 10px;border:1px solid #EEF2F0;text-align:center;">${s.mutunAchieved}</td>
            <td style="padding:6px 10px;border:1px solid #EEF2F0;text-align:center;">${s.quranPagesAchieved} ص</td>
            <td style="padding:6px 10px;border:1px solid #EEF2F0;text-align:center;color:$attendColor;font-weight:bold;">${(s.attendancePercent * 100).round()}%</td>
            <td style="padding:6px 10px;border:1px solid #EEF2F0;text-align:center;">${s.absentDays}</td>
          </tr>
        ''';
      }).join('');

      return '''
        <h3 style="color:#0E7C5B;border-right:4px solid #0E7C5B;padding-right:10px;margin-top:20px;">
          ${pathway.pathwayName} — ${pathway.students.length} طالب
        </h3>
        <table style="width:100%;border-collapse:collapse;margin-bottom:16px;">
          <thead>
            <tr style="background:#0E7C5B;color:white;">
              <th style="padding:8px;border:1px solid #0E7C5B;">اسم الطالب</th>
              <th style="padding:8px;border:1px solid #0E7C5B;">المنجز (بيت/صفحة)</th>
              <th style="padding:8px;border:1px solid #0E7C5B;">الورد القرآني</th>
              <th style="padding:8px;border:1px solid #0E7C5B;">الحضور %</th>
              <th style="padding:8px;border:1px solid #0E7C5B;">أيام الغياب</th>
            </tr>
          </thead>
          <tbody>$rows</tbody>
        </table>
      ''';
    }).join('');

    return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar" xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <title>${report.typeLabel}</title>
  <style>
    @page {
      mso-page-orientation:portrait;
      margin:2cm;
    }
    body {
      font-family:"Cairo","Arial",sans-serif;
      direction:rtl;
      font-size:11pt;
      color:#14201C;
    }
    .header-table { width:100%;margin-bottom:14px; }
    .center-name { color:#0E7C5B;font-weight:bold;font-size:13pt; }
    .location { color:#C09A3E;font-size:10pt; }
    .date-box { color:#0E7C5B;font-weight:bold;font-size:11pt; }
    .report-title {
      background:#0E7C5B;color:white;
      padding:8px 18px;text-align:center;
      font-size:13pt;font-weight:bold;
      border-radius:6px;margin:10px 0;
    }
    hr { border:none;border-top:2px solid #0E7C5B;margin:10px 0; }
    .footer { color:#5C6B65;font-size:9pt;margin-top:16px; }
  </style>
</head>
<body>
  <!-- الترويسة -->
  <table class="header-table">
    <tr>
      <td style="width:33%;text-align:right;">
        <div class="date-box">تاريخ الإصدار<br>$issueDateStr</div>
      </td>
      <td style="width:33%;text-align:center;">
        <div class="center-name">مركز السنة للعلوم الشرعية<br>وتأهيل الدعاة</div>
        <div class="location">شبوة - عتق</div>
      </td>
      <td style="width:33%;text-align:left;">
        <div style="color:#5C6B65;font-size:9pt;">
          ${report.isTeacherReport ? "تقرير المعلمين" : "تقرير الطلاب"}
        </div>
      </td>
    </tr>
  </table>
  <hr>
  <div class="report-title">${report.typeLabel} — ${report.periodLabel}</div>
  
  $pathwaysHtml
  
  <div class="footer">
    <hr>
    ${AppConstants.centerName} — ${AppConstants.centerLocation}
  </div>
</body>
</html>
''';
  }
}
