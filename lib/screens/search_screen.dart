import 'dart:async';

import 'package:flutter/material.dart';

import '../models/surah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_service.dart';
import '../utils/arabic_digits.dart';
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(
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
                  ? const Center(child: Text('اكتب كلمة للبحث في الآيات'))
                  : _results.isEmpty
                      ? const Center(child: Text('لا توجد نتائج مطابقة'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final verse = _results[index];
                            final surah =
                                widget.quranService.surahOf(verse.chapter);
                            return ListTile(
                              title: Text(
                                '${surah.name} · الآية ${toArabicDigits(verse.number)}',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                verse.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _openVerse(verse),
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
