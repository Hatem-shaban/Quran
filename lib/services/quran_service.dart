/// خدمة تحميل بيانات القرآن من الأصول المحلية (تعمل دون اتصال بالإنترنت).
library;

import 'dart:convert';

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
  final Map<int, List<Verse>> _versesByChapter = {};
  final List<Verse> _allVerses = [];
  final Map<String, int> _verseToPage = {};

  bool get isReady => _surahs.isNotEmpty;

  List<Surah> get surahs => List.unmodifiable(_surahs);

  Surah surahOf(int chapter) => _surahs[chapter - 1];

  List<Verse> versesOfSurah(int chapter) =>
      List.unmodifiable(_versesByChapter[chapter] ?? const <Verse>[]);

  /// جميع آيات القرآن مرتبة ترتيباً تليدياً.
  List<Verse> get allVerses => List.unmodifiable(_allVerses);

  Future<void> _init() async {
    final chaptersRaw = jsonDecode(
      await rootBundle.loadString('assets/data/chapters.json'),
    ) as Map<String, dynamic>;
    for (final chapter in chaptersRaw['chapters']! as List<dynamic>) {
      _surahs.add(Surah.fromJson(chapter! as Map<String, dynamic>));
    }

    final quranRaw = jsonDecode(
      await rootBundle.loadString('assets/data/quran_uthmani.json'),
    ) as Map<String, dynamic>;
    for (final verseJson in quranRaw['quran']! as List<dynamic>) {
      final verse = Verse.fromJson(verseJson! as Map<String, dynamic>);
      (_versesByChapter[verse.chapter] ??= []).add(verse);
      _allVerses.add(verse);
    }

    final pagesRaw = jsonDecode(
      await rootBundle.loadString('assets/data/verse_pages.json'),
    ) as Map<String, dynamic>;
    for (final entry in pagesRaw.entries) {
      _verseToPage[entry.key] = entry.value as int;
    }
  }

  /// رقم الصفحة في المصحف لآية معينة.
  int pageOf(int chapter, int verse) =>
      _verseToPage['$chapter:$verse'] ?? 1;

  /// إجمالي صفحات المصحف.
  static const int totalPages = 604;

  /// البحث في جميع آيات القرآن مع تجاهل التشكيل.
  List<Verse> search(String query) {
    final needle = normalize(query.trim());
    if (needle.isEmpty) return const [];
    return [
      for (final verse in _allVerses)
        if (normalize(verse.text).contains(needle)) verse,
    ];
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
          code == 0x0671)   // ٱ  ألف وصل
      {
        buffer.writeCharCode(0x0627); // ا  ألف عادية
        continue;
      }

      // ── همزة单独 ← ألف ──
      if (code == 0x0621) {
        buffer.writeCharCode(0x0627); // ا
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
