import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lesson.dart';
import '../models/matna.dart';
import '../models/quran.dart';

// ==================== نماذج التقارير ====================

/// تقرير يومي مجمّع لمعلم واحد (جميع الأنشطة في يوم محدد)
class TeacherDayReport {
  final List<LessonRecording> lessonRecordings;
  final List<MutunRecording> mutunRecordings;
  final List<QuranRecording> quranRecordings;
  final Map<String, String> studentNames;
  final Map<String, String> matnaNames;

  const TeacherDayReport({
    required this.lessonRecordings,
    required this.mutunRecordings,
    required this.quranRecordings,
    required this.studentNames,
    required this.matnaNames,
  });

  bool get isEmpty =>
      lessonRecordings.isEmpty &&
      mutunRecordings.isEmpty &&
      quranRecordings.isEmpty;

  int get totalLessonUnits =>
      lessonRecordings.fold(0, (s, r) => s + r.count);
  int get totalMutunUnits =>
      mutunRecordings.fold(0, (s, r) => s + r.count);
  int get totalQuranPages =>
      quranRecordings.fold(0, (s, r) => s + r.count);
  int get totalActivity =>
      lessonRecordings.length +
      mutunRecordings.length +
      quranRecordings.length;
}

/// تقرير درس ليوم واحد
class LessonDayReport {
  final LessonRecording recording;
  final int presentCount;
  final int totalStudents;
  final List<String> absentNames;
  final List<String> presentNames;
  final int lessonTotalCount;

  const LessonDayReport({
    required this.recording,
    required this.presentCount,
    required this.totalStudents,
    required this.absentNames,
    this.presentNames = const [],
    required this.lessonTotalCount,
  });

  DateTime get date => recording.date;

  /// نسبة حضور الطلاب في هذا اليوم
  double get attendanceRate =>
      totalStudents > 0 ? presentCount / totalStudents : 0;

  /// نسبة الإنجاز في الدرس بعد هذا اليوم
  double get completionRate =>
      lessonTotalCount > 0 ? recording.to / lessonTotalCount : 0;
}

/// ملخص فترة (أسبوع أو شهر) لدرس معيّن
class PeriodReport {
  final DateTime start;
  final DateTime end;

  /// وحدات (أبيات/صفحات) المنجزة خلال الفترة
  final int unitsAccomplished;
  final int recordingsCount;

  /// نسبة الحضور لكل طالب خلال الفترة
  final Map<String, double> attendanceRates;

  /// نسبة إنجاز الدرس في نهاية الفترة
  final double completionRate;

  const PeriodReport({
    required this.start,
    required this.end,
    required this.unitsAccomplished,
    required this.recordingsCount,
    required this.attendanceRates,
    required this.completionRate,
  });
}

/// بطاقة فترة (أسبوع منتهٍ أو شهر منتهٍ)
class PeriodCard {
  final String id; // مثال: week_2025_12 | month_2025_6
  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime end;
  final bool isCurrent; // الفترة الجارية (تظهر يوم الجمعة / نهاية الشهر)
  final PeriodReport report;

  const PeriodCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.report,
  });
}

// ==================== خدمة التقارير ====================

class ReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// بث دروس مسار كامل (كل المعلمين في المسار)
  Stream<List<Lesson>> watchPathwayLessons(String pathwayId) {
    return _firestore
        .collection('lessons')
        .where('pathwayId', isEqualTo: pathwayId)
        .snapshots()
        .map((snapshot) {
      final lessons =
          snapshot.docs.map((d) => Lesson.fromFirestore(d)).toList();
      lessons.sort((a, b) {
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return at.compareTo(bt);
      });
      return lessons;
    });
  }

  /// بث دروس معلم معيّن (بدون orderBy لتفادي الفهارس المركّبة)
  Stream<List<Lesson>> watchTeacherLessons(String teacherId) {
    return _firestore
        .collection('lessons')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final lessons =
          snapshot.docs.map((d) => Lesson.fromFirestore(d)).toList();
      lessons.sort((a, b) {
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return at.compareTo(bt);
      });
      return lessons;
    });
  }

  /// بناء تقرير درس يومي كامل (تسجيلات + حضور + أسماء الطلاب)
  /// [historyWindowDays] حد أقصى للأيام المعروضة (افتراضي: منذ إنشاء الدرس)
  Future<List<LessonDayReport>> buildLessonDailyReports(
      Lesson lesson) async {
    final results = await Future.wait([
      _firestore
          .collection('lesson_recordings')
          .where('lessonId', isEqualTo: lesson.id)
          .get(),
      _firestore
          .collection('attendance')
          .where('lessonId', isEqualTo: lesson.id)
          .get(),
      _firestore
          .collection('students')
          .where('teacherId', isEqualTo: lesson.teacherId)
          .where('pathwayId', isEqualTo: lesson.pathwayId)
          .get(),
    ]);

    final studentNames = <String, String>{
      for (final d in results[2].docs)
        d.id: (d.data()['name'] as String?) ?? 'طالب',
    };

    // خريطة recordingId ← وثيقة الحضور
    final attendanceByRecording = <String, Map<String, dynamic>>{};
    for (final doc in results[1].docs) {
      final data = doc.data();
      final recId = data['recordingId'] as String?;
      if (recId != null) attendanceByRecording[recId] = data;
    }

    final recordings = results[0].docs
        .map((d) => LessonRecording.fromFirestore(d))
        .toList()
      // الأقدم أولاً (الترتيب الزمني للتمرير نحو اليوم الحالي)
      ..sort((a, b) => a.date.compareTo(b.date));

    return recordings.map((rec) {
      final att = attendanceByRecording[rec.id];

      // استخراج الغائبين: من الوثيقة إن وُجدت، وإلا من عدّادات التسجيل
      List<String> absentNames = [];
      List<String> presentNames = [];
      int presentCount = rec.presentCount;
      int totalStudents = rec.totalStudents;

      if (att != null) {
        final absentIds = (att['absentStudentIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        absentNames =
            absentIds.map((id) => studentNames[id] ?? 'طالب').toList();
        final presentIds = (att['presentStudentIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        presentNames =
            presentIds.map((id) => studentNames[id] ?? 'طالب').toList();
        presentCount = presentIds.length;
        totalStudents = presentIds.length + absentIds.length;
      }

      return LessonDayReport(
        recording: rec,
        presentCount: presentCount,
        totalStudents: totalStudents,
        absentNames: absentNames,
        presentNames: presentNames,
        lessonTotalCount: lesson.totalCount,
      );
    }).toList();
  }

  /// ملخص فترة زمنية لدرس (يُستخدم للأسبوعي والشهري)
  PeriodReport buildPeriodReport({
    required Lesson lesson,
    required List<LessonDayReport> dailyReports,
    required DateTime start,
    required DateTime end,
  }) {
    final inPeriod = dailyReports.where((r) {
      final d = _dayOnly(r.date);
      return !d.isBefore(_dayOnly(start)) && !d.isAfter(_dayOnly(end));
    }).toList();

    final units = inPeriod.fold(0, (s, r) => s + r.recording.count);

    // نسبة حضور كل طالب = (أيام حضوره الفعلية) / (أيام ظهوره في السجلات)
    final presentDays = <String, int>{};
    final totalDays = <String, int>{};
    for (final day in inPeriod) {
      for (final name in day.presentNames) {
        presentDays[name] = (presentDays[name] ?? 0) + 1;
        totalDays[name] = (totalDays[name] ?? 0) + 1;
      }
      for (final name in day.absentNames) {
        totalDays[name] = (totalDays[name] ?? 0) + 1;
      }
    }

    // نسبة حضور عامة للفترة
    int sumPresent = 0, sumTotal = 0;
    for (final day in inPeriod) {
      sumPresent += day.presentCount;
      sumTotal += day.totalStudents;
    }
    final overallRate = sumTotal > 0 ? sumPresent / sumTotal : 0.0;

    // نسبة كل طالب: أيام حضوره / أيام تسجيله
    final rates = <String, double>{};
    for (final entry in totalDays.entries) {
      final attended = presentDays[entry.key] ?? 0;
      rates[entry.key] =
          entry.value > 0 ? attended / entry.value : 0.0;
    }
    // نسبة افتراضية إن لم توجد أسماء (سجلات قديمة بدون وثائق حضور)
    if (rates.isEmpty && sumTotal > 0) {
      rates['جميع الطلاب'] = overallRate;
    }

    final lastInPeriod = inPeriod.isEmpty ? null : inPeriod.last;
    final completion = lastInPeriod == null || lesson.totalCount == 0
        ? (lesson.totalCount > 0
            ? lesson.completedCount / lesson.totalCount
            : 0.0)
        : lastInPeriod.recording.to / lesson.totalCount;

    return PeriodReport(
      start: start,
      end: end,
      unitsAccomplished: units,
      recordingsCount: inPeriod.length,
      attendanceRates: rates,
      completionRate: completion.clamp(0.0, 1.0),
    );
  }

  /// بناء البطاقات الأسبوعية والشهرية لدرس
  ///
  /// الأسبوع: يبدأ السبت وينتهي الجمعة — يظهر "الحالي" يوم الجمعة فقط.
  /// الشهر: من أول الشهر لآخره — يظهر "الحالي" في آخر يوم بالشهر.
  ({List<PeriodCard> weeks, List<PeriodCard> months}) buildPeriodCards({
    required Lesson lesson,
    required List<LessonDayReport> dailyReports,
  }) {
    if (dailyReports.isEmpty) {
      return (weeks: <PeriodCard>[], months: <PeriodCard>[]);
    }

    final now = DateTime.now();
    final firstDate = _dayOnly(dailyReports.first.date);
    final lastDate = _dayOnly(dailyReports.last.date);

    // ===== الأسابيع (السبت → الجمعة) =====
    final weeks = <PeriodCard>[];
    // أول سبت يسبق أول تسجيل أو يساويه
    var weekStart = firstDate
        .subtract(Duration(days: (firstDate.weekday % 7)));
    int weekNumber = 1;

    while (!weekStart.isAfter(lastDate) && weeks.length < 60) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final isCurrentWeek = !_dayOnly(now).isBefore(weekStart) &&
          !_dayOnly(now).isAfter(weekEnd);
      // تظهر البطاقة الحالية يوم الجمعة فقط (weekday == 5)
      final showCurrent = isCurrentWeek && now.weekday == 5;
      final finished = _dayOnly(now).isAfter(weekEnd);

      if (showCurrent || finished) {
        final report = buildPeriodReport(
          lesson: lesson,
          dailyReports: dailyReports,
          start: weekStart,
          end: weekEnd,
        );
        weeks.add(PeriodCard(
          id: 'week_${weekStart.millisecondsSinceEpoch}',
          title: 'الأسبوع ${_toArabicNumber(weekNumber)}',
          subtitle:
              '${_fmt(weekStart)} ← ${_fmt(weekEnd)}${showCurrent ? ' • جارٍ' : ''}',
          start: weekStart,
          end: weekEnd,
          isCurrent: showCurrent,
          report: report,
        ));
      }

      weekStart = weekStart.add(const Duration(days: 7));
      weekNumber++;
    }

    // ===== الأشهر =====
    final months = <PeriodCard>[];
    var monthCursor = DateTime(firstDate.year, firstDate.month);

    while (!monthCursor.isAfter(lastDate) && months.length < 24) {
      final monthStart = DateTime(monthCursor.year, monthCursor.month);
      final monthEnd =
          DateTime(monthCursor.year, monthCursor.month + 1)
              .subtract(const Duration(days: 1));
      final isCurrentMonth =
          now.year == monthStart.year && now.month == monthStart.month;
      // يظهر الشهر الحالي في آخر يوم منه فقط
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
      final showCurrent = isCurrentMonth && now.day == lastDayOfMonth;
      final finished = _dayOnly(now).isAfter(monthEnd);

      if (showCurrent || finished) {
        final report = buildPeriodReport(
          lesson: lesson,
          dailyReports: dailyReports,
          start: monthStart,
          end: monthEnd,
        );
        months.add(PeriodCard(
          id: 'month_${monthStart.year}_${monthStart.month}',
          title: 'شهر ${_monthName(monthStart.month)} ${monthStart.year}',
          subtitle:
              '${_fmt(monthStart)} ← ${_fmt(monthEnd)}${showCurrent ? ' • جارٍ' : ''}',
          start: monthStart,
          end: monthEnd,
          isCurrent: showCurrent,
          report: report,
        ));
      }

      monthCursor = DateTime(monthCursor.year, monthCursor.month + 1);
    }

    return (weeks: weeks, months: months);
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}';

  String _monthName(int m) {
    const names = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return names[m - 1];
  }

  String _toArabicNumber(int n) {
    const words = [
      '', 'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس',
      'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر',
    ];
    if (n >= 1 && n <= 10) return words[n];
    return '$n';
  }

  /// تقرير يومي مجمّع لمعلم (يُستخدم في صفحة اليوم المفصّلة)
  Future<TeacherDayReport> buildTeacherDayReport({
    required String teacherId,
    required DateTime day,
  }) async {
    final results = await Future.wait([
      _firestore
          .collection('lesson_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get(),
      _firestore
          .collection('mutun_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get(),
      _firestore
          .collection('quran_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get(),
      _firestore
          .collection('students')
          .where('teacherId', isEqualTo: teacherId)
          .get(),
      _firestore
          .collection('mutun')
          .where('teacherId', isEqualTo: teacherId)
          .get(),
    ]);

    final lessonRecs = results[0]
        .docs
        .map((d) => LessonRecording.fromFirestore(d))
        .where((r) => _isSameDay(r.date, day))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final mutunRecs = results[1]
        .docs
        .map((d) => MutunRecording.fromFirestore(d))
        .where((r) => _isSameDay(r.date, day))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final quranRecs = results[2]
        .docs
        .map((d) => QuranRecording.fromFirestore(d))
        .where((r) => _isSameDay(r.date, day))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final studentNames = <String, String>{
      for (final d in results[3].docs)
        d.id: (d.data()['name'] as String?) ?? 'طالب',
    };

    final matnaNames = <String, String>{
      for (final d in results[4].docs)
        d.id: (d.data()['name'] as String?) ?? 'متن',
    };

    return TeacherDayReport(
      lessonRecordings: lessonRecs,
      mutunRecordings: mutunRecs,
      quranRecordings: quranRecs,
      studentNames: studentNames,
      matnaNames: matnaNames,
    );
  }
}
