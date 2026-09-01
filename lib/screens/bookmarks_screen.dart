import 'package:flutter/material.dart';

import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../utils/arabic_digits.dart';
import '../utils/page_transitions.dart';
import '../widgets/error_fallback.dart';
import 'reader_screen.dart';

/// شاشة العلامات المرجعية المحفوظة.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({
    super.key,
    required this.quranService,
    required this.bookmarkService,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;

  void _openBookmark(BuildContext context, int chapter, int verse) {
    Navigator.of(context).push(SlideRoute(
      page: ReaderScreen(
        quranService: quranService,
        bookmarkService: bookmarkService,
        surah: quranService.surahOf(chapter),
        initialVerse: verse - 1,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العلامات المرجعية')),
      body: SafeChild(
        builder: (_) => ListenableBuilder(
          listenable: bookmarkService,
          builder: (context, _) {
            final bookmarks = bookmarkService.bookmarks;
            if (bookmarks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border, size: 64,
                        color: Theme.of(context).colorScheme.outline.withAlpha(60)),
                    const SizedBox(height: 16),
                    Text('لا توجد علامات مرجعية بعد',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.outline,
                      )),
                    const SizedBox(height: 8),
                    Text('اضغط على أي آية لحفظها',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.outline.withAlpha(150),
                      )),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final (chapter, verse) = bookmarks[index];
                final surah = quranService.surahOf(chapter);
                final verseText = quranService.versesOfSurah(chapter)[verse - 1].text;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Dismissible(
                    key: ValueKey('bookmark_$chapter:$verse'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => bookmarkService.removeBookmark('$chapter:$verse'),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(Icons.bookmark,
                              color: Theme.of(context).colorScheme.primary, size: 22),
                        ),
                      ),
                      title: Text(
                        'سورة ${surah.name} · الآية ${toArabicDigits(verse)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(verseText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16)),
                      onTap: () => _openBookmark(context, chapter, verse),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
