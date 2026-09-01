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
  bool _initialSaveDone = false;

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
      final pageNum = widget.quranService.pageOf(verse.chapter, verse.number);
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

  void _saveCurrentPosition() {
    if (_currentPageIndex < 0 || _currentPageIndex >= _pages.length) return;
    final page = _pages[_currentPageIndex];
    final firstVerse = page.verses.first;
    widget.bookmarkService.setLastRead(firstVerse.chapter, firstVerse.number);
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
      _saveCurrentPosition();
    });
  }

  /// حفظ الموضع الحالي عند بناء الصفحة الأولى.
  void _onPageBuilt() {
    if (_initialSaveDone) return;
    _initialSaveDone = true;
    // تأخير بسيط للتأكد من أن الصفحة نشطة
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _saveCurrentPosition();
    });
  }

  @override
  void dispose() {
    _positionSaveDebounce?.cancel();
    // حفظ الموضع الأخير عند مغادرة الشاشة
    _saveCurrentPosition();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showVerseActions(Verse verse) async {
    final isBookmarked = widget.bookmarkService.isBookmarked(verse.key);
    final surah = widget.quranService.surahOf(verse.chapter);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // معاينة الآية
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                verse.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: widget.settingsService?.fontFamily ?? 'Amiri Quran',
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textDirection: TextDirection.rtl,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '﴿${toArabicDigits(verse.number)}﴾ سورة ${surah.name}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
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
                        '${verse.text}\n﴿${toArabicDigits(verse.number)}﴾ سورة ${surah.name}'));
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
      final targetIndex = _pages.indexWhere((p) => p.pageNumber == result);
      if (targetIndex >= 0 && _pageController.hasClients) {
        _pageController.jumpToPage(targetIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = widget.settingsService?.fontFamily ?? 'Amiri Quran';
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
        builder: (_) {
          final surahNames = {
            for (final s in widget.quranService.surahs) s.number: s.name,
          };
          // حفظ الموضع عند أول بناء
          WidgetsBinding.instance.addPostFrameCallback((_) => _onPageBuilt());
          return PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final page = _pages[index];
              final firstChapter = page.verses.first.chapter;
              final showBismillah = page.verses.first.number == 1 &&
                  firstChapter != 1 &&
                  firstChapter != 9;
              final juz = Juz.of(firstChapter, page.verses.first.number);
              return _MushafPage(
                page: page,
                juz: juz,
                showBismillah: showBismillah,
                surahName: surahNames[firstChapter],
                onVerseTap: _showVerseActions,
                fontFamily: fontFamily,
                surahNames: surahNames,
                bookmarkService: widget.bookmarkService,
              );
            },
          );
        },
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
class _MushafPage extends StatelessWidget {
  const _MushafPage({
    required this.page,
    required this.juz,
    required this.showBismillah,
    this.surahName,
    required this.onVerseTap,
    required this.fontFamily,
    this.surahNames,
    required this.bookmarkService,
  });

  final _PageData page;
  final Juz juz;
  final bool showBismillah;
  final String? surahName;
  final void Function(Verse) onVerseTap;
  final String fontFamily;
  final Map<int, String>? surahNames;
  final BookmarkService bookmarkService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _groupVerses(page.verses);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final paddingV = maxH * 0.012;
        final bismillahH = showBismillah ? maxH * 0.07 : 0.0;
        final headerH = maxH * 0.04;
        final separatorCount = segments.length > 1 ? segments.length - 1 : 0;
        final separatorH = separatorCount * (maxH * 0.10);
        final textAreaH = (maxH - paddingV * 2 - bismillahH - headerH - separatorH) * 0.85 - 40;
        final textAreaW = maxW - 24;

        // بناء نص الآيات لحساب حجم الخط
        final buffer = StringBuffer();
        for (final v in page.verses) {
          buffer.write('${v.text} ﴿${toArabicDigits(v.number)}﴾  ');
        }
        final fullText = buffer.toString();

        final fontSize = _findOptimalFontSize(
          text: fullText,
          fontFamily: fontFamily,
          maxWidth: textAreaW,
          maxHeight: textAreaH,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: paddingV),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF252525)
                : const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD4A843).withAlpha(60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // رأس الصفحة
              SizedBox(
                height: headerH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, size: 10, color: const Color(0xFFD4A843).withAlpha(120)),
                    const SizedBox(width: 6),
                    Text(
                      '${juz.name} · صفحة ${toArabicDigits(page.pageNumber)}',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13,
                        color: theme.colorScheme.outline,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.star, size: 10, color: const Color(0xFFD4A843).withAlpha(120)),
                  ],
                ),
              ),
              if (showBismillah) ...[
                SizedBox(
                  height: bismillahH,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (surahName != null) ...[
                          Text(
                            surahName!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 22,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // الآيات — كل آية تفاعلية بشكل منفصل
              Expanded(
                child: SingleChildScrollView(
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
                                    Expanded(
                                      child: Container(
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              const Color(0xFFD4A843).withAlpha(150),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4A843).withAlpha(30),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.auto_stories,
                                        size: fontSize * 0.7,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              const Color(0xFFD4A843).withAlpha(150),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  surahNames?[segments[s].chapter] ?? '',
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
                        // كل آية في منعطف مستقل لتكون تفاعلية
                        for (final verse in segments[s].verses)
                          _VerseWidget(
                            verse: verse,
                            fontSize: fontSize,
                            fontFamily: fontFamily,
                            onTap: () => onVerseTap(verse),
                            isBookmarked: bookmarkService.isBookmarked(verse.key),
                          ),
                      ],
                    ],
                  ),
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

  double _findOptimalFontSize({
    required String text,
    required String fontFamily,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) return 18.0;
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

/// آية فردية تفاعلية — يمكن النقر عليها لحفظ العلامة أو النسخ.
class _VerseWidget extends StatelessWidget {
  const _VerseWidget({
    required this.verse,
    required this.fontSize,
    required this.fontFamily,
    required this.onTap,
    required this.isBookmarked,
  });

  final Verse verse;
  final double fontSize;
  final String fontFamily;
  final VoidCallback onTap;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Text.rich(
          TextSpan(
            text: verse.text,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              height: 2.0,
              color: theme.colorScheme.onSurface,
            ),
            children: [
              TextSpan(
                text: ' ﴿${toArabicDigits(verse.number)}﴾',
                style: TextStyle(
                  fontSize: fontSize * 0.8,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isBookmarked)
                TextSpan(
                  text: '  ',
                  style: TextStyle(fontSize: fontSize * 0.5),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.bookmark,
                        size: fontSize * 0.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        ),
      ),
    );
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
