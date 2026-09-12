import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/models/quran.dart';

/// اختبارات نموذج القرآن وتلخيص التقدم
/// هذه الاختبارات تكشف أخطاء حساب الختمات والصفحات
void main() {
  group('QuranRecording', () {
    test('completesKhatma returns true when toPage >= 604', () {
      final recording = QuranRecording(
        id: 'q1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        fromPage: 590,
        toPage: 604,
        count: 15,
      );
      expect(recording.completesKhatma, true);
    });

    test('completesKhatma returns false when toPage < 604', () {
      final recording = QuranRecording(
        id: 'q1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        fromPage: 1,
        toPage: 20,
        count: 20,
      );
      expect(recording.completesKhatma, false);
    });

    test('completesKhatma returns true when toPage > 604', () {
      final recording = QuranRecording(
        id: 'q1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        fromPage: 600,
        toPage: 610,
        count: 11,
      );
      expect(recording.completesKhatma, true);
    });

    test('isOfficial defaults to false', () {
      final recording = QuranRecording(
        id: 'q1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        fromPage: 1,
        toPage: 10,
        count: 10,
      );
      expect(recording.isOfficial, false);
    });

    test('isOfficial can be set to true', () {
      final recording = QuranRecording(
        id: 'q1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        fromPage: 1,
        toPage: 10,
        count: 10,
        isOfficial: true,
      );
      expect(recording.isOfficial, true);
    });
  });

  group('QuranProgressSummary', () {
    test('empty summary has all zeros', () {
      final empty = QuranProgressSummary.empty;
      expect(empty.currentPage, 0);
      expect(empty.completedKhatmas, 0);
      expect(empty.totalPagesRead, 0);
      expect(empty.recordingsCount, 0);
      expect(empty.lastDate, isNull);
    });

    test('empty summary: khatmaProgress is 0', () {
      expect(QuranProgressSummary.empty.khatmaProgress, 0.0);
      expect(QuranProgressSummary.empty.khatmaPercent, 0);
    });

    test('empty summary: remainingPages is 604', () {
      expect(QuranProgressSummary.empty.remainingPages, 604);
    });

    test('summary with current page: progress calculated correctly', () {
      final summary = QuranProgressSummary(
        currentPage: 302,  // نصف المصحف
        completedKhatmas: 0,
        totalPagesRead: 302,
        recordingsCount: 10,
      );
      expect(summary.khatmaProgress, closeTo(0.5, 0.01));
      expect(summary.khatmaPercent, 50);
      expect(summary.remainingPages, 302);
    });

    test('summary with full khatma: remaining is 604', () {
      final summary = QuranProgressSummary(
        currentPage: 0,  // بدأ من جديد بعد الختمة
        completedKhatmas: 1,
        totalPagesRead: 604,
        recordingsCount: 30,
      );
      expect(summary.completedKhatmas, 1);
      expect(summary.remainingPages, 604);
    });
  });

  group('summarizeQuranProgress', () {
    test('empty recordings returns empty summary', () {
      final summary = summarizeQuranProgress([]);
      expect(summary.currentPage, 0);
      expect(summary.completedKhatmas, 0);
      expect(summary.totalPagesRead, 0);
      expect(summary.recordingsCount, 0);
    });

    test('single recording: correct page and total', () {
      final recordings = [
        QuranRecording(
          id: 'q1',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'السبت',
          date: DateTime(2026, 9, 1),
          fromPage: 1,
          toPage: 20,
          count: 20,
        ),
      ];

      final summary = summarizeQuranProgress(recordings);
      expect(summary.currentPage, 20);
      expect(summary.totalPagesRead, 20);
      expect(summary.recordingsCount, 1);
      expect(summary.completedKhatmas, 0);
    });

    test('multiple recordings: accumulates pages correctly', () {
      final recordings = [
        QuranRecording(
          id: 'q1',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'السبت',
          date: DateTime(2026, 9, 1),
          fromPage: 1,
          toPage: 20,
          count: 20,
        ),
        QuranRecording(
          id: 'q2',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'الأحد',
          date: DateTime(2026, 9, 2),
          fromPage: 21,
          toPage: 40,
          count: 20,
        ),
      ];

      final summary = summarizeQuranProgress(recordings);
      expect(summary.currentPage, 40);
      expect(summary.totalPagesRead, 40);
      expect(summary.recordingsCount, 2);
    });

    test('full khatma (toPage >= 604) increments completedKhatmas', () {
      final recordings = [
        QuranRecording(
          id: 'q1',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'السبت',
          date: DateTime(2026, 9, 1),
          fromPage: 590,
          toPage: 604,
          count: 15,
        ),
      ];

      final summary = summarizeQuranProgress(recordings);
      expect(summary.completedKhatmas, 1);
      expect(summary.currentPage, 0); // يبدأ من جديد
    });

    test('two full khatmas counted correctly', () {
      final recordings = [
        // الختمة الأولى
        QuranRecording(
          id: 'q1',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'السبت',
          date: DateTime(2026, 9, 1),
          fromPage: 1,
          toPage: 604,
          count: 604,
        ),
        // الختمة الثانية
        QuranRecording(
          id: 'q2',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'الأحد',
          date: DateTime(2026, 10, 1),
          fromPage: 1,
          toPage: 604,
          count: 604,
        ),
      ];

      final summary = summarizeQuranProgress(recordings);
      expect(summary.completedKhatmas, 2);
      expect(summary.totalPagesRead, 1208);
      expect(summary.currentPage, 0);
    });

    test('lastDate is the most recent recording date', () {
      final recordings = [
        QuranRecording(
          id: 'q1',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'السبت',
          date: DateTime(2026, 9, 1),
          fromPage: 1,
          toPage: 10,
          count: 10,
        ),
        QuranRecording(
          id: 'q2',
          teacherId: 't1',
          pathwayId: 'mafatih',
          studentId: 's1',
          weekday: 'الأربعاء',
          date: DateTime(2026, 9, 5),
          fromPage: 11,
          toPage: 20,
          count: 10,
        ),
      ];

      final summary = summarizeQuranProgress(recordings);
      expect(summary.lastDate, DateTime(2026, 9, 5));
    });
  });
}
