import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// موضع القراءة الأخير (سورة + آية).
class ReadingPosition {
  final int surah;
  final int verse;

  const ReadingPosition({required this.surah, required this.verse});

  factory ReadingPosition.fromJson(Map<String, dynamic> json) =>
      ReadingPosition(surah: json['s']! as int, verse: json['v']! as int);

  Map<String, dynamic> toJson() => {'s': surah, 'v': verse};
}

/// خدمة حفظ العلامات المرجعية وموضع القراءة الأخير باستخدام shared_preferences.
class BookmarkService extends ChangeNotifier {
  static const _bookmarksKey = 'bookmarks';
  static const _lastReadKey = 'last_read';

  SharedPreferences? _prefs;
  Set<String> _bookmarks = {};
  ReadingPosition? _lastRead;

  /// القائمة المُحلَّلة والمُرتَّبة تُحسب مرة واحدة وتُبطل عند أي تعديل
  /// — بدل إعادة التحليل والفرز في كل إطار واجهة.
  List<(int, int)>? _parsedBookmarks;

  ReadingPosition? get lastRead => _lastRead;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _bookmarks = _prefs!.getStringList(_bookmarksKey)?.toSet() ?? {};
    final rawLastRead = _prefs!.getString(_lastReadKey);
    if (rawLastRead != null) {
      try {
        _lastRead = ReadingPosition.fromJson(
          jsonDecode(rawLastRead)! as Map<String, dynamic>,
        );
      } catch (_) {
        _lastRead = null;
      }
    }
  }

  bool isBookmarked(String key) => _bookmarks.contains(key);

  bool isBookmarkedAt(int chapter, int verse) =>
      isBookmarked('$chapter:$verse');

  Future<void> toggleBookmark(String key) async {
    if (_bookmarks.contains(key)) {
      _bookmarks.remove(key);
    } else {
      _bookmarks.add(key);
    }
    _parsedBookmarks = null;
    await _prefs!.setStringList(_bookmarksKey, _bookmarks.toList());
    notifyListeners();
  }

  /// حذف علامة مرجعية مباشرةً (من شاشة العلامات).
  Future<void> removeBookmark(String key) async {
    if (!_bookmarks.contains(key)) return;
    _bookmarks.remove(key);
    _parsedBookmarks = null;
    await _prefs!.setStringList(_bookmarksKey, _bookmarks.toList());
    notifyListeners();
  }

  /// قائمة العلامات المرجعية مفصولة إلى سورة/آية، مرتبة حسب ترتيب المصحف.
  List<(int, int)> get bookmarks {
    final cached = _parsedBookmarks;
    if (cached != null) return cached;
    final parsed = <(int, int)>[
      for (final key in _bookmarks) ?_parseKey(key),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return _parsedBookmarks = List.unmodifiable(parsed);
  }

  (int, int)? _parseKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final verse = int.tryParse(parts[1]);
    if (surah == null || verse == null) return null;
    return (surah, verse);
  }

  Future<void> setLastRead(int surah, int verse) async {
    if (_lastRead?.surah == surah && _lastRead?.verse == verse) return;
    _lastRead = ReadingPosition(surah: surah, verse: verse);
    await _prefs!.setString(_lastReadKey, jsonEncode(_lastRead!.toJson()));
    notifyListeners();
  }
}
