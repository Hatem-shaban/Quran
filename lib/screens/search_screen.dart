import 'dart:async';

import 'package:flutter/material.dart';

import '../models/surah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../utils/arabic_digits.dart';
import '../utils/page_transitions.dart';
import '../widgets/error_fallback.dart';
import 'reader_screen.dart';

/// شاشة البحث في جميع آيات القرآن (تجاهل التشكيل).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.quranService,
    required this.bookmarkService,
  });

  final QuranService quranService;
  final BookmarkService bookmarkService;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Verse> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _results = widget.quranService.search(query);
        _searched = query.trim().isNotEmpty;
      });
    });
  }

  void _openVerse(Verse verse) {
    Navigator.of(context).push(SlideRoute(
      page: ReaderScreen(
        quranService: widget.quranService,
        bookmarkService: widget.bookmarkService,
        surah: widget.quranService.surahOf(verse.chapter),
        initialVerse: verse.number - 1,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: SafeChild(
        builder: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث في القرآن الكريم…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (_searched)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'عدد النتائج: ${toArabicDigits(_results.length)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(
              child: !_searched
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 64,
                              color: Theme.of(context).colorScheme.outline.withAlpha(60)),
                          const SizedBox(height: 16),
                          Text('اكتب كلمة للبحث في الآيات',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 16,
                            )),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 64,
                                  color: Theme.of(context).colorScheme.outline.withAlpha(60)),
                              const SizedBox(height: 16),
                              Text('لا توجد نتائج مطابقة',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 16,
                                )),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final verse = _results[index];
                            final surah =
                                widget.quranService.surahOf(verse.chapter);
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      toArabicDigits(verse.number),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  'سورة ${surah.name}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  verse.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                onTap: () => _openVerse(verse),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
