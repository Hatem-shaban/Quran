import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/services/quran_service.dart';

void main() {
  group('QuranService.normalize', () {
    test('يحذف التشكيل والتطويل', () {
      expect(QuranService.normalize('الْحَمْدُ'), 'الحمد');
      expect(QuranService.normalize('ٱلرَّحۡمَٰنِ'), 'ٱلرحمن');
      expect(QuranService.normalize('قَالَ — ٱللَّهُـمَّ'), 'قال — ٱللهم');
    });

    test('لا يغيّر النص الخالي من التشكيل', () {
      expect(QuranService.normalize('بسم الله'), 'بسم الله');
    });
  });
}
