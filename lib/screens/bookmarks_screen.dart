import 'package:flutter/material.dart';

import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../utils/arabic_digits.dart';
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(
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
        builder: (_) => AnimatedBuilder(
          animation: bookmarkService,
          builder: (context, _) {
            final bookmarks = bookmarkService.bookmarks;
            if (bookmarks.isEmpty) {
              return const Center(
                child: Text('لا توجد علامات مرجعية بعد\nاضغط على أي آية لحفظها',
                    textAlign: TextAlign.center),
              );
            }
            return ListView.builder(
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final (chapter, verse) = bookmarks[index];
                final surah = quranService.surahOf(chapter);
                final verseText = quranService.versesOfSurah(chapter)[verse - 1].text;
                return ListTile(
                  leading:
                      Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
                  title: Text(
                    '${surah.name} · الآية ${toArabicDigits(verse)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  subtitle: Text(verseText,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'حذف العلامة',
                    onPressed: () =>
                        bookmarkService.removeBookmark('$chapter:$verse'),
                  ),
                  onTap: () => _openBookmark(context, chapter, verse),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
