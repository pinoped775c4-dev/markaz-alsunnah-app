import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/models/lesson.dart';
import 'package:islamic_center_manager/models/matna.dart';
import 'package:islamic_center_manager/models/student.dart';

/// اختبارات النماذج: الدرس، المتن، الطالب
/// تكشف أخطاء الحسابات والحقول المنطقية
void main() {
  group('Lesson', () {
    // ===== النوع =====

    test('nazm lesson: isNazm is true, unit is بيت', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'الألفية',
        type: 'nazm',
        totalCount: 100,
      );
      expect(lesson.isNazm, true);
      expect(lesson.unitLabel, 'بيت');
      expect(lesson.typeLabel, 'نظم');
    });

    test('nathr lesson: isNazm is false, unit is صفحة', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'الورقات',
        type: 'nathr',
        totalCount: 50,
      );
      expect(lesson.isNazm, false);
      expect(lesson.unitLabel, 'صفحة');
      expect(lesson.typeLabel, 'نثر');
    });

    // ===== التقدم =====

    test('progress: 25 from 100 = 0.25 (25%)', () {
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

    test('progress: 0 from 100 = 0.0 (0%)', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس',
        type: 'nathr',
        totalCount: 100,
        completedCount: 0,
      );
      expect(lesson.progress, 0.0);
      expect(lesson.progressPercent, 0);
      expect(lesson.remainingCount, 100);
    });

    test('progress: 100 from 100 = 1.0 (100%)', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس',
        type: 'nathr',
        totalCount: 100,
        completedCount: 100,
      );
      expect(lesson.progress, 1.0);
      expect(lesson.progressPercent, 100);
      expect(lesson.remainingCount, 0);
    });

    test('progress clamps: completed > total = 1.0 (not > 1)', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس',
        type: 'nathr',
        totalCount: 100,
        completedCount: 150, // أكثر من الإجمالي!
      );
      expect(lesson.progress, 1.0); // لا يتجاوز 1
      expect(lesson.remainingCount, 0); // لا يكون سالب
    });

    test('progress with totalCount = 0 returns 0 (no division by zero)', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'درس',
        type: 'nathr',
        totalCount: 0,
        completedCount: 0,
      );
      expect(lesson.progress, 0.0); // لا يقسم على صفر
    });

    // ===== toMap =====

    test('toMap contains all required fields', () {
      final lesson = Lesson(
        id: 'l1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'الورقات',
        type: 'nathr',
        totalCount: 50,
        completedCount: 10,
      );

      final map = lesson.toMap();
      expect(map['teacherId'], 't1');
      expect(map['pathwayId'], 'mafatih');
      expect(map['name'], 'الورقات');
      expect(map['type'], 'nathr');
      expect(map['totalCount'], 50);
      expect(map['completedCount'], 10);
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

    test('nazm matna: unit is بيت', () {
      final matna = Matna(
        id: 'm1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'ألفية',
        type: 'nazm',
        totalCount: 100,
      );
      expect(matna.isNazm, true);
      expect(matna.unitLabel, 'بيت');
      expect(matna.typeLabel, 'نظم');
    });

    test('nathr matna: unit is صفحة', () {
      final matna = Matna(
        id: 'm1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        name: 'متون',
        type: 'nathr',
        totalCount: 50,
      );
      expect(matna.isNazm, false);
      expect(matna.unitLabel, 'صفحة');
      expect(matna.typeLabel, 'نثر');
    });
  });

  group('Student', () {
    test('active student: isActive is true', () {
      final student = Student(
        id: 's1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        pathwayName: 'مفاتيح الطلب',
        name: 'أحمد',
        status: 'active',
      );
      expect(student.isActive, true);
    });

    test('inactive student: isActive is false', () {
      final student = Student(
        id: 's1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        pathwayName: 'مفاتيح الطلب',
        name: 'أحمد',
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
        name: 'أحمد',
        phone: '777123456',
      );

      final map = student.toMap();
      expect(map['teacherId'], 't1');
      expect(map['pathwayId'], 'mafatih');
      expect(map['pathwayName'], 'مفاتيح الطلب');
      expect(map['name'], 'أحمد');
      expect(map['phone'], '777123456');
    });

    test('default values: status is active, totalQuranPages is 0', () {
      final student = Student(
        id: 's1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        pathwayName: 'مفاتيح الطلب',
        name: 'أحمد',
      );
      expect(student.status, 'active');
      expect(student.totalQuranPages, 0);
    });
  });
}
