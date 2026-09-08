import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/juz.dart';
import '../models/surah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../services/settings_service.dart';
import '../utils/arabic_digits.dart';
import '../widgets/error_fallback.dart';
import '../widgets/mushaf_style_picker.dart';

/// لون ورق المصحف المحيط بصفحة المصحف المطبوعة.
const _parchment = Color(0xFFFFF8F0);

/// شاشة القراءة — صفحات المصحف المطبوع (مجمع الملك فهد) كصور رسمية،
/// كل صفحة معروضة كاملة دون قص ودون تمرير.
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

  /// آيات كل صفحة (١..٦٠٤) وفق ترقيم المصحف.
  late final Map<int, List<Verse>> _versesByPage;

  /// لكل صفحة: خطوطها الـ ١٥ — كل خط هو [سورة_البداية، آية_البداية، سورة_النهاية، آية_النهاية]
  /// أو null للخطوط الزخرفية (رأس سورة / بسملة).
  Map<int, List<List<int>?>> _pageLines = const {};

  /// لكل نمط وصفحة: الحدود اليسرى/اليمنى لكتلة النص (كسور من عرض الصورة) —
  /// تُستخدم لتكبير الصفحة إلى أقصى حجم لا يُقصّ فيه أي نص.
  Map<String, Map<int, ({double left, double right})>> _pageExtents = {};

  int _currentPage = 1;
  Surah _currentSurah = _placeholderSurah;
  bool _initialSaveDone = false;

  static const Surah _placeholderSurah = Surah(
    number: 1,
    name: '',
    transliteration: '',
    revelation: '',
    verseCount: 7,
  );

  @override
  void initState() {
    super.initState();
    // إبقاء الشاشة مضاءة أثناء القراءة.
    WakelockPlus.enable();
    _versesByPage = _buildPageVerses();

    var startPage = widget.quranService.pageOf(
      widget.surah.number,
      widget.initialVerse > 0 ? widget.initialVerse : 1,
    );
    startPage = startPage.clamp(1, QuranService.totalPages);
    _currentPage = startPage;

    final first = _versesByPage[startPage]!.first;
    _currentSurah = widget.quranService.surahOf(first.chapter);

    _pageController = PageController(initialPage: startPage - 1);
    _loadPageLines();
  }

  Future<void> _loadPageLines() async {
    try {
      final raw = await rootBundle.loadString('assets/data/page_lines.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final lines = <int, List<List<int>?>>{};
      for (final e in decoded.entries) {
        final page = int.parse(e.key);
        final list = (e.value as List<dynamic>)
            .map((l) => l == null
                ? null
                : (l as List<dynamic>).cast<int>())
            .toList();
        lines[page] = list;
      }
      if (mounted) {
        setState(() => _pageLines = lines);
      }
    } catch (_) {
      // بدون بيانات الخطوط تبقى الصفحات قابلة للتصفح (النقر متاح على مستوى الصفحة فقط).
    }
    try {
      final raw = await rootBundle.loadString('assets/data/page_extents.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final extents = <String, Map<int, ({double left, double right})>>{};
      for (final e in decoded.entries) {
        final pages = <int, ({double left, double right})>{};
        for (final pe in (e.value as Map<String, dynamic>).entries) {
          final arr = (pe.value as List<dynamic>).cast<num>();
          pages[int.parse(pe.key)] = (
            left: arr[0].toDouble(),
            right: arr[1].toDouble(),
          );
        }
        extents[e.key] = pages;
      }
      if (mounted) {
        setState(() => _pageExtents = extents);
      }
    } catch (_) {
      // بدون البيانات تُعرض الصفحة بعرضها الكامل.
    }
  }

  Map<int, List<Verse>> _buildPageVerses() {
    final map = <int, List<Verse>>{};
    for (final verse in widget.quranService.allVerses) {
      final page = widget.quranService.pageOf(verse.chapter, verse.number);
      (map[page] ??= []).add(verse);
    }
    return map;
  }

  Juz get _currentJuz {
    final first = _versesByPage[_currentPage]!.first;
    return Juz.of(first.chapter, first.number);
  }

  void _savePositionForPage(int page) {
    final verses = _versesByPage[page];
    if (verses == null || verses.isEmpty) return;
    final first = verses.first;
    widget.bookmarkService.setLastRead(first.chapter, first.number);
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= QuranService.totalPages) return;
    final page = index + 1;
    final verses = _versesByPage[page];
    if (verses == null || verses.isEmpty) return;

    if (mounted) {
      setState(() {
        _currentPage = page;
        _currentSurah = widget.quranService.surahOf(verses.first.chapter);
      });
    }

    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _savePositionForPage(page);
    });
  }

  void _onPageBuilt() {
    if (_initialSaveDone) return;
    _initialSaveDone = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _savePositionForPage(_currentPage);
    });
  }

  @override
  void dispose() {
    _positionSaveDebounce?.cancel();
    _savePositionForPage(_currentPage);
    _pageController.dispose();
    // السماح للشاشة بالخمول مرة أخرى عند مغادرة القارئ.
    WakelockPlus.disable();
    super.dispose();
  }

  /// آيات تغطي سطرًا معينًا (نطاق قد يعبر حدود السورة في بداية/نهاية الصفحة).
  List<Verse> _versesInRange(List<int> range) {
    final startKey = '${range[0]}:${range[1]}';
    final endKey = '${range[2]}:${range[3]}';
    final all = widget.quranService.allVerses;
    final start = all.indexWhere((v) => v.key == startKey);
    final end = all.indexWhere((v) => v.key == endKey);
    if (start < 0 || end < 0 || end < start) return const [];
    return all.sublist(start, end + 1);
  }

  Future<void> _onPageTap(
    TapUpDetails details,
    int page,
    double height, {
    double yOffset = 0,
  }) async {
    final lines = _pageLines[page];
    if (lines == null || lines.isEmpty) return;
    final lineCount = lines.length;
    final y = details.localPosition.dy - yOffset;
    final lineIdx = (y / height * lineCount).floor().clamp(0, lineCount - 1);
    final range = lines[lineIdx];
    if (range == null) return; // رأس سورة أو بسملة

    final verses = _versesInRange(range);
    if (verses.isEmpty) return;
    if (verses.length == 1) {
      _showVerseActions(verses.first);
      return;
    }
    // أكثر من آية في السطر — اختيار الآية المطلوبة.
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'اختر الآية',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            for (final verse in verses) _VerseSheetTile(
              verse: verse,
              surahName: widget.quranService.surahOf(verse.chapter).name,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showVerseActions(verse);
              },
            ),
          ],
        ),
      ),
    );
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
              title: Text(
                isBookmarked
                    ? 'إزالة من العلامات المرجعية'
                    : 'إضافة إلى العلامات المرجعية',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                widget.bookmarkService.toggleBookmark(verse.key);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ الآية'),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(
                    text:
                        '${verse.text}\n﴿${toArabicDigits(verse.number)}﴾ سورة ${surah.name}',
                  ),
                );
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
      final targetIndex = result - 1;
      if (targetIndex >= 0 &&
          targetIndex < QuranService.totalPages &&
          _pageController.hasClients) {
        _pageController.jumpToPage(targetIndex);
      }
    }
  }

  Future<void> _showStylePicker() async {
    final settings = widget.settingsService;
    if (settings == null) return;
    final picked = await showMushafStylePicker(context, settings);
    if (picked != null && mounted) {
      await settings.setStyle(picked);
    }
  }

  /// عرض الصفحات — يتفاعل مع تغيير نمط المصحف (مدني/تجويد) ويبقي على نفس الصفحة.
  Widget _buildPageView() {
    final settings = widget.settingsService;
    if (settings == null) {
      return PageView.builder(
        controller: _pageController,
        itemCount: QuranService.totalPages,
        onPageChanged: _onPageChanged,
        itemBuilder: _buildPageItem,
      );
    }
    // نفس الـ controller عبر إعادة البناء — يحافظ PageView على موقعه تلقائيًا،
    // فلا نقفز للصفحة الأولى عند تغيير النمط.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PageView.builder(
        controller: _pageController,
        itemCount: QuranService.totalPages,
        onPageChanged: _onPageChanged,
        itemBuilder: _buildPageItem,
      ),
    );
  }

  /// صفحة المصحف: تكبير الصورة إلى أقصى حجم لا يُقصّ فيه أي نص —
  /// تُقاس حدود كتلة النص لكل صفحة (page_extents.json) ويُضبط التكبير
  /// ليملأ الارتفاع ما أمكن، مع قص الهوامش البيضاء الجانبية فقط.
  Widget _buildPageItem(BuildContext context, int index) {
    final page = index + 1;
    final style = widget.settingsService?.style ?? MushafStyle.madani;
    final extents = _pageExtents[style.name]?[page];
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;
        final left = extents?.left ?? 0.03;
        final right = extents?.right ?? 0.03;
        // نص كامل: كتلة النص تشغل (1 - left - right) من عرض الصورة.
        // لا نسمح بقص أكثر من ٦٪ من كل جانب حتى مع بيانات غير دقيقة.
        final usable = (1 - left - right).clamp(0.88, 1.0);
        final scaleH = areaH / style.imgH;
        // هامش أمان ٢٪: قياس حدود النص تقريبي، وقد تُقصّ حروف متطاولة
        // عند الحافة إذا مُلئ العرض بالكامل.
        final scaleW = (areaW * 0.98) / (style.imgW * usable);
        final scale = scaleW < scaleH ? scaleW : scaleH;
        final dispW = style.imgW * scale;
        final dispH = style.imgH * scale;
        // نوسّط كتلة النص (وليس الصورة كاملة) أفقيًا حتى لا يُقصّ نص
        // عند حافة أضيق من الأخرى.
        final shift = (areaW - dispW) / 2 + dispW * (right - left) / 2;
        final topPad = (areaH - dispH) / 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) =>
              _onPageTap(details, page, dispH, yOffset: topPad),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: shift,
                top: topPad,
                child: Image.asset(
                  style.pageAsset(page),
                  width: dispW,
                  height: dispH,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _parchment,
      appBar: AppBar(
        title: Text(_currentSurah.name),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showStylePicker,
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'نمط المصحف',
          ),
          IconButton(
            onPressed: _showJumpToPageDialog,
            icon: const Icon(Icons.book),
            tooltip: 'انتقل إلى صفحة',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${_currentJuz.name} · صفحة ${toArabicDigits(_currentPage)}',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onPrimary.withAlpha(220),
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
      body: SafeChild(
        builder: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onPageBuilt());
          return SafeArea(
            top: false,
            child: _buildPageView(),
          );
        },
      ),
    );
  }
}

class _VerseSheetTile extends StatelessWidget {
  const _VerseSheetTile({
    required this.verse,
    required this.surahName,
    required this.onTap,
  });

  final Verse verse;
  final String surahName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(
        toArabicDigits(verse.number),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      title: Text(
        verse.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 15),
      ),
      subtitle: Text(
        'سورة $surahName',
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// نافذة الانتقال إلى صفحة محددة (١-٦٠٤).
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
