import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/services/bookmark_service.dart';
import 'package:quran_app/services/quran_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبار تحميل خدمة القرآن وبناء كل الفهارس — يعيد إنتاج أي خطأ تحميل
/// يظهر على الجهاز مع تتبع مكدس كامل ورموز (بعكس وضع الإصدار).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QuranService.load يبني كل الفهارس بنجاح', () async {
    final service = await QuranService.load();

    expect(service.surahs.length, 114);
    expect(service.allVerses.length, 6236);

    // فهرس الصفحات.
    expect(service.versesOnPage(1).first.chapter, 1);
    expect(service.versesOnPage(604), isNotEmpty);
    expect(service.pageOf(2, 2), inInclusiveRange(1, 604));

    // فهرس معرفات الآيات.
    expect(service.indexOfVerse(1, 1), 0);
    expect(service.indexOf(service.allVerses.first), 0);

    // نطاقات الأسطر (قد تعبر أكثر من آية).
    expect(service.versesForRange('1:1', '1:7').length, 7);
    expect(service.versesForRange('999:1', '999:2'), isEmpty);

    // البحث (يبني النص المطبع لأول مرة).
    expect(service.search('الرحمن'), isNotEmpty);
    expect(service.search(''), isEmpty);

    // بيانات التخطيط.
    final layout = await service.layout();
    expect(layout.lineCount(422), greaterThan(0));
    expect(layout.extents['madani']?[1], isNotNull);
  });

  test('BookmarkService يعمل بعد التهيئة', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = BookmarkService();
    await service.init();
    expect(service.bookmarks, isEmpty);
  });
}
