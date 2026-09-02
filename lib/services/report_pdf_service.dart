import '../core/constants.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/lesson.dart';
import 'reports_service.dart';

/// خدمة تصدير التقارير الأسبوعية والشهرية كملف PDF بالعربية (RTL)
class ReportPdfService {
  ReportPdfService._();

  static pw.Font? _font;
  static pw.Font? _fontBold;

  /// تحميل خط Cairo (يُحمَّل مرة واحدة)
  static Future<void> _ensureFont() async {
    if (_font != null && _fontBold != null) return;
    final data = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    _font = pw.Font.ttf(data);
    _fontBold = pw.Font.ttf(data);
  }

  static pw.TextStyle _s(double size,
          {bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        font: bold ? _fontBold : _font,
        fontSize: size,
        color: color ?? PdfColors.grey900,
      );

  /// تصدير تقرير فترة (أسبوع/شهر) كملف PDF جاهز للطباعة
  static Future<void> exportPeriodPdf({
    required PeriodCard period,
    required Lesson lesson,
    required List<LessonDayReport> dailyReports,
    required String teacherName,
    required String pathwayName,
  }) async {
    await _ensureFont();

    final isWeek = period.id.startsWith('week');
    final report = period.report;

    // أيام الفترة فقط (الأقدم أولاً)
    final periodDays = dailyReports.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return !d.isBefore(period.start) && !d.isAfter(period.end);
    }).toList();

    final attendancePct = report.attendanceRates.values.isEmpty
        ? 0
        : (report.attendanceRates.values.fold(0.0, (s, v) => s + v) /
                report.attendanceRates.length *
                100)
            .round();

    final dateFmt = DateFormat('EEEE، d MMMM y', 'ar');

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: _font, bold: _fontBold),
        build: (context) => [
          // ===== الترويسة =====
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#0E7C5B'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'مركز السنة للعلوم الشرعية وتأهيل الدعاة',
                  style: _s(15, bold: true, color: PdfColors.white),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  isWeek ? 'التقرير الأسبوعي' : 'التقرير الشهري',
                  style: _s(12, color: PdfColor.fromHex('#E9D9A6')),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${period.title} — ${period.subtitle}',
                  style: _s(10.5, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ===== بيانات الدرس =====
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#D9E5DF')),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _info('المعلم', teacherName),
                _info('المستوى', pathwayName),
                _info('الدرس', lesson.name),
                _info('النوع', lesson.typeLabel),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ===== الملخص الإجمالي =====
          pw.Text('ملخص الفترة', style: _s(13, bold: true)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F2F8F5'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _summaryStat('المنجز', '${report.unitsAccomplished} ${lesson.unitLabel}'),
                _summaryStat('أيام التسجيل', '${report.recordingsCount}'),
                _summaryStat('متوسط الحضور', '$attendancePct%'),
                _summaryStat('نسبة الإنجاز', '${(report.completionRate * 100).round()}%'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ===== التقارير اليومية =====
          pw.Text('التقارير اليومية', style: _s(13, bold: true)),
          pw.SizedBox(height: 6),
          if (periodDays.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text('لا توجد تسجيلات يومية في هذه الفترة',
                  style: _s(11, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center),
            )
          else
            pw.TableHelper.fromTextArray(
              cellAlignment: pw.Alignment.center,
              headerStyle: _s(11, bold: true, color: PdfColors.white),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#0E7C5B')),
              cellStyle: _s(10),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: [
                'الغائبون',
                'الحضور',
                'المنجز',
                'المدة',
                'التاريخ',
              ],
              data: [
                for (final day in periodDays)
                  [
                    day.absentNames.isEmpty
                        ? 'لا يوجد'
                        : day.absentNames.join('، '),
                    '${day.presentCount}/${day.totalStudents} (${(day.attendanceRate * 100).round()}%)',
                    '${fmtNum(day.recording.from)} ← ${fmtNum(day.recording.to)} (${fmtNum(day.recording.count)})',
                    day.recording.duration,
                    dateFmt.format(day.date),
                  ],
              ],
            ),
          pw.SizedBox(height: 12),

          // ===== نسب حضور الطلاب =====
          if (report.attendanceRates.isNotEmpty) ...[
            pw.Text('نسبة حضور الطلاب خلال الفترة',
                style: _s(13, bold: true)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              cellAlignment: pw.Alignment.center,
              headerStyle: _s(11, bold: true, color: PdfColors.white),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#C09A3E')),
              cellStyle: _s(10.5),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: ['النسبة', 'اسم الطالب'],
              data: [
                for (final e in report.attendanceRates.entries)
                  ['${(e.value * 100).round()}%', e.key],
              ],
            ),
          ],

          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Text(
            'أُنشئ بواسطة تطبيق مركز السنة — ${DateFormat('d MMMM y', 'ar').format(DateTime.now())}',
            style: _s(9, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    final fileName = isWeek
        ? 'تقرير_أسبوعي_${lesson.name}'
        : 'تقرير_شهري_${lesson.name}';

    // تنزيل التقرير كملف PDF جاهز (على الويب يُنزَّل مباشرة،
    // وعلى الجوال تظهر نافذة المشاركة/الحفظ كملف)
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static pw.Widget _info(String label, String value) => pw.Column(
        children: [
          pw.Text(label, style: _s(9.5, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: _s(11.5, bold: true)),
        ],
      );

  static pw.Widget _summaryStat(String label, String value) => pw.Column(
        children: [
          pw.Text(value,
              style: _s(14, bold: true, color: PdfColor.fromHex('#0E7C5B'))),
          pw.SizedBox(height: 2),
          pw.Text(label, style: _s(9.5, color: PdfColors.grey700)),
        ],
      );
}
