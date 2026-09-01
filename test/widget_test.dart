import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/services/quran_service.dart';

void main() {
  group('QuranService.normalize', () {
    test('يحذف التشكيل والتطويل', () {
      expect(QuranService.normalize('الْحَمْدُ'), 'الحمد');
      expect(QuranService.normalize('قَالَ — ٱللَّهُـمَّ'), 'قال — اللهم');
    });

    test('يوحّد أشكال الألف', () {
      // ألف وصل → ألف عادية
      expect(QuranService.normalize('ٱلرَّحۡمَٰنِ'), 'الرحمن');
      // ألف ممدودة → ألف عادية
      expect(QuranService.normalize('آدم'), 'ادم');
      // ألف فوق همزة → ألف عادية
      expect(QuranService.normalize('أحمد'), 'احمد');
    });

    test('يحوّل تاء مربوطة إلى هاء', () {
      expect(QuranService.normalize('الرحمة'), 'الرحمه');
    });

    test('يحوّل ألف مقصورة إلى ياء', () {
      expect(QuranService.normalize('على'), 'علي');
    });

    test('يحوّل همزة standalone إلى ألف', () {
      expect(QuranService.normalize('ءادم'), 'اادم');
    });

    test('لا يغيّر النص الخالي من التشكيل', () {
      expect(QuranService.normalize('بسم الله'), 'بسم الله');
    });
  });
}
