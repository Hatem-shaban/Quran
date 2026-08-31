import 'package:flutter/material.dart';

import '../models/juz.dart';
import '../models/surah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../services/settings_service.dart';
import '../utils/arabic_digits.dart';
import 'reader_screen.dart';

/// الشاشة الرئيسية: قائمة السور والأجزاء مع متابعة القراءة الأخيرة.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.quranService,
    required this.bookmarkService,
    required this.settingsService,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;
  final SettingsService settingsService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSurah(BuildContext context, Surah surah, [int verseIndex = 0]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(
        quranService: widget.quranService,
        bookmarkService: widget.bookmarkService,
        settingsService: widget.settingsService,
        surah: surah,
        initialVerse: verseIndex,
      ),
    ));
  }

  void _openJuz(BuildContext context, Juz juz) {
    final surah = widget.quranService.surahOf(juz.startSurah);
    _openSurah(context, surah, juz.startVerse - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastRead = widget.bookmarkService.lastRead;

    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: widget.settingsService,
            builder: (context, _) {
              return PopupMenuButton<QuranFont>(
                icon: Icon(
                  Icons.font_download_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                tooltip: 'تغيير الخط',
                onSelected: (font) => widget.settingsService.setFont(font),
                itemBuilder: (context) => [
                  for (final font in QuranFont.values)
                    PopupMenuItem(
                      value: font,
                      child: Row(
                        children: [
                          if (font == widget.settingsService.font)
                            Icon(Icons.check,
                                size: 18, color: theme.colorScheme.primary)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(
                            font.displayName,
                            style: TextStyle(
                              fontFamily: font.familyName,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'السور', icon: Icon(Icons.menu_book)),
            Tab(text: 'الأجزاء', icon: Icon(Icons.view_list)),
          ],
        ),
      ),
      body: Column(
        children: [
          // بطاقة متابعة القراءة
          if (lastRead != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.auto_stories,
                      color: theme.colorScheme.primary),
                  title: const Text('متابعة القراءة'),
                  subtitle: Text(
                      '${widget.quranService.surahOf(lastRead.surah).name} — الآية ${toArabicDigits(lastRead.verse)}'),
                  onTap: () => _openSurah(
                      context, widget.quranService.surahOf(lastRead.surah),
                      lastRead.verse - 1),
                ),
              ),
            ),
          ],
          // محتوى التبويب
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // تبويب السور
                _buildSurahList(context, theme, lastRead),
                // تبويب الأجزاء
                _buildJuzList(context, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahList(
      BuildContext context, ThemeData theme, dynamic lastRead) {
    return ListView.builder(
      itemCount: widget.quranService.surahs.length,
      itemBuilder: (context, index) {
        final surah = widget.quranService.surahs[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              toArabicDigits(surah.number),
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
          title: Text(surah.name),
          subtitle: Text(
              '${surah.revelation} · ${toArabicDigits(surah.verseCount)} آية'),
          trailing:
              Icon(Icons.chevron_left, color: theme.colorScheme.outline),
          onTap: () => _openSurah(context, surah),
        );
      },
    );
  }

  Widget _buildJuzList(BuildContext context, ThemeData theme) {
    return ListView.builder(
      itemCount: Juz.all.length,
      itemBuilder: (context, index) {
        final juz = Juz.all[index];
        final startSurah = widget.quranService.surahOf(juz.startSurah);
        final endSurah = widget.quranService.surahOf(juz.endSurah);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            child: Text(
              toArabicDigits(juz.number),
              style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
          title: Text(juz.name),
          subtitle: Text(
            '${startSurah.name} ${toArabicDigits(juz.startVerse)} — ${endSurah.name} ${toArabicDigits(juz.endVerse)}',
            textDirection: TextDirection.rtl,
          ),
          trailing:
              Icon(Icons.chevron_left, color: theme.colorScheme.outline),
          onTap: () => _openJuz(context, juz),
        );
      },
    );
  }
}
