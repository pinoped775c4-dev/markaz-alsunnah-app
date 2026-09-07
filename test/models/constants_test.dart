import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_center_manager/core/constants.dart';

void main() {
  group('AppConstants', () {
    test('studentsCountText returns correct Arabic plural forms', () {
      expect(AppConstants.studentsCountText(0), 'لا يوجد طلاب');
      expect(AppConstants.studentsCountText(1), 'طالب واحد');
      expect(AppConstants.studentsCountText(2), 'طالبان');
      expect(AppConstants.studentsCountText(3), '3 طلاب');
      expect(AppConstants.studentsCountText(10), '10 طلاب');
      expect(AppConstants.studentsCountText(11), '11 طالباً');
      expect(AppConstants.studentsCountText(100), '100 طالباً');
    });

    test('pathwayImageAsset returns correct asset paths', () {
      expect(AppConstants.pathwayImageAsset('mafatih'), 'assets/pathways/mafatih.png');
      expect(AppConstants.pathwayImageAsset('maarij1'), 'assets/pathways/maarij1.png');
      expect(AppConstants.pathwayImageAsset('maarij2'), 'assets/pathways/maarij2.png');
      expect(AppConstants.pathwayImageAsset('maarij3'), 'assets/pathways/maarij3.png');
      expect(AppConstants.pathwayImageAsset('quran'), null);
      expect(AppConstants.pathwayImageAsset('unknown'), null);
    });

    test('khatmaPages is 604', () {
      expect(AppConstants.khatmaPages, 604);
    });

    test('pathways list has 5 items', () {
      expect(AppConstants.pathways.length, 5);
    });
  });

  group('PathwayInfo', () {
    test('isQuranOnly returns true only for quran pathway', () {
      final quran = AppConstants.pathways.firstWhere((p) => p.id == 'quran');
      expect(quran.isQuranOnly, true);

      final mafatih = AppConstants.pathways.firstWhere((p) => p.id == 'mafatih');
      expect(mafatih.isQuranOnly, false);
    });

    test('quran pathway has only one tab', () {
      final quran = AppConstants.pathways.firstWhere((p) => p.id == 'quran');
      expect(quran.tabs.length, 1);
      expect(quran.tabs.first, 'القرآن');
    });

    test('non-quran pathways have 4 tabs', () {
      final mafatih = AppConstants.pathways.firstWhere((p) => p.id == 'mafatih');
      expect(mafatih.tabs.length, 4);
      expect(mafatih.tabs, ['الطلاب', 'الدروس', 'المتون', 'القرآن']);
    });
  });

  group('fmtNum', () {
    test('formats integer doubles without decimal', () {
      expect(fmtNum(5.0), '5');
      expect(fmtNum(10.0), '10');
      expect(fmtNum(0.0), '0');
    });

    test('formats fractional doubles with decimals', () {
      expect(fmtNum(5.5), '5.5');
      expect(fmtNum(3.14159), '3.1416');
    });
  });
}
