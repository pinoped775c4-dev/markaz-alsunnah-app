import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/models/matna.dart';

/// اختبارات نموذج تسجيل المتون (MutunRecording)
void main() {
  group('MutunRecording', () {
    // ===== الحالة الافتراضية =====

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

    // ===== حالات الحضور =====

    test('absent status: isAbsent is true, wasPresent is false', () {
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
      expect(recording.isNotListened, false);
      expect(recording.statusLabel, 'غائب');
    });

    test('not_listened status: isNotListened is true, wasPresent is false', () {
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
        status: 'not_listened',
      );
      expect(recording.isAbsent, false);
      expect(recording.isNotListened, true);
      expect(recording.wasPresent, false);
      expect(recording.statusLabel, 'لم يسمع');
    });

    // ===== isOfficial =====

    test('isOfficial defaults to false', () {
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
      expect(recording.isOfficial, false);
    });

    test('isOfficial can be set to true', () {
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
        isOfficial: true,
      );
      expect(recording.isOfficial, true);
    });

    // ===== القيم =====

    test('from, to, count are stored correctly', () {
      final recording = MutunRecording(
        id: 'mr1',
        teacherId: 't1',
        pathwayId: 'mafatih',
        matnaId: 'm1',
        studentId: 's1',
        weekday: 'السبت',
        date: DateTime(2026, 9, 6),
        from: 5,
        to: 15,
        count: 11,
      );
      expect(recording.from, 5);
      expect(recording.to, 15);
      expect(recording.count, 11);
    });

    test('notes can be null', () {
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
      expect(recording.notes, isNull);
    });

    test('notes can have value', () {
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
        notes: 'أحسنت في الحفظ',
      );
      expect(recording.notes, 'أحسنت في الحفظ');
    });
  });
}
