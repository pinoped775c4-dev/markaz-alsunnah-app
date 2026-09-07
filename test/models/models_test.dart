import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/models/app_user.dart';
import 'package:islamic_center_manager/models/student.dart';
import 'package:islamic_center_manager/models/lesson.dart';
import 'package:islamic_center_manager/models/matna.dart';
import 'package:islamic_center_manager/models/quran.dart';

void main() {
  group('AppUser', () {
    test('isAdmin returns true for admin role', () {
      final user = AppUser(
        uid: 'test-uid',
        role: 'admin',
        name: 'Test Admin',
        email: 'admin@test.com',
        status: 'active',
      );
      expect(user.isAdmin, true);
      expect(user.isTeacher, false);
      expect(user.isActive, true);
    });

    test('isTeacher returns true for teacher role', () {
      final user = AppUser(
        uid: 'test-uid',
        role: 'teacher',
        name: 'Test Teacher',
        email: 'teacher@test.com',
        status: 'active',
      );
      expect(user.isAdmin, false);
      expect(user.isTeacher, true);
      expect(user.isActive, true);
    });

    test('isActive returns false for disabled status', () {
      final user = AppUser(
        uid: 'test-uid',
        role: 'teacher',
        name: 'Test Teacher',
        email: 'teacher@test.com',
        status: 'disabled',
      );
      expect(user.isActive, false);
    });

    test('toMap contains all required fields', () {
      final user = AppUser(
        uid: 'test-uid',
        role: 'teacher',
        name: 'Test',
        email: 'test@test.com',
        status: 'active',
      );
      final map = user.toMap();
      expect(map['role'], 'teacher');
      expect(map['name'], 'Test');
      expect(map['email'], 'test@test.com');
      expect(map['status'], 'active');
    });
  });

  group('Student', () {
    test('isActive returns true for active status', () {
      final student = Student(
        id: 's1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        pathwayName: 'مفاتيح الطلب',
        name: 'طالب اختبار',
        status: 'active',
      );
      expect(student.isActive, true);
    });

    test('isActive returns false for inactive status', () {
      final student = Student(
        id: 's1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        pathwayName: 'مفاتيح الطلب',
        name: 'طالب اختبار',
        status: 'inactive',
      );
      expect(student.isActive, false);
    });

    test('toMap contains teacherId and pathwayId', () {
      final student = Student(
        id: 's1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        pathwayName: 'مفاتيح الطلب',
        name: 'طالب',
      );
      final map = student.toMap();
      expect(map['teacherId'], 't1');
      expect(map['pathwayId'], 'mafatih');
    });
  });

  group('Lesson', () {
    test('isNazm returns true for nazm type', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس نظم',
        type: 'nazm',
        totalCount: 100,
      );
      expect(lesson.isNazm, true);
      expect(lesson.unitLabel, 'بيت');
      expect(lesson.typeLabel, 'نظم');
    });

    test('isNazm returns false for nathr type', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس نثر',
        type: 'nathr',
        totalCount: 50,
      );
      expect(lesson.isNazm, false);
      expect(lesson.unitLabel, 'صفحة');
      expect(lesson.typeLabel, 'نثر');
    });

    test('progress calculation is correct', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس',
        type: 'nathr',
        totalCount: 100,
        completedCount: 25,
      );
      expect(lesson.progress, 0.25);
      expect(lesson.progressPercent, 25);
      expect(lesson.remainingCount, 75);
    });

    test('progress clamps to 0-1 range', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس',
        type: 'nathr',
        totalCount: 100,
        completedCount: 150, // أكثر من الإجمالي
      );
      expect(lesson.progress, 1.0);
    });
  });

  group('Matna', () {
    test('isOfficial defaults to false', () {
      final matna = Matna(
        id: 'm1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'متن',
        type: 'nathr',
        totalCount: 50,
      );
      expect(matna.isOfficial, false);
    });

    test('isOfficial can be set to true', () {
      final matna = Matna(
        id: 'm1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'متن رسمي',
        type: 'nathr',
        totalCount: 50,
        isOfficial: true,
      );
      expect(matna.isOfficial, true);
    });
  });

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
  });

  group('QuranProgressSummary', () {
    test('empty summary has zero values', () {
      expect(QuranProgressSummary.empty.currentPage, 0);
      expect(QuranProgressSummary.empty.completedKhatmas, 0);
      expect(QuranProgressSummary.empty.totalPagesRead, 0);
      expect(QuranProgressSummary.empty.khatmaProgress, 0.0);
      expect(QuranProgressSummary.empty.remainingPages, 604);
    });
  });

  group('MutunRecording', () {
    test('default status is present', () {
      final recording = MutunRecording(
        id: 'mr1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        matnaId: 'm1',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        from: 1,
        to: 10,
        count: 10,
      );
      expect(recording.status, 'present');
      expect(recording.wasPresent, true);
      expect(recording.isAbsent, false);
      expect(recording.isNotListened, false);
      expect(recording.statusLabel, 'حاضر');
    });

    test('absent status is handled correctly', () {
      final recording = MutunRecording(
        id: 'mr1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        matnaId: 'm1',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        from: 0,
        to: 0,
        count: 0,
        status: 'absent',
      );
      expect(recording.isAbsent, true);
      expect(recording.wasPresent, false);
      expect(recording.statusLabel, 'غائب');
    });
  });
}
