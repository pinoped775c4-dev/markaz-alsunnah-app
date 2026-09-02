import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:intl/intl.dart';

import '../models/lesson.dart';
import '../models/matna.dart';
import '../models/quran.dart';
import '../models/student.dart';

// ==================== نماذج التقارير ====================

/// فاصل مُوحّد لأنشطة الطالب الثلاثة (درس/متن/قرآن) في شاشة تقرير الطالب
enum StudentActivityKind { lesson, matn, quran }

extension StudentActivityKindX on StudentActivityKind {
  String get label => switch (this) {
        StudentActivityKind.lesson => 'الدرس',
        StudentActivityKind.matn => 'متن',
        StudentActivityKind.quran => 'قرآن',
      };

  IconData get icon => switch (this) {
        StudentActivityKind.lesson => Icons.auto_stories_outlined,
        StudentActivityKind.matn => Icons.article_outlined,
        StudentActivityKind.quran => Icons.menu_book_outlined,
      };
}

/// عنصر نشاط واحد في تقرير الطالب (تسجيل درس/متن/قرآن في يوم محدد)
class StudentActivityEntry {
  final StudentActivityKind kind;
  final String title; // اسم الدرس أو المتن أو "ورد القرآن الكريم"
  final DateTime date;
  final String weekdayLabel;
  final double from;
  final double to;
  final double count;
  final String? notes;
  final bool wasPresent; // للدروس: هل حضر الطالب يوم التسجيل؟
  final double completionBase; // إجمالي وحدات الدرس/المتن (0 للقرآن)

  const StudentActivityEntry({
    required this.kind,
    required this.title,
    required this.date,
    required this.weekdayLabel,
    required this.from,
    required this.to,
    required this.count,
    this.notes,
    this.wasPresent = true,
    this.completionBase = 0,
  });

  DateTime get day => DateTime(date.year, date.month, date.day);
}

/// تقرير طالب واحد مجمّع (دروس حضور + متون + قرآن) — المهمة 3
class StudentReport {
  final Student student;
  final List<StudentActivityEntry> activities; // الأحدث أولاً

  const StudentReport({
    required this.student,
    required this.activities,
  });

  bool get isEmpty => activities.isEmpty;

  double get lessonUnits => _sumFor(StudentActivityKind.lesson);
  double get matnUnits => _sumFor(StudentActivityKind.matn);
  double get quranPages => _sumFor(StudentActivityKind.quran);

  double _sumFor(StudentActivityKind kind) => activities
      .where((a) => a.kind == kind)
      .fold(0.0, (s, a) => s + a.count);

  /// نسبة حضور الطالب في الدروس = أيام حضوره / أيام تسجيل الدروس
  int get lessonDays => activities
      .where((a) => a.kind == StudentActivityKind.lesson)
      .length;
  int get lessonPresentDays => activities
      .where((a) => a.kind == StudentActivityKind.lesson && a.wasPresent)
      .length;
  double get attendanceRate =>
      lessonDays > 0 ? lessonPresentDays / lessonDays : 0;

  /// آخر يوم نشاط للطالب (أو null إن لم يوجد)
  DateTime? get lastActivityDay =>
      activities.isEmpty ? null : activities.first.day;

  /// أيام نشاط الطالب (أيام الدروس التي ظهر فيها ضمن التسجيلات)
  List<StudentActivityEntry> get lessonEntries => activities
      .where((a) => a.kind == StudentActivityKind.lesson)
      .toList(growable: false);
}

/// يوم "غائب المعلم" — المهمة 4
class TeacherAbsence {
  final DateTime date;
  final String weekdayLabel;

  const TeacherAbsence({required this.date, required this.weekdayLabel});
}

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

  double get totalLessonUnits =>
      lessonRecordings.fold(0.0, (s, r) => s + r.count);
  double get totalMutunUnits =>
      mutunRecordings.fold(0.0, (s, r) => s + r.count);
  double get totalQuranPages =>
      quranRecordings.fold(0.0, (s, r) => s + r.count);
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
  final double unitsAccomplished;
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

// ==================== نماذج تقارير المتون والقرآن ====================

/// سجل طالب واحد داخل يوم نشاط (متن أو قرآن)
class ActivityEntry {
  final String studentName;
  final double from;
  final double to;
  final double count;
  final String? notes;

  /// هل أتمّ الطالب المتن/الختمة بهذا السجل؟
  final bool completesTotal;

  const ActivityEntry({
    required this.studentName,
    required this.from,
    required this.to,
    required this.count,
    this.notes,
    required this.completesTotal,
  });
}

/// تقرير يوم واحد لنشاط متعدد الطلاب (متون أو قرآن)
class ActivityDayReport {
  final DateTime date;
  final String weekdayLabel;
  final List<ActivityEntry> entries;

  const ActivityDayReport({
    required this.date,
    required this.weekdayLabel,
    required this.entries,
  });

  double get units => entries.fold(0.0, (s, e) => s + e.count);
  int get studentsCount => entries.length;
  bool get hasCompletion => entries.any((e) => e.completesTotal);

  /// أسماء الطلاب الذين سجّلوا في هذا اليوم (بدون تكرار)
  List<String> get participantNames =>
      entries.map((e) => e.studentName).toSet().toList();
}

/// بيانات تقرير متن كاملة (المتن + الأيام + أقصى موضع وصل إليه الطلاب)
class MutunReportData {
  final Matna matna;
  final List<ActivityDayReport> days;
  final double reached;

  const MutunReportData({
    required this.matna,
    required this.days,
    required this.reached,
  });

  bool get isEmpty => days.isEmpty;
  double get progress =>
      matna.totalCount > 0 ? (reached / matna.totalCount).clamp(0.0, 1.0) : 0.0;
  int get progressPercent => (progress * 100).round();
}

/// بيانات تقرير قرآن معلم في مسار

class QuranReportData {
  final List<ActivityDayReport> days;

  /// ملخص تقدم كل طالب (بالاسم)
  final Map<String, QuranProgressSummary> studentSummaries;
  final int completedKhatmas;
  final double totalPagesRead;

  const QuranReportData({
    required this.days,
    required this.studentSummaries,
    required this.completedKhatmas,
    required this.totalPagesRead,
  });

  bool get isEmpty => days.isEmpty;
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
      // استعلام بشرط واحد فقط (تجنّب الفهرس المركب) — الفلترة على pathwayId تتم محليًا
      _firestore
          .collection('students')
          .where('teacherId', isEqualTo: lesson.teacherId)
          .get(),
    ]);

    final studentNames = <String, String>{
      for (final d in results[2].docs)
        if (d.data()['pathwayId'] == lesson.pathwayId)
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

    final units = inPeriod.fold(0.0, (s, r) => s + r.recording.count);

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

  // ==================== تقارير المتون والقرآن (للإدارة) ====================

  /// بث متون مسار كامل (كل المعلمين في المسار)
  Stream<List<Matna>> watchPathwayMutun(String pathwayId) {
    return _firestore
        .collection('mutun')
        .where('pathwayId', isEqualTo: pathwayId)
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map((d) => Matna.fromFirestore(d)).toList();
      items.sort((a, b) {
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return at.compareTo(bt);
      });
      return items;
    });
  }

  /// بث تسجيلات القرآن في مسار كامل
  Stream<List<QuranRecording>> watchPathwayQuranRecordings(
      String pathwayId) {
    return _firestore
        .collection('quran_recordings')
        .where('pathwayId', isEqualTo: pathwayId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((d) => QuranRecording.fromFirestore(d))
          .toList();
      items.sort((a, b) => a.date.compareTo(b.date));
      return items;
    });
  }

  /// التقرير اليومي لمتن (تسجيلات كل الطلاب مجمّعة حسب اليوم)
  Future<MutunReportData> buildMutunDailyReports(Matna matna) async {
    final results = await Future.wait([
      _firestore
          .collection('mutun_recordings')
          .where('matnaId', isEqualTo: matna.id)
          .get(),
      // استعلام بشرط واحد فقط (تجنّب الفهرس المركّب) — الفلترة محليًا
      _firestore
          .collection('students')
          .where('teacherId', isEqualTo: matna.teacherId)
          .get(),
    ]);

    final studentNames = <String, String>{
      for (final d in results[1].docs)
        if (d.data()['pathwayId'] == matna.pathwayId)
          d.id: (d.data()['name'] as String?) ?? 'طالب',
    };

    final recordings = results[0].docs
        .map((d) => MutunRecording.fromFirestore(d))
        .toList();

    // تجميع التسجيلات حسب اليوم
    final byDay = <DateTime, List<MutunRecording>>{};
    for (final r in recordings) {
      byDay.putIfAbsent(_dayOnly(r.date), () => []).add(r);
    }

    final days = byDay.entries.map((entry) {
      final recs = entry.value..sort((a, b) => a.from.compareTo(b.from));
      return ActivityDayReport(
        date: entry.key,
        weekdayLabel: recs.first.weekday,
        entries: recs
            .map((r) => ActivityEntry(
                  studentName: studentNames[r.studentId] ?? 'طالب',
                  from: r.from,
                  to: r.to,
                  count: r.count,
                  notes: r.notes,
                  completesTotal:
                      matna.totalCount > 0 && r.to >= matna.totalCount,
                ))
            .toList(),
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double reached = 0;
    for (final r in recordings) {
      if (r.to > reached) reached = r.to;
    }

    return MutunReportData(matna: matna, days: days, reached: reached);
  }

  /// التقرير اليومي لقرآن معلم في مسار (أوراد كل الطلاب مجمّعة حسب اليوم)
  Future<QuranReportData> buildTeacherQuranDailyReports({
    required String teacherId,
    required String pathwayId,
  }) async {
    final results = await Future.wait([
      _firestore
          .collection('quran_recordings')
          .where('teacherId', isEqualTo: teacherId)
          .get(),
      _firestore
          .collection('students')
          .where('teacherId', isEqualTo: teacherId)
          .get(),
    ]);

    final studentNames = <String, String>{
      for (final d in results[1].docs)
        d.id: (d.data()['name'] as String?) ?? 'طالب',
    };

    // فلترة المسار محليًا (استعلام واحد فقط — بلا فهارس مركّبة)
    final recordings = results[0].docs
        .map((d) => QuranRecording.fromFirestore(d))
        .where((r) => r.pathwayId == pathwayId)
        .toList();

    final byDay = <DateTime, List<QuranRecording>>{};
    for (final r in recordings) {
      byDay.putIfAbsent(_dayOnly(r.date), () => []).add(r);
    }

    final days = byDay.entries.map((entry) {
      final recs = entry.value
        ..sort((a, b) => a.fromPage.compareTo(b.fromPage));
      return ActivityDayReport(
        date: entry.key,
        weekdayLabel: recs.first.weekday,
        entries: recs
            .map((r) => ActivityEntry(
                  studentName: studentNames[r.studentId] ?? 'طالب',
                  from: r.fromPage,
                  to: r.toPage,
                  count: r.count,
                  notes: r.notes,
                  completesTotal: r.completesKhatma,
                ))
            .toList(),
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // ملخص تقدم كل طالب (ختمات + موضع القراءة الحالي)
    final byStudent = <String, List<QuranRecording>>{};
    for (final r in recordings) {
      byStudent.putIfAbsent(r.studentId, () => []).add(r);
    }
    final summaries = <String, QuranProgressSummary>{};
    for (final e in byStudent.entries) {
      summaries[studentNames[e.key] ?? 'طالب'] =
          summarizeQuranProgress(e.value);
    }

    int khatmas = 0;
    for (final s in summaries.values) {
      khatmas += s.completedKhatmas;
    }

    return QuranReportData(
      days: days,
      studentSummaries: summaries,
      completedKhatmas: khatmas,
      totalPagesRead: recordings.fold(0.0, (s, r) => s + r.count),
    );
  }

  /// بناء بطاقات الفترات (أسبوعية/شهرية) لنشاط المتون أو القرآن
  ///
  /// نفس قاعدة الأسابيع والأشهر في تقارير الدروس:
  /// الأسبوع من السبت إلى الجمعة، والشهر من أوله لآخره.
  /// [completionBase] إجمالي وحدات المتن (لنسبة الإنجاز)، أو 0 للقرآن.
  ({List<PeriodCard> weeks, List<PeriodCard> months})
      buildActivityPeriodCards({
    required List<ActivityDayReport> days,
    required double completionBase,
  }) {
    if (days.isEmpty) {
      return (weeks: <PeriodCard>[], months: <PeriodCard>[]);
    }

    PeriodReport reportFor(DateTime start, DateTime end) {
      final inPeriod = days.where((d) {
        return !d.date.isBefore(_dayOnly(start)) &&
            !d.date.isAfter(_dayOnly(end));
      }).toList();

      final units = inPeriod.fold(0.0, (s, d) => s + d.units);
      final recordingsCount =
          inPeriod.fold(0, (s, d) => s + d.entries.length);

      // مشاركة الطلاب: أيام تسجيل الطالب / أيام النشاط في الفترة
      final activeDays = inPeriod.length;
      final studentDays = <String, int>{};
      for (final d in inPeriod) {
        for (final name in d.participantNames) {
          studentDays[name] = (studentDays[name] ?? 0) + 1;
        }
      }
      final rates = <String, double>{};
      for (final e in studentDays.entries) {
        rates[e.key] = activeDays > 0 ? e.value / activeDays : 0.0;
      }

      double completion = 0.0;
      if (completionBase > 0) {
        double maxTo = 0;
        for (final d in inPeriod) {
          for (final en in d.entries) {
            if (en.to > maxTo) maxTo = en.to;
          }
        }
        completion = (maxTo / completionBase).clamp(0.0, 1.0);
      }

      return PeriodReport(
        start: start,
        end: end,
        unitsAccomplished: units,
        recordingsCount: recordingsCount,
        attendanceRates: rates,
        completionRate: completion,
      );
    }

    final now = DateTime.now();
    final firstDate = days.first.date;
    final lastDate = days.last.date;

    // ===== الأسابيع (السبت → الجمعة) =====
    final weeks = <PeriodCard>[];
    var weekStart =
        firstDate.subtract(Duration(days: (firstDate.weekday % 7)));
    int weekNumber = 1;

    while (!weekStart.isAfter(lastDate) && weeks.length < 60) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final isCurrentWeek = !_dayOnly(now).isBefore(weekStart) &&
          !_dayOnly(now).isAfter(weekEnd);
      final showCurrent = isCurrentWeek && now.weekday == 5;
      final finished = _dayOnly(now).isAfter(weekEnd);

      if (showCurrent || finished) {
        weeks.add(PeriodCard(
          id: 'week_${weekStart.millisecondsSinceEpoch}',
          title: 'الأسبوع ${_toArabicNumber(weekNumber)}',
          subtitle:
              '${_fmt(weekStart)} ← ${_fmt(weekEnd)}${showCurrent ? ' • جارٍ' : ''}',
          start: weekStart,
          end: weekEnd,
          isCurrent: showCurrent,
          report: reportFor(weekStart, weekEnd),
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
      final monthEnd = DateTime(monthCursor.year, monthCursor.month + 1)
          .subtract(const Duration(days: 1));
      final isCurrentMonth =
          now.year == monthStart.year && now.month == monthStart.month;
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
      final showCurrent = isCurrentMonth && now.day == lastDayOfMonth;
      final finished = _dayOnly(now).isAfter(monthEnd);

      if (showCurrent || finished) {
        months.add(PeriodCard(
          id: 'month_${monthStart.year}_${monthStart.month}',
          title: 'شهر ${_monthName(monthStart.month)} ${monthStart.year}',
          subtitle:
              '${_fmt(monthStart)} ← ${_fmt(monthEnd)}${showCurrent ? ' • جارٍ' : ''}',
          start: monthStart,
          end: monthEnd,
          isCurrent: showCurrent,
          report: reportFor(monthStart, monthEnd),
        ));
      }

      monthCursor = DateTime(monthCursor.year, monthCursor.month + 1);
    }

    return (weeks: weeks, months: months);
  }

  // ================= تقرير طالب واحد (المهمة 3) =================

  ///
  /// يجمع نشاط الطالب من المصادر الثلاثة:
  /// - الدروس: حضور/غياب + الوحدات التي وصل إليها الدرس يومها
  /// - المتون: تسجيلات الطالب في كل متون المعلم
  /// - القرآن: أوراد الطالب
  ///
  /// كل استعلام بشرط where واحد فقط (studentId أو teacherId) —
  /// الفلترة على pathwayId تتم محليًا لتفادي الفهارس المركّبة.
  Future<StudentReport> buildStudentReport(Student student) async {
    final results = await Future.wait([
      // حضور الطالب في دروس المعلم
      _firestore
          .collection('attendance')
          .where('teacherId', isEqualTo: student.teacherId)
          .get(),
      // تسجيلات دروس المعلم (لربط الحضور بأيام الدرس)
      _firestore
          .collection('lesson_recordings')
          .where('teacherId', isEqualTo: student.teacherId)
          .get(),
      // متون المعلم + تسجيلات متون الطالب
      _firestore.collection('mutun').get(),
      _firestore
          .collection('mutun_recordings')
          .where('studentId', isEqualTo: student.id)
          .get(),
      // أوراد قرآن الطالب
      _firestore
          .collection('quran_recordings')
          .where('studentId', isEqualTo: student.id)
          .get(),
    ]);

    // ===== دروس المعلم في مسار الطالب فقط =====
    final lessonsOfPathway = <String, LessonRecording>{};
    final lessonNames = <String, String>{};
    final lessonTotals = <String, int>{};
    for (final d in results[1].docs) {
      final rec = LessonRecording.fromFirestore(d);
      if (rec.pathwayId != student.pathwayId) continue;
      lessonsOfPathway[rec.id] = rec;
    }
    for (final d in results[1].docs) {
      final data = d.data();
      if (data['pathwayId'] != student.pathwayId) continue;
      lessonNames[d.id] = (data['lessonName'] as String?) ?? 'الدرس';
      lessonTotals[d.id] = (data['totalCount'] as num?)?.toInt() ?? 0;
    }
    // أسماء الدروس من مجموعة lessons مباشرة (الأدق)
    try {
      final lessonsSnap = await _firestore
          .collection('lessons')
          .where('teacherId', isEqualTo: student.teacherId)
          .get();
      for (final d in lessonsSnap.docs) {
        if (d.data()['pathwayId'] != student.pathwayId) continue;
        lessonNames[d.id] = (d.data()['name'] as String?) ?? 'الدرس';
        lessonTotals[d.id] =
            ((d.data()['totalCount'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {
      // أسماء الدروس احتياطية فقط — لا تُفشل التقرير
    }

    // ===== حضور الطالب في أيام الدروس (درس واحد لكل تسجيل) =====
    final activities = <StudentActivityEntry>[];
    for (final doc in results[0].docs) {
      final data = doc.data();
      if (data['pathwayId'] != student.pathwayId) continue;
      final presentIds =
          (data['presentStudentIds'] as List?)?.map((e) => e.toString());
      final absentIds =
          (data['absentStudentIds'] as List?)?.map((e) => e.toString());
      final isPresent =
          presentIds?.contains(student.id) ?? false;
      final isAbsent = absentIds?.contains(student.id) ?? false;
      if (!isPresent && !isAbsent) continue; // الطالب ليس في هذا اليوم

      final recId = data['recordingId'] as String?;
      final LessonRecording? rec =
          recId != null ? lessonsOfPathway[recId] : null;
      if (rec == null) continue;

      activities.add(StudentActivityEntry(
        kind: StudentActivityKind.lesson,
        title: lessonNames[rec.lessonId] ?? 'الدرس',
        date: rec.date,
        weekdayLabel: DateFormat('EEEE', 'ar').format(rec.date),
        from: rec.from,
        to: rec.to,
        count: rec.count,
        wasPresent: isPresent,
        completionBase: (lessonTotals[rec.lessonId] ?? 0).toDouble(),
      ));
    }

    // ===== متون الطالب =====
    final matnaById = <String, Matna>{};
    for (final d in results[2].docs) {
      final data = d.data();
      if (data['teacherId'] != student.teacherId) continue;
      if (data['pathwayId'] != student.pathwayId) continue;
      matnaById[d.id] = Matna.fromFirestore(d);
    }
    for (final d in results[3].docs) {
      final rec = MutunRecording.fromFirestore(d);
      final matna = matnaById[rec.matnaId];
      if (matna == null) continue;
      activities.add(StudentActivityEntry(
        kind: StudentActivityKind.matn,
        title: matna.name,
        date: rec.date,
        weekdayLabel: DateFormat('EEEE', 'ar').format(rec.date),
        from: rec.from,
        to: rec.to,
        count: rec.count,
        notes: rec.notes,
        completionBase: matna.totalCount.toDouble(),
      ));
    }

    // ===== قرآن الطالب =====
    for (final d in results[4].docs) {
      final rec = QuranRecording.fromFirestore(d);
      if (rec.pathwayId != student.pathwayId) continue;
      activities.add(StudentActivityEntry(
        kind: StudentActivityKind.quran,
        title: 'ورد القرآن الكريم',
        date: rec.date,
        weekdayLabel: DateFormat('EEEE', 'ar').format(rec.date),
        from: rec.fromPage,
        to: rec.toPage,
        count: rec.count,
        notes: rec.notes,
      ));
    }

    // الأحدث أولاً
    activities.sort((a, b) => b.date.compareTo(a.date));

    return StudentReport(student: student, activities: activities);
  }

  // ================= أيام غياب المعلم (المهمة 4) =================

  ///
  /// الأيام التي كان على المعلم أن يسجّل فيها درسه ولم يفعل:
  /// أيام الدروس المتوقعة (المستخرجة من نمط أيام التسجيلات السابقة)
  /// التي انقضت بين أول تسجيل وأمس، ولا يوجد فيها تسجيل.
  ///
  /// المنطق: نجمع أيام الأسبوع التي سجّل المعلم فيها دروسًا سابقًا
  /// (نمط الحصص)، ثم نفحص كل يوم منعقد منذ أول تسجيل وحتى أمس؛
  /// إن كان يوم نمطٍ معروف ولا تسجيل فيه فهو "غائب المعلم".
  Future<List<TeacherAbsence>> buildTeacherAbsenceDays({
    required String teacherId,
    required String pathwayId,
    String? lessonId,
  }) async {
    final snapshot = await _firestore
        .collection('lesson_recordings')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final recordings = snapshot.docs
        .map((d) => LessonRecording.fromFirestore(d))
        .where((r) => r.pathwayId == pathwayId)
        .where((r) => lessonId == null || r.lessonId == lessonId)
        .toList();

    if (recordings.isEmpty) return const [];

    // أيام الأسبوع التي جرى فيها تسجيل (نمط حصص المعلم)
    final patternWeekdays = recordings.map((r) => r.date.weekday).toSet();

    // أول تسجيل → أمس
    recordings.sort((a, b) => a.date.compareTo(b.date));
    final first = _dayOnly(recordings.first.date);
    final yesterday = _dayOnly(DateTime.now())
        .subtract(const Duration(days: 1));

    // الأيام المسجّلة فعليًا
    final recordedDays = recordings.map((r) => _dayOnly(r.date)).toSet();

    final absences = <TeacherAbsence>[];
    var cursor = first;
    while (!cursor.isAfter(yesterday)) {
      if (patternWeekdays.contains(cursor.weekday) &&
          !recordedDays.contains(cursor)) {
        absences.add(TeacherAbsence(
          date: cursor,
          weekdayLabel: DateFormat('EEEE', 'ar').format(cursor),
        ));
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    // الأحدث أولاً
    return absences.reversed.toList();
  }
}
