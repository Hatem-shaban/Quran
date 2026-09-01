import 'package:flutter/material.dart';

import '../models/juz.dart';
import '../models/surah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../services/settings_service.dart';
import '../utils/arabic_digits.dart';
import '../utils/page_transitions.dart';
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
    Navigator.of(context).push(ScaleFadeRoute(
      page: ReaderScreen(
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
      body: CustomScrollView(
        slivers: [
          // Hero header with gradient
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E5A46), Color(0xFF1A7A5E)],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                      style: TextStyle(
                        fontFamily: 'Amiri Quran',
                        fontSize: 18,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ),
                ),
              ),
              title: const Text('القرآن الكريم'),
            ),
            actions: [
              ListenableBuilder(
                listenable: widget.settingsService,
                builder: (context, _) {
                  return PopupMenuButton<QuranFont>(
                    icon: const Icon(Icons.font_download_outlined,
                        color: Colors.white),
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
                                    size: 18, color: Theme.of(context).colorScheme.primary)
                              else
                                const SizedBox(width: 18),
                              const SizedBox(width: 8),
                              Text(
                                font.displayName,
                                style: TextStyle(fontFamily: font.familyName, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          // Tab bar pinned
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.outline,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'السور', icon: Icon(Icons.menu_book)),
                  Tab(text: 'الأجزاء', icon: Icon(Icons.view_list)),
                ],
              ),
            ),
          ),
          // Continue reading card
          if (lastRead != null)
            SliverToBoxAdapter(
              child: _ContinueReadingCard(
                surah: widget.quranService.surahOf(lastRead.surah),
                verse: lastRead.verse,
                onTap: () => _openSurah(
                    context, widget.quranService.surahOf(lastRead.surah),
                    lastRead.verse - 1),
              ),
            ),
          // Surah/Juz list content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSurahList(context, theme, lastRead),
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
    return ListView.separated(
      itemCount: widget.quranService.surahs.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final surah = widget.quranService.surahs[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                toArabicDigits(surah.number),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            surah.name,
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(
            '${surah.revelation} · ${toArabicDigits(surah.verseCount)} آية',
            style: TextStyle(
              color: theme.colorScheme.outline,
              fontSize: 13,
            ),
          ),
          trailing:
              Icon(Icons.chevron_left, color: theme.colorScheme.outline),
          onTap: () => _openSurah(context, surah),
        );
      },
    );
  }

  Widget _buildJuzList(BuildContext context, ThemeData theme) {
    return ListView.separated(
      itemCount: Juz.all.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final juz = Juz.all[index];
        final startSurah = widget.quranService.surahOf(juz.startSurah);
        final endSurah = widget.quranService.surahOf(juz.endSurah);

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                toArabicDigits(juz.number),
                style: TextStyle(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(juz.name, style: const TextStyle(fontSize: 18)),
          subtitle: Text(
            '${startSurah.name} ${toArabicDigits(juz.startVerse)} — ${endSurah.name} ${toArabicDigits(juz.endVerse)}',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: theme.colorScheme.outline,
              fontSize: 13,
            ),
          ),
          trailing:
              Icon(Icons.chevron_left, color: theme.colorScheme.outline),
          onTap: () => _openJuz(context, juz),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Decorative widgets
// ─────────────────────────────────────────────────────────────

/// بطاقة متابعة القراءة مع تدرج لوني.
class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.surah,
    required this.verse,
    required this.onTap,
  });

  final Surah surah;
  final int verse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  theme.colorScheme.primary.withAlpha(30),
                  theme.colorScheme.primary.withAlpha(10),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_stories, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'متابعة القراءة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'سورة ${surah.name} — الآية ${toArabicDigits(verse)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(180),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Delegate for pinning the TabBar inside a CustomScrollView.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
