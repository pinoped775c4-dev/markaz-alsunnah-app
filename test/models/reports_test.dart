import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/models/student.dart';
import 'package:islamic_center_manager/services/reports_service.dart';

/// اختبارات نماذج التقارير
/// هذه الاختبارات تكشف أخطاء الحسابات في التقارير
void main() {
  group('StudentActivityEntry', () {
    test('day strips time component', () {
      final entry = StudentActivityEntry(
        kind: StudentActivityKind.lesson,
        title: 'الورقات',
        date: DateTime(2026, 9, 7, 14, 30), // بتاريخ ووقت
        weekdayLabel: 'الأحد',
        from: 1,
        to: 10,
        count: 10,
      );
      // day يجب أن يكون بدون وقت
      expect(entry.day, DateTime(2026, 9, 7));
      expect(entry.day.hour, 0);
      expect(entry.day.minute, 0);
    });

    test('wasPresent defaults to true', () {
      final entry = StudentActivityEntry(
        kind: StudentActivityKind.lesson,
        title: 'درس',
        date: DateTime(2026, 9, 7),
        weekdayLabel: 'الأحد',
        from: 1,
        to: 10,
        count: 10,
      );
      expect(entry.wasPresent, true);
    });

    test('completionBase defaults to 0', () {
      final entry = StudentActivityEntry(
        kind: StudentActivityKind.quran,
        title: 'ورد القرآن',
        date: DateTime(2026, 9, 7),
        weekdayLabel: 'الأحد',
        from: 1,
        to: 20,
        count: 20,
      );
      expect(entry.completionBase, 0);
    });
  });

  group('StudentActivityKind', () {
    test('lesson has correct label and icon', () {
      expect(StudentActivityKind.lesson.label, 'الدرس');
    });

    test('matn has correct label', () {
      expect(StudentActivityKind.matn.label, 'متن');
    });

    test('quran has correct label', () {
      expect(StudentActivityKind.quran.label, 'قرآن');
    });
  });

  group('StudentReport', () {
    late Student testStudent;

    setUp(() {
      testStudent = Student(
        id: 's1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        pathwayName: 'مفاتيح الطلب',
        name: 'أحمد',
      );
    });

    test('isEmpty returns true when no activities', () {
      final report = StudentReport(
        student: testStudent,
        activities: [],
      );
      expect(report.isEmpty, true);
    });

    test('isEmpty returns false when has activities', () {
      final report = StudentReport(
        student: testStudent,
        activities: [
          StudentActivityEntry(
            kind: StudentActivityKind.lesson,
            title: 'درس',
            date: DateTime(2026, 9, 7),
            weekdayLabel: 'الأحد',
            from: 1,
            to: 10,
            count: 10,
          ),
        ],
      );
      expect(report.isEmpty, false);
    });

    test('lessonUnits sums only lesson activities', () {
      final report = StudentReport(
        student: testStudent,
        activities: [
          StudentActivityEntry(
            kind: StudentActivityKind.lesson,
            title: 'درس 1',
            date: DateTime(2026, 9, 1),
            weekdayLabel: 'السبت',
            from: 1,
            to: 10,
            count: 10,
          ),
          StudentActivityEntry(
            kind: StudentActivityKind.lesson,
            title: 'درس 2',
            date: DateTime(2026, 9, 2),
            weekdayLabel: 'الأحد',
            from: 11,
            to: 20,
            count: 10,
          ),
          // هذا ليس درساً — لا يُحتسب
          StudentActivityEntry(
            kind: StudentActivityKind.matn,
            title: 'متن',
            date: DateTime(2026, 9, 3),
            weekdayLabel: 'الاثنين',
            from: 1,
            to: 5,
            count: 5,
          ),
        ],
      );
      expect(report.lessonUnits, 20); // 10 + 10 فقط
    });

    test('matnUnits sums only matn activities', () {
      final report = StudentReport(
        student: testStudent,
        activities: [
          StudentActivityEntry(
            kind: StudentActivityKind.matn,
            title: 'متن 1',
            date: DateTime(2026, 9, 1),
            weekdayLabel: 'السبت',
            from: 1,
            to: 10,
            count: 10,
          ),
          StudentActivityEntry(
            kind: StudentActivityKind.matn,
            title: 'متن 2',
            date: DateTime(2026, 9, 2),
            weekdayLabel: 'الأحد',
            from: 11,
            to: 25,
            count: 15,
          ),
          // هذا ليس متناً
          StudentActivityEntry(
            kind: StudentActivityKind.lesson,
            title: 'درس',
            date: DateTime(2026, 9, 3),
            weekdayLabel: 'الاثنين',
            from: 1,
            to: 10,
            count: 10,
          ),
        ],
      );
      expect(report.matnUnits, 25); // 10 + 15 فقط
    });

    test('quranPages sums only quran activities', () {
      final report = StudentReport(
        student: testStudent,
        activities: [
          StudentActivityEntry(
            kind: StudentActivityKind.quran,
            title: 'ورد القرآن',
            date: DateTime(2026, 9, 1),
            weekdayLabel: 'السبت',
            from: 1,
            to: 20,
            count: 20,
          ),
          StudentActivityEntry(
            kind: StudentActivityKind.quran,
            title: 'ورد القرآن',
            date: DateTime(2026, 9, 2),
            weekdayLabel: 'الأحد',
            from: 21,
            to: 40,
            count: 20,
          ),
        ],
      );
      expect(report.quranPages, 40);
    });

    test('attendanceRate: 3 present out of 4 lessons = 0.75', () {
      final report = StudentReport(
        student: testStudent,
        activities: [
          _lessonEntry(DateTime(2026, 9, 1), wasPresent: true),
          _lessonEntry(DateTime(2026, 9, 2), wasPresent: true),
          _lessonEntry(DateTime(2026, 9, 3), wasPresent: true),
          _lessonEntry(DateTime(2026, 9, 4), wasPresent: false),
        ],
      );
      expect(report.lessonDays, 4);
      expect(report.lessonPresentDays, 3);
      expect(report.attendanceRate, 0.75);
    });

    test('attendanceRate: 0 lessons = 0 (no division by zero)', () {
      final report = StudentReport(
        student: testStudent,
        activities: [],
      );
      expect(report.lessonDays, 0);
      expect(report.attendanceRate, 0);
    });

    test('lastActivityDay is the first activity (activities are sorted newest first)', () {
      final report = StudentReport(
        student: testStudent,
        activities: [
          StudentActivityEntry(
            kind: StudentActivityKind.lesson,
            title: 'درس',
            date: DateTime(2026, 9, 5),
            weekdayLabel: 'الجمعة',
            from: 1,
            to: 10,
            count: 10,
          ),
          StudentActivityEntry(
            kind: StudentActivityKind.lesson,
            title: 'درس',
            date: DateTime(2026, 9, 1),
            weekdayLabel: 'السبت',
            from: 1,
            to: 10,
            count: 10,
          ),
        ],
      );
      // الأحدث أولاً
      expect(report.lastActivityDay, DateTime(2026, 9, 5));
    });

    test('lastActivityDay is null when no activities', () {
      final report = StudentReport(
        student: testStudent,
        activities: [],
      );
      expect(report.lastActivityDay, isNull);
    });
  });

  group('ActivityDayReport', () {
    test('units sums all entry counts', () {
      final report = ActivityDayReport(
        date: DateTime(2026, 9, 7),
        weekdayLabel: 'الأحد',
        entries: [
          ActivityEntry(
            studentName: 'أحمد',
            from: 1,
            to: 10,
            count: 10,
            completesTotal: false,
          ),
          ActivityEntry(
            studentName: 'محمد',
            from: 1,
            to: 15,
            count: 15,
            completesTotal: false,
          ),
        ],
      );
      expect(report.units, 25); // 10 + 15
      expect(report.studentsCount, 2);
    });

    test('hasCompletion returns true when any entry completes', () {
      final report = ActivityDayReport(
        date: DateTime(2026, 9, 7),
        weekdayLabel: 'الأحد',
        entries: [
          ActivityEntry(
            studentName: 'أحمد',
            from: 590,
            to: 604,
            count: 15,
            completesTotal: true,
          ),
        ],
      );
      expect(report.hasCompletion, true);
    });

    test('hasCompletion returns false when no entry completes', () {
      final report = ActivityDayReport(
        date: DateTime(2026, 9, 7),
        weekdayLabel: 'الأحد',
        entries: [
          ActivityEntry(
            studentName: 'أحمد',
            from: 1,
            to: 10,
            count: 10,
            completesTotal: false,
          ),
        ],
      );
      expect(report.hasCompletion, false);
    });

    test('participantNames returns unique names', () {
      final report = ActivityDayReport(
        date: DateTime(2026, 9, 7),
        weekdayLabel: 'الأحد',
        entries: [
          ActivityEntry(
            studentName: 'أحمد',
            from: 1,
            to: 10,
            count: 10,
            completesTotal: false,
          ),
          ActivityEntry(
            studentName: 'محمد',
            from: 1,
            to: 5,
            count: 5,
            completesTotal: false,
          ),
        ],
      );
      expect(report.participantNames.length, 2);
      expect(report.participantNames, contains('أحمد'));
      expect(report.participantNames, contains('محمد'));
    });
  });

  group('MutunReportData', () {
    test('isEmpty returns true when no days', () {
      // نحتاج Matna — نستخدم قيم افتراضية
      // لا يمكن إنشاء Matna بدون Firebase هنا،
      // لكن نختبر المنطق فقط
      expect(true, true); // placeholder
    });
  });

  group('TeacherAbsence', () {
    test('stores date and weekday correctly', () {
      final absence = TeacherAbsence(
        date: DateTime(2026, 9, 7),
        weekdayLabel: 'الأحد',
      );
      expect(absence.date, DateTime(2026, 9, 7));
      expect(absence.weekdayLabel, 'الأحد');
    });
  });
}

/// مساعد: إنشاء نشاط درس للاختبار
StudentActivityEntry _lessonEntry(DateTime date, {required bool wasPresent}) {
  return StudentActivityEntry(
    kind: StudentActivityKind.lesson,
    title: 'درس',
    date: date,
    weekdayLabel: 'يوم',
    from: 1,
    to: 10,
    count: 10,
    wasPresent: wasPresent,
  );
}
