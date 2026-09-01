import 'dart:async';

import 'package:flutter/gestures.dart';
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

    final startPage = widget.quranService.pageOf(
        widget.surah.number,
        widget.initialVerse > 0 ? widget.initialVerse : 1);
    final idx = _pages.indexWhere((p) => p.pageNumber == startPage);
    _currentPageIndex = idx >= 0 ? idx : 0;

    _pageController = PageController(initialPage: _currentPageIndex);
  }

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

  void _onPageBuilt() {
    if (_initialSaveDone) return;
    _initialSaveDone = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _saveCurrentPosition();
    });
  }

  @override
  void dispose() {
    _positionSaveDebounce?.cancel();
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                verse.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily:
                      widget.settingsService?.fontFamily ?? 'Amiri Quran',
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

/// صفحة مصحف — النص ينساب كفقرات مركوزة (طراز المصحف الحقيقي).
/// لا تمرير عمودي: كل المحتوى يملأ الصفحة بالكامل.
class _MushafPage extends StatefulWidget {
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
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _groupVerses(widget.page.verses);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;

        // ── حساب المساحات الثابتة ──
        const paddingV = 10.0;
        const headerH = 30.0;
        final bismillahH = widget.showBismillah ? 56.0 : 0.0;
        final separatorCount = segments.length > 1 ? segments.length - 1 : 0;
        // كل فاصل: خط + اسم سورة + بسملة
        final separatorH = separatorCount * 68.0;

        final verseAreaH =
            maxH - (paddingV * 2) - headerH - bismillahH - separatorH - 16;
        final textAreaW = maxW - 32;

        // ── حساب حجم الخط ──
        final buffer = StringBuffer();
        for (final v in widget.page.verses) {
          buffer.write('${v.text} ﴿${toArabicDigits(v.number)}﴾  ');
        }
        final fullText = buffer.toString();

        final fontSize = _findOptimalFontSize(
          text: fullText,
          fontFamily: widget.fontFamily,
          maxWidth: textAreaW,
          maxHeight: verseAreaH,
        );
        final lineHeight = fontSize < 20 ? 1.6 : fontSize < 26 ? 1.7 : 1.8;

        // ── تنظيف recognizer القديمة ──
        for (final r in _recognizers) {
          r.dispose();
        }
        _recognizers.clear();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: paddingV),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── رأس الصفحة ──
              SizedBox(
                height: headerH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star,
                        size: 10,
                        color: const Color(0xFFD4A843).withAlpha(120)),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.juz.name} · صفحة ${toArabicDigits(widget.page.pageNumber)}',
                      style: TextStyle(
                        fontFamily: widget.fontFamily,
                        fontSize: 13,
                        color: theme.colorScheme.outline,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.star,
                        size: 10,
                        color: const Color(0xFFD4A843).withAlpha(120)),
                  ],
                ),
              ),

              // ── بسملة البداية ──
              if (widget.showBismillah) ...[
                SizedBox(
                  height: bismillahH,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.surahName != null) ...[
                          Text(
                            widget.surahName!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: widget.fontFamily,
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
                            fontFamily: widget.fontFamily,
                            fontSize: 22,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── محتوى الآيات — فواصل + نصوص منسابة بدون قيود Expanded ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    // حساب ارتفاع المحتوى الفعلي
                    final contentHeight = _estimateContentHeight(
                      segments: segments,
                      fontSize: fontSize,
                      lineHeight: lineHeight,
                      fontFamily: widget.fontFamily,
                      textAreaW: textAreaW,
                    );
                    final fitsNaturally = contentHeight <= verseAreaH + 10;

                    final content = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int s = 0; s < segments.length; s++) ...[
                          if (s > 0)
                            _SurahSeparator(
                              surahName: widget.surahNames?[segments[s].chapter] ?? '',
                              showBismillah: segments[s].chapter != 1 && segments[s].chapter != 9,
                              fontFamily: widget.fontFamily,
                              fontSize: fontSize,
                              theme: theme,
                            ),
                          _SegmentText(
                            verses: segments[s].verses,
                            fontSize: fontSize,
                            lineHeight: lineHeight,
                            fontFamily: widget.fontFamily,
                            theme: theme,
                            bookmarkService: widget.bookmarkService,
                            onVerseTap: widget.onVerseTap,
                            recognizers: _recognizers,
                          ),
                        ],
                      ],
                    );

                    // إذا النص يتناسب مع المساحة — لا نسمح بالتمرير
                    if (fitsNaturally) {
                      return Center(child: content);
                    }
                    // وإلا — نسمح بتمرير كشبكة أمان
                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: content,
                    );
                  },
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

  static double _findOptimalFontSize({
    required String text,
    required String fontFamily,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) return 18.0;
    double low = 12.0;
    double high = 36.0;
    double bestSize = 14.0;

    for (int i = 0; i < 25; i++) {
      final mid = (low + high) / 2;
      final lh = mid < 20 ? 1.6 : mid < 26 ? 1.7 : 1.8;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: mid,
            height: lh,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: null,
      );
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight) {
        bestSize = mid;
        low = mid + 0.25;
      } else {
        high = mid - 0.25;
      }
      painter.dispose();
    }

    return bestSize;
  }

  /// تقدير ارتفاع المحتوى الكلي (فواصل + نصوص) بحجم خط معين.
  double _estimateContentHeight({
    required List<_VerseSegment> segments,
    required double fontSize,
    required double lineHeight,
    required String fontFamily,
    required double textAreaW,
  }) {
    final buffer = StringBuffer();
    for (final segment in segments) {
      for (final v in segment.verses) {
        buffer.write('${v.text} ﴿${toArabicDigits(v.number)}﴾  ');
      }
    }
    final fullText = buffer.toString();

    final painter = TextPainter(
      text: TextSpan(
        text: fullText,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: lineHeight,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: null,
    );
    painter.layout(maxWidth: textAreaW);
    final textH = painter.height;
    painter.dispose();

    final separatorCount = segments.length > 1 ? segments.length - 1 : 0;
    final separatorH = separatorCount * 68.0;

    return textH + separatorH;
  }
}

/// فاصل بين السور — خط ذهبي + اسم السورة + بسملة
class _SurahSeparator extends StatelessWidget {
  const _SurahSeparator({
    required this.surahName,
    required this.showBismillah,
    required this.fontFamily,
    required this.fontSize,
    required this.theme,
  });

  final String surahName;
  final bool showBismillah;
  final String fontFamily;
  final double fontSize;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // خط فاصل
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
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
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A843).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories,
                  size: fontSize * 0.6,
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
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
          // اسم السورة
          Text(
            surahName,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize * 0.8,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textDirection: TextDirection.rtl,
          ),
          if (showBismillah) ...[
            const SizedBox(height: 1),
            Text(
              'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: fontSize * 0.65,
                color: theme.colorScheme.primary.withAlpha(180),
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ],
      ),
    );
  }
}

/// نص آيات السورة — فقرة واحدة منسابة (طراز المصحف).
/// كل آية تفاعلية عبر TapGestureRecognizer.
class _SegmentText extends StatelessWidget {
  const _SegmentText({
    required this.verses,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.theme,
    required this.bookmarkService,
    required this.onVerseTap,
    required this.recognizers,
  });

  final List<Verse> verses;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final ThemeData theme;
  final BookmarkService bookmarkService;
  final void Function(Verse) onVerseTap;
  final List<TapGestureRecognizer> recognizers;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: _buildSpans(),
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: lineHeight,
          color: theme.colorScheme.onSurface,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];

    for (final verse in verses) {
      final recognizer = TapGestureRecognizer()
        ..onTap = () => onVerseTap(verse);
      recognizers.add(recognizer);

      // نص الآية
      spans.add(TextSpan(
        text: verse.text,
        recognizer: recognizer,
      ));

      // رقم الآية
      final isBookmarked = bookmarkService.isBookmarked(verse.key);
      spans.add(TextSpan(
        text: ' ﴿${toArabicDigits(verse.number)}﴾ ',
        style: TextStyle(
          fontSize: fontSize * 0.8,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        recognizer: recognizer,
      ));

      if (isBookmarked) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.bookmark,
            size: fontSize * 0.45,
            color: theme.colorScheme.primary,
          ),
        ));
      }
    }

    return spans;
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
