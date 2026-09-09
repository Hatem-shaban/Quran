import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/juz.dart';
import '../models/surah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../services/settings_service.dart';
import '../services/ui_controller.dart';
import '../utils/arabic_digits.dart';
import '../widgets/mushaf_style_picker.dart';

/// لون ورق المصحف المحيط بصفحة المصحف المطبوعة.
const _parchment = Color(0xFFFFF8F0);

/// مصنع موحّد لفتح شاشة القراءة من جميع الشاشات (الرئيسية/البحث/العلامات).
ReaderScreen buildReaderScreen({
  required QuranService quranService,
  required BookmarkService bookmarkService,
  SettingsService? settingsService,
  required UiController uiController,
  required int chapter,
  int initialVerse = 1,
}) {
  return ReaderScreen(
    quranService: quranService,
    bookmarkService: bookmarkService,
    settingsService: settingsService,
    uiController: uiController,
    surah: quranService.surahOf(chapter),
    initialVerse: initialVerse,
  );
}

/// شاشة القراءة — صفحات المصحف المطبوع (مجمع الملك فهد) كصور رسمية،
/// كل صفحة معروضة كاملة دون قص ودون تمرير.
///
/// الأداء: خريطة الصفحات وبيانات التخطيط تُقرأ من [QuranService] المخزنة
/// مسبقًا (بلا تحليل JSON أو مسح O(n) عند كل فتح)، وفك صور الصفحات
/// مرتبط بمفتاح ثابت (نمط+صفحة) فلا يُعاد فك الصورة عند تبديل الواجهة.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.quranService,
    required this.bookmarkService,
    this.settingsService,
    required this.uiController,
    required this.surah,
    this.initialVerse = 0,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;
  final SettingsService? settingsService;
  final UiController uiController;
  final Surah surah;
  final int initialVerse;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _saveDebounce = Duration(milliseconds: 600);

  PageController? _pageController;
  Timer? _positionSaveDebounce;

  /// بيانات تخطيط المصحف (خطوط الصفحات + حدود النص) — من الذاكرة المشتركة.
  MushafLayout? _layout;

  /// النمط الحالي — يُعاد بناء المتحكم عند تغيّره فقط.
  MushafStyle _style = MushafStyle.madani;
  bool _settingsListenerAttached = false;

  int _currentPage = 1;
  Surah _currentSurah;

  /// هل عناصر الواجهة (الشريط العلوي + الشريط السفلي) ظاهرة؟
  bool _chromeVisible = true;

  _ReaderScreenState() : _currentSurah = _placeholderSurah;

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

    var startPage = widget.quranService.pageOf(
      widget.surah.number,
      widget.initialVerse > 0 ? widget.initialVerse : 1,
    );
    startPage = startPage.clamp(1, QuranService.totalPages);
    _currentPage = startPage;
    _currentSurah = widget.quranService.surahOf(
      widget.quranService.versesOnPage(startPage).first.chapter,
    );

    // بيانات التخطيط مخزنة في الخدمة (SynchronousFuture عند أول تحميل) —
    // إن لم تكن جاهزة بعد فتصل خلال إطار دون إعادة تحليل الملفات.
    widget.quranService.layout().then((layout) {
      if (!mounted) return;
      setState(() => _layout = layout);
    });

    // حفظ موضع القراءة (الافتتاحي + عند تقليب الصفحات) بتأجيل موحّد.
    _schedulePositionSave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = widget.settingsService;
    if (settings != null && !_settingsListenerAttached) {
      settings.addListener(_onSettingsChanged);
      _settingsListenerAttached = true;
    }
    _applyStyle();
  }

  /// إنشاء/إعادة إنشاء متحكم الصفحات عند تغيّر نمط المصحف فقط —
  /// يُحافظ أثناءها على الصفحة الحالية (لا قفز إلى أول الصورة).
  void _applyStyle() {
    final style = widget.settingsService?.style ?? MushafStyle.madani;
    if (style == _style && _pageController != null) return;
    _style = style;
    _pageController?.dispose();
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(_applyStyle);
  }

  /// جدولة حفظ موضع القراءة (يُدمج الاستدعاءات المتتالية في كتابة واحدة).
  void _schedulePositionSave() {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(_saveDebounce, _savePositionNow);
  }

  void _savePositionNow() {
    final verses = widget.quranService.versesOnPage(_currentPage);
    if (verses.isEmpty) return;
    final first = verses.first;
    widget.bookmarkService.setLastRead(first.chapter, first.number);
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= QuranService.totalPages) return;
    final page = index + 1;
    final verses = widget.quranService.versesOnPage(page);
    if (verses.isEmpty) return;

    setState(() {
      _currentPage = page;
      _currentSurah = widget.quranService.surahOf(verses.first.chapter);
    });
    _schedulePositionSave();
  }

  @override
  void dispose() {
    widget.settingsService?.removeListener(_onSettingsChanged);
    _positionSaveDebounce?.cancel();
    _savePositionNow();
    _pageController?.dispose();
    // إعادة الواجهة والشريط السفلي عند مغادرة القارئ.
    widget.uiController.showChrome();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // السماح للشاشة بالخمول مرة أخرى عند مغادرة القارئ.
    WakelockPlus.disable();
    super.dispose();
  }

  /// آيات تغطي سطرًا معينًا (نطاق قد يعبر حدود السورة في بداية/نهاية الصفحة)
  /// — بحث معرفي O(1) عبر فهارس الخدمة.
  List<Verse> _versesInRange(List<int> range) {
    return widget.quranService.versesForRange(
      '${range[0]}:${range[1]}',
      '${range[2]}:${range[3]}',
    );
  }

  /// إظهار/إخفاء واجهة القراءة (الشريط العلوي + الشريط السفلي + أشرطة النظام)
  /// — وضع التركيز على صفحة المصحف.
  void _setChromeVisible(bool visible) {
    if (_chromeVisible == visible) return;
    setState(() => _chromeVisible = visible);
    widget.uiController.chromeVisible.value = visible;
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _toggleChrome() => _setChromeVisible(!_chromeVisible);

  void _onVerseLongPress(
    Offset localPosition,
    int page,
    double dispH,
    double topPad,
  ) {
    final layout = _layout;
    if (layout == null) return;
    final lineCount = layout.lineCount(page);
    if (lineCount == 0) return;
    final y = localPosition.dy - topPad;
    final lineIdx = (y / dispH * lineCount).floor().clamp(0, lineCount - 1);
    final range = layout.lineRange(page, lineIdx);
    if (range == null) return; // رأس سورة أو بسملة

    final verses = _versesInRange(range);
    if (verses.isEmpty) return;
    if (verses.length == 1) {
      _showVerseActions(verses.first);
      return;
    }
    // أكثر من آية في السطر — اختيار الآية المطلوبة.
    unawaited(_showVersePicker(verses));
  }

  Future<void> _showVersePicker(List<Verse> verses) {
    return showModalBottomSheet<void>(
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
                style: Theme.of(sheetContext).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            for (final verse in verses)
              _VerseSheetTile(
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

  Future<void> _showVerseActions(Verse verse) {
    final isBookmarked = widget.bookmarkService.isBookmarked(verse.key);
    final surah = widget.quranService.surahOf(verse.chapter);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
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
                    color: theme.colorScheme.onSurface,
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
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  color: theme.colorScheme.primary,
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
        );
      },
    );
  }

  Future<void> _showJumpToPageDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => const _JumpDialog(),
    );
    final controller = _pageController;
    if (result != null && mounted && controller != null && controller.hasClients) {
      final targetIndex = result - 1;
      if (targetIndex >= 0 && targetIndex < QuranService.totalPages) {
        controller.jumpToPage(targetIndex);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageView = LayoutBuilder(
      builder: (context, constraints) {
        // تُحسب المقاسات مرة واحدة لكل تغيير مقاس/نمط — وليس لكل صفحة.
        final layout = _layout;
        return PageView.builder(
          controller: _pageController,
          itemCount: QuranService.totalPages,
          // فك الصفحة المجاور مسبقًا لتقليب سلس بلا وميض.
          allowImplicitScrolling: true,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) => _MushafPage(
            key: ValueKey('${_style.name}_${index + 1}'),
            page: index + 1,
            style: _style,
            layout: layout,
            areaW: constraints.maxWidth,
            areaH: constraints.maxHeight,
            onTap: _toggleChrome,
            onVerseLongPress: _onVerseLongPress,
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: _parchment,
      appBar: _chromeVisible
          ? AppBar(
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
            )
          : null,
      // في وضع التركيز تمتد الصفحة تحت شريط الحالة أيضًا.
      body: _chromeVisible
          ? SafeArea(top: false, child: pageView)
          : pageView,
    );
  }

  Juz get _currentJuz {
    final first = widget.quranService.versesOnPage(_currentPage).first;
    return Juz.of(first.chapter, first.number);
  }
}

/// صفحة مصحف واحدة — عرض ذكي: يُكبَّر إلى أقصى حجم لا يُقصّ فيه أي نص
/// (حدود كتلة النص من بيانات page_extents)، مع الحفاظ على النسب الحقيقية.
class _MushafPage extends StatelessWidget {
  const _MushafPage({
    super.key,
    required this.page,
    required this.style,
    required this.layout,
    required this.areaW,
    required this.areaH,
    required this.onTap,
    required this.onVerseLongPress,
  });

  final int page;
  final MushafStyle style;
  final MushafLayout? layout;
  final double areaW;
  final double areaH;
  final VoidCallback onTap;
  final void Function(Offset localPosition, int page, double dispH, double topPad)
      onVerseLongPress;

  @override
  Widget build(BuildContext context) {
    final extents = layout?.extents[style.name]?[page];
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
      // نقرة واحدة: إظهار/إخفاء الواجهة (وضع التركيز).
      onTap: onTap,
      // ضغطة طويلة: قائمة إجراءات الآية تحت مؤشر الإصبع.
      onLongPressStart: (details) =>
          onVerseLongPress(details.localPosition, page, dispH, topPad),
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
