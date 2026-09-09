/// خدمة تحميل بيانات القرآن من الأصول المحلية (تعمل دون اتصال بالإنترنت).
///
/// كل الفهارس (خريطة الصفحات، مواضع الآيات، نصوص البحث المطبع) تُبنى مرة
/// واحدة عند التحميل، فلا تُنفَّذ أي عملية O(n) أثناء التفاعل مع الشاشات.
library;

import 'dart:convert';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/services.dart' show rootBundle;

import '../models/surah.dart';

class QuranService {
  QuranService._();

  static QuranService? _instance;

  /// تحميل الخدمة (مرة واحدة فقط).
  static Future<QuranService> load() async {
    if (_instance != null) return _instance!;
    final service = QuranService._();
    await service._init();
    _instance = service;
    return service;
  }

  final List<Surah> _surahs = [];
  final List<List<Verse>> _versesByChapter = [];
  final List<Verse> _allVerses = [];

  /// الفهارس المحسوبة مسبقًا (تُبنى مرة واحدة):
  late final Int32List _versePage;        // معرّف الآية → رقم الصفحة
  late final List<List<Verse>> _pages;    // رقم الصفحة → آياتها
  late final Map<String, int> _verseKeyToIndex; // "سورة:آية" → معرّف عالمي

  /// نصوص الآيات بعد إزالة التشكيل — تُبنى كسولًا عند أول بحث فقط
  /// (٦٢٣٦ نصًا ≈ ٢MB لا يُدفع إلا لمن يستخدم البحث).
  List<String>? _searchCorpus;

  /// عرض غير قابل للتعديل — يُنشأ مرة واحدة (بدل نسخة في كل استدعاء).
  late final List<Surah> _surahsView = List.unmodifiable(_surahs);
  late final List<Verse> _allVersesView = List.unmodifiable(_allVerses);

  bool get isReady => _surahs.isNotEmpty;

  List<Surah> get surahs => _surahsView;

  Surah surahOf(int chapter) => _surahs[chapter - 1];

  /// آيات سورة معينة — عرض مباشر على القائمة المخزنة (بدون نسخ).
  List<Verse> versesOfSurah(int chapter) => _versesByChapter[chapter - 1];

  /// جميع آيات القرآن مرتبة ترتيبًا مصحفيًا — عرض واحد ثابت (بدون نسخ).
  List<Verse> get allVerses => _allVersesView;

  Future<void> _init() async {
    // قراءة ملفات الأصول تجري على isolate الواجهة (rootBundle يحتاج ربط
    // Flutter ولا يعمل داخل isolate خلفي)، والتحميل بالتوازي — يقصّ زمن
    // الإقلاع إلى زمن أبطأ ملف بدل مجموعها.
    final raws = await Future.wait<String>([
      rootBundle.loadString('assets/data/chapters.json'),
      rootBundle.loadString('assets/data/quran_uthmani.json'),
      rootBundle.loadString('assets/data/verse_pages.json'),
    ]);

    // فك JSON (١.٦MB+) وبناء بيانات الآيات — عملية سريعة (عشرات المللي
    // ثانية) تُنفَّذ على isolate الواجهة مباشرة: إرسال كائنات الداتا عبر
    // حدود العوازل سبب أعطال فك رسائل في وضع الإصدار على بعض الأجهزة.
    final parsed = _parseQuranData(raws);

    // بناء الفهارس من البيانات الجاهزة (عمليات رخيصة في الذاكرة).
    _surahs.addAll(parsed.surahs);
    final versesByChapter = List<List<Verse>>.generate(
      _surahs.length,
      (_) => <Verse>[],
      growable: false,
    );
    _versesByChapter.addAll(versesByChapter);

    final count = parsed.verses.length;
    // ملاحظة: لا يجوز تنمية قائمة List<Verse> عبر length= — يملأ الفتحات
    // الجديدة بـ null ويُخلّ بنوع العناصر غير القابلة للـ null (سبب انهيار
    // الإقلاع). تُبنى القائمة من البيانات المحلَّلة جاهزة بدلًا من ذلك.
    _allVerses.addAll(parsed.verses);
    _verseKeyToIndex = HashMap<String, int>();
    _versePage = parsed.versePages;

    final pages = List<List<Verse>>.generate(
      totalPages + 1, // الفهرس ٠ غير مستخدم
      (_) => const <Verse>[],
      growable: false,
    );
    for (var i = 0; i < count; i++) {
      final verse = parsed.verses[i];
      _versesByChapter[verse.chapter - 1].add(verse);
      _verseKeyToIndex[verse.key] = i;
      final page = _versePage[i];
      final bucket = pages[page];
      pages[page] = bucket.isEmpty
          ? <Verse>[verse]
          : List<Verse>.from(bucket)..add(verse);
    }
    _pages = pages;

    // تسخين بيانات التخطيط مبكرًا (بالتوازي مع أول إطار عرض).
    _layoutFuture = _loadLayout().then((l) => _layoutCache = l);
  }

  /// رقم الصفحة في المصحف لآية معينة.
  int pageOf(int chapter, int verse) =>
      _versePage[indexOfVerse(chapter, verse) ?? 0];

  /// إجمالي صفحات المصحف.
  static const int totalPages = 604;

  /// المعرف العالمي للآية ("سورة:آية")، أو null إن لم توجد.
  int? indexOfVerse(int chapter, int verse) =>
      _verseKeyToIndex['$chapter:$verse'];

  /// المعرف العالمي عبر كائن الآية.
  int indexOf(Verse verse) => _verseKeyToIndex[verse.key] ?? -1;

  /// آيات صفحة مصحف معينة (١..٦٠٤) — قائمة محسوبة مسبقًا.
  List<Verse> versesOnPage(int page) => _pages[page];

  /// آيات النطاق من آية البداية إلى آية النهاية شاملًا (سطر مصحف واحد
  /// قد يمتد عبر أكثر من آية).
  List<Verse> versesForRange(String startKey, String endKey) {
    final start = _verseKeyToIndex[startKey];
    final end = _verseKeyToIndex[endKey];
    if (start == null || end == null || end < start) return const <Verse>[];
    return _allVersesView.sublist(start, end + 1);
  }

  /// البحث في جميع آيات القرآن مع تجاهل التشكيل.
  ///
  /// النص المطبع (بلا تشكيل) يُبنى مرة واحدة عند أول بحث، ثم تبقى كل
  /// عملية بحث مسحًا خطيًا على مقارنات جاهزة — بلا إعادة تطبيع لكل آية.
  List<Verse> search(String query) {
    final needle = normalize(query.trim());
    if (needle.isEmpty) return const <Verse>[];

    final corpus = _searchCorpus ??= [
      for (final verse in _allVersesView) normalize(verse.text),
    ];

    return [
      for (var i = 0; i < corpus.length; i++)
        if (corpus[i].contains(needle)) _allVersesView[i],
    ];
  }

  /// بيانات تخطيط المصحف (خطوط كل صفحة + حدود كتلة النص) — تُحمّل وتُفك
  /// مرة واحدة ثم تُخزَّن للجلسة كلها (بدل إعادة تحليل JSON في كل فتح قارئ).
  MushafLayout? _layoutCache;
  Future<MushafLayout>? _layoutFuture;

  Future<MushafLayout> layout() {
    final cached = _layoutCache;
    if (cached != null) return SynchronousFuture(cached);
    return _layoutFuture ??= _loadLayout().then((l) => _layoutCache = l);
  }

  Future<MushafLayout> _loadLayout() async {
    try {
      return await _parseLayout();
    } catch (_) {
      // بيانات تالفة لا تُعطّل القارئ — تُعرض الصفحات بلا تخطيط.
      return const MushafLayout(lines: {}, extents: {});
    }
  }

  Future<MushafLayout> _parseLayout() async {
    final results = await Future.wait([
      // التخطيط اختياري: غياب ملف لا يُعطّل القارئ.
      _loadOptionalJson('assets/data/page_lines.json'),
      _loadOptionalJson('assets/data/page_extents.json'),
    ]);

    final lines = <int, List<List<int>?>>{};
    for (final e in results[0].entries) {
      lines[int.parse(e.key)] = (e.value! as List<dynamic>)
          .map((l) => l == null ? null : (l! as List<dynamic>).cast<int>())
          .toList(growable: false);
    }

    final extents = <String, Map<int, ({double left, double right})>>{};
    for (final e in results[1].entries) {
      final pages = <int, ({double left, double right})>{};
      for (final pe in (e.value! as Map<String, dynamic>).entries) {
        final arr = (pe.value! as List<dynamic>).cast<num>();
        pages[int.parse(pe.key)] =
            (left: arr[0].toDouble(), right: arr[1].toDouble());
      }
      extents[e.key] = pages;
    }
    return MushafLayout(lines: lines, extents: extents);
  }

  /// فك JSON اختياري — ملف مفقود يعاد كخريطة فارغة بدل الاستثناء.
  static Future<Map<String, dynamic>> _loadOptionalJson(String path) async {
    try {
      return jsonDecode(await rootBundle.loadString(path))
          as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  /// إزالة التشكيل وتوحيد أشكال الحروف لتسهيل البحث العربي.
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final code in input.runes) {
      // ── حذف التشكيل ──
      final isDiacritic =
          (code >= 0x0610 && code <= 0x061A) ||
          (code >= 0x064B && code <= 0x065F) ||
          code == 0x0670 ||
          code == 0x0640 ||
          (code >= 0x06D6 && code <= 0x06ED) ||
          (code >= 0x08D3 && code <= 0x08FF);
      if (isDiacritic) continue;

      // ── توحيد أشكال الألف ──
      if (code == 0x0622 || // أ  ألف ممدودة
          code == 0x0623 || // أ  ألف فوق همزة
          code == 0x0625 || // إ  ألف تحت همزة
          code == 0x0671 || // ٱ  ألف وصل
          code == 0x0621)   // ء  همزة مستقلة
      {
        buffer.writeCharCode(0x0627); // ا  ألف عادية
        continue;
      }

      // ── تاء مربوطة ← هاء ──
      if (code == 0x0629) {
        buffer.writeCharCode(0x0647); // ه
        continue;
      }

      // ── ألف مقصورة ← ياء ──
      if (code == 0x0649) {
        buffer.writeCharCode(0x064A); // ي
        continue;
      }

      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }
}

/// ناتج تحليل بيانات القرآن — كائن نقي قابل للإرسال بين العوازل،
/// يُبنى على isolate خلفي ثم يُستخدم لبناء فهارس الخدمة.
class _QuranData {
  const _QuranData({
    required this.surahs,
    required this.verses,
    required this.versePages,
  });

  final List<Surah> surahs;
  final List<Verse> verses;
  final Int32List versePages;
}

/// دالة تحليل نقية (بلا وصول لـ rootBundle أو ربط Flutter) — آمنة
/// للتنفيذ داخل isolate خلفي عبر [Isolate.run].
_QuranData _parseQuranData(List<String> raws) {
  final chaptersRaw = jsonDecode(raws[0]) as Map<String, dynamic>;
  final quranRaw = jsonDecode(raws[1]) as Map<String, dynamic>;
  final pagesRaw = jsonDecode(raws[2]) as Map<String, dynamic>;

  final surahs = [
    for (final chapter in chaptersRaw['chapters']! as List<dynamic>)
      Surah.fromJson(chapter! as Map<String, dynamic>),
  ];

  final verseList = quranRaw['quran']! as List<dynamic>;
  final count = verseList.length;
  final verses = List<Verse>.filled(count, Verse.empty, growable: false);
  final versePages = Int32List(count);

  for (var i = 0; i < count; i++) {
    final verse = Verse.fromJson(verseList[i]! as Map<String, dynamic>);
    verses[i] = verse;
    versePages[i] =
        (pagesRaw['${verse.chapter}:${verse.number}'] as num?)?.toInt() ?? 1;
  }

  return _QuranData(surahs: surahs, verses: verses, versePages: versePages);
}

/// بيانات تخطيط المصحف المطبوع: خطوط كل صفحة وحدود كتلة النص فيها.
class MushafLayout {
  const MushafLayout({
    required this.lines,
    required this.extents,
  });

  /// لكل صفحة: خطوطها الـ ١٥ — كل خط هو
  /// [سورة_البداية، آية_البداية، سورة_النهاية، آية_النهاية]
  /// أو null للخطوط الزخرفية (رأس سورة / بسملة).
  final Map<int, List<List<int>?>> lines;

  /// لكل نمط وصفحة: الحدود اليسرى/اليمنى لكتلة النص (كسور من عرض الصورة)
  /// — تُستخدم لتكبير الصفحة إلى أقصى حجم لا يُقصّ فيه أي نص.
  final Map<String, Map<int, ({double left, double right})>> extents;

  /// عدد أسطر الصفحة (٠ إن غابت البيانات).
  int lineCount(int page) => lines[page]?.length ?? 0;

  /// آيات السطر عند فهرس معين، أو قائمة فارغة للخطوط الزخرفية.
  List<int>? lineRange(int page, int lineIndex) {
    final pageLines = lines[page];
    if (pageLines == null || lineIndex < 0 || lineIndex >= pageLines.length) {
      return null;
    }
    return pageLines[lineIndex];
  }
}
