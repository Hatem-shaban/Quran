import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/juz.dart';
import '../models/surah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../services/settings_service.dart';
import '../utils/arabic_digits.dart';
import '../widgets/error_fallback.dart';

/// شاشة القراءة — كل صفحات المصحف (٦٠٤) متتالية مع تمرير أفقي.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.quranService,
    required this.bookmarkService,
    this.settingsService,
    required this.surah,
    this.initialVerse = 0,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;
  final SettingsService? settingsService;
  final Surah surah;
  final int initialVerse;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pageController;
  Timer? _positionSaveDebounce;

  late final List<_PageData> _pages;
  int _currentPageIndex = 0;
  Surah? _currentSurah;

  Surah get _displaySurah => _currentSurah ?? widget.surah;

  @override
  void initState() {
    super.initState();
    _pages = _buildAllPages();
    _currentSurah = widget.surah;

    // ابحث عن الصفحة الابتدائية بناءً على السورة والآية
    final startPage = widget.quranService.pageOf(
        widget.surah.number,
        widget.initialVerse > 0 ? widget.initialVerse : 1);
    final idx = _pages.indexWhere((p) => p.pageNumber == startPage);
    _currentPageIndex = idx >= 0 ? idx : 0;

    _pageController = PageController(initialPage: _currentPageIndex);
  }

  /// بناء جميع صفحات المصحف (٦٠٤ صفحة) من جميع السور.
  List<_PageData> _buildAllPages() {
    final pageMap = <int, List<Verse>>{};
    for (final verse in widget.quranService.allVerses) {
      final pageNum = widget.quranService.pageOf(
          verse.chapter, verse.number);
      (pageMap[pageNum] ??= []).add(verse);
    }
    return [
      for (final entry in pageMap.entries)
        _PageData(
          verses: List.unmodifiable(entry.value),
          pageNumber: entry.key,
        ),
    ]..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _pages.length) return;
    final page = _pages[index];
    final firstVerse = page.verses.first;

    // تحديث السورة الحالية
    final newSurah = widget.quranService.surahOf(firstVerse.chapter);

    if (mounted) {
      setState(() {
        _currentPageIndex = index;
        _currentSurah = newSurah;
      });
    }

    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      widget.bookmarkService.setLastRead(
          firstVerse.chapter, firstVerse.number);
    });
  }

  @override
  void dispose() {
    _positionSaveDebounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showVerseActions(Verse verse) async {
    final isBookmarked =
        widget.bookmarkService.isBookmarked(verse.key);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(isBookmarked
                  ? 'إزالة من العلامات المرجعية'
                  : 'إضافة إلى العلامات المرجعية'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                widget.bookmarkService.toggleBookmark(verse.key);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ الآية'),
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text:
                        '${verse.text}\n﴿${toArabicDigits(verse.number)}﴾ ${widget.surah.name}'));
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الآية')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJumpToPageDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => const _JumpDialog(),
    );
    if (result != null && mounted) {
      final targetIndex =
          _pages.indexWhere((p) => p.pageNumber == result);
      if (targetIndex >= 0 && _pageController.hasClients) {
        _pageController.jumpToPage(targetIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily =
        widget.settingsService?.fontFamily ?? 'Amiri Quran';
    return Scaffold(
        appBar: AppBar(
          title: Text(_displaySurah.name),

          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _showJumpToPageDialog,
              icon: const Icon(Icons.book),
              tooltip: 'انتقل إلى صفحة',
            ),
          ],
        ),
        body: SafeChild(
          builder: (_) => PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final page = _pages[index];
              // ابدأ بسم الله في أول صفحة لكل سورة ما عدا الفاتحة والتوبة
              final firstChapter = page.verses.first.chapter;
              final isFirstPage = index == 0 ||
                  _pages[index - 1].verses.first.chapter != firstChapter;
              final showBismillah = isFirstPage &&
                  firstChapter != 1 && firstChapter != 9;
              final juz = Juz.of(firstChapter, page.verses.first.number);
              return _MushafPage(
                page: page,
                juz: juz,
                showBismillah: showBismillah,
                onVerseTap: _showVerseActions,
                fontFamily: fontFamily,
                surahNames: {
                  for (final s in widget.quranService.surahs)
                    s.number: s.name,
                },
              );
            },
          ),
        ),
      );
  }
}

/// بيانات صفحة واحدة.
class _PageData {
  final List<Verse> verses;
  final int pageNumber;

  const _PageData({required this.verses, required this.pageNumber});
}

/// صفحة مصحف تملأ الشاشة بالكامل.
/// يستخدم TextPainter لحساب حجم الخط الأمثل.
class _MushafPage extends StatelessWidget {
  const _MushafPage({
    required this.page,
    required this.juz,
    required this.showBismillah,
    required this.onVerseTap,
    required this.fontFamily,
    this.surahNames,
  });

  final _PageData page;
  final Juz juz;
  final bool showBismillah;
  final void Function(Verse) onVerseTap;
  final String fontFamily;
  final Map<int, String>? surahNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _groupVerses(page.verses);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final paddingV = maxH * 0.012;
        final bismillahH = showBismillah ? maxH * 0.04 : 0.0;
        final headerH = maxH * 0.04;
        // حساب ارتفاع فواصل السور (+ مساحة أمان للعناصرﻹضافية)
        final separatorCount = segments.length > 1 ? segments.length - 1 : 0;
        final separatorH = separatorCount * (maxH * 0.10); // ~10% per separator (divider + icon + name + bismillah)
        final textAreaH = (maxH - paddingV * 2 - bismillahH - headerH - separatorH) * 0.85 - 40; // safety margin 15% + 40px buffer for TextPainter vs rendering discrepancy
        final textAreaW = maxW - 24; // padding horizontal

        // بناء نص الآيات الكامل مع فواصل السور
        final buffer = StringBuffer();
        int? lastChapter;
        for (final v in page.verses) {
          if (lastChapter != null && v.chapter != lastChapter) {
            buffer.write('سورة separator ');
          }
          buffer.write('${v.text} ﴿${toArabicDigits(v.number)}﴾  ');
          lastChapter = v.chapter;
        }
        final fullText = buffer.toString();

        // حساب حجم الخط الأمثل باستخدام TextPainter
        final fontSize = _findOptimalFontSize(
          text: fullText,
          fontFamily: fontFamily,
          maxWidth: textAreaW,
          maxHeight: textAreaH,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          padding: EdgeInsets.symmetric(
              horizontal: 12, vertical: paddingV),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withAlpha(30),
            ),
          ),
          child: Column(
            children: [
              // رأس الصفحة: الجزء ورقم الصفحة
              SizedBox(
                height: headerH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${juz.name} · صفحة ${toArabicDigits(page.pageNumber)}',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        color: theme.colorScheme.outline,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              if (showBismillah) ...[
                SizedBox(
                  height: bismillahH,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 22,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
              // الآيات
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int s = 0; s < segments.length; s++) ...[
                        if (s > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(child: Divider(thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Icon(
                                        Icons.menu_book,
                                        size: fontSize * 0.85,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const Expanded(child: Divider(thickness: 1)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'سورة ${surahNames?[segments[s].chapter] ?? ''}',
                                  style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: fontSize * 0.85,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                if (segments[s].chapter != 1 && segments[s].chapter != 9) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                                    style: TextStyle(
                                      fontFamily: fontFamily,
                                      fontSize: fontSize * 0.7,
                                      color: theme.colorScheme.primary.withAlpha(180),
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        Text.rich(
                          TextSpan(
                            children: [
                              for (final verse in segments[s].verses) ...[
                                TextSpan(
                                  text: verse.text,
                                  style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: fontSize,
                                    height: 1.8,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ﴿${toArabicDigits(verse.number)}﴾ ',
                                  style: TextStyle(
                                    fontSize: fontSize * 0.8,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static List<_VerseSegment> _groupVerses(List<Verse> verses) {
    final segments = <_VerseSegment>[];
    for (final v in verses) {
      if (segments.isEmpty || segments.last.chapter != v.chapter) {
        segments.add(_VerseSegment(v.chapter, [v]));
      } else {
        segments.last.verses.add(v);
      }
    }
    return segments;
  }

  /// حساب حجم الخط الأمثل الذي يملأ المساحة المتاحة
  double _findOptimalFontSize({
    required String text,
    required String fontFamily,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) return 18.0;
    // البحث الثنائي عن أفضل حجم خط
    double low = 12.0;
    double high = 36.0;
    double bestSize = 18.0;

    for (int i = 0; i < 15; i++) {
      final mid = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: mid,
            height: 1.8,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: null,
      );
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight) {
        bestSize = mid;
        low = mid + 0.5;
      } else {
        high = mid - 0.5;
      }
      painter.dispose();
    }

    return bestSize;
  }
}

class _VerseSegment {
  final int chapter;
  final List<Verse> verses;
  _VerseSegment(this.chapter, this.verses);
}

class _JumpDialog extends StatefulWidget {
  const _JumpDialog();

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final page = parseArabicDigits(_controller.text);
    if (page != null && page >= 1 && page <= QuranService.totalPages) {
      Navigator.of(context).pop(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('انتقل إلى صفحة'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        autofocus: true,
        decoration: InputDecoration(
          hintText:
              'رقم الصفحة (١-${toArabicDigits(QuranService.totalPages)})',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('انتقال'),
        ),
      ],
    );
  }
}


