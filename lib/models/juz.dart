/// بيانات الجزء (Juz) — 30 جزء في القرآن الكريم.
class Juz {
  final int number;
  final String name;
  final int startSurah;
  final int startVerse;
  final int endSurah;
  final int endVerse;

  const Juz({
    required this.number,
    required this.name,
    required this.startSurah,
    required this.startVerse,
    required this.endSurah,
    required this.endVerse,
  });

  /// قائمة الأجزاء الثلاثين مع بداية كل جزء.
  static const List<Juz> all = [
    Juz(number: 1, name: 'الجزء ١', startSurah: 1, startVerse: 1, endSurah: 2, endVerse: 141),
    Juz(number: 2, name: 'الجزء ٢', startSurah: 2, startVerse: 142, endSurah: 2, endVerse: 252),
    Juz(number: 3, name: 'الجزء ٣', startSurah: 2, startVerse: 253, endSurah: 3, endVerse: 92),
    Juz(number: 4, name: 'الجزء ٤', startSurah: 3, startVerse: 93, endSurah: 4, endVerse: 23),
    Juz(number: 5, name: 'الجزء ٥', startSurah: 4, startVerse: 24, endSurah: 4, endVerse: 147),
    Juz(number: 6, name: 'الجزء ٦', startSurah: 4, startVerse: 148, endSurah: 5, endVerse: 81),
    Juz(number: 7, name: 'الجزء ٧', startSurah: 5, startVerse: 82, endSurah: 6, endVerse: 110),
    Juz(number: 8, name: 'الجزء ٨', startSurah: 6, startVerse: 111, endSurah: 7, endVerse: 87),
    Juz(number: 9, name: 'الجزء ٩', startSurah: 7, startVerse: 88, endSurah: 8, endVerse: 40),
    Juz(number: 10, name: 'الجزء ١٠', startSurah: 8, startVerse: 41, endSurah: 9, endVerse: 92),
    Juz(number: 11, name: 'الجزء ١١', startSurah: 9, startVerse: 93, endSurah: 11, endVerse: 5),
    Juz(number: 12, name: 'الجزء ١٢', startSurah: 11, startVerse: 6, endSurah: 12, endVerse: 52),
    Juz(number: 13, name: 'الجزء ١٣', startSurah: 12, startVerse: 53, endSurah: 14, endVerse: 52),
    Juz(number: 14, name: 'الجزء ١٤', startSurah: 15, startVerse: 1, endSurah: 16, endVerse: 128),
    Juz(number: 15, name: 'الجزء ١٥', startSurah: 17, startVerse: 1, endSurah: 18, endVerse: 74),
    Juz(number: 16, name: 'الجزء ١٦', startSurah: 18, startVerse: 75, endSurah: 20, endVerse: 135),
    Juz(number: 17, name: 'الجزء ١٧', startSurah: 21, startVerse: 1, endSurah: 22, endVerse: 78),
    Juz(number: 18, name: 'الجزء ١٨', startSurah: 23, startVerse: 1, endSurah: 25, endVerse: 20),
    Juz(number: 19, name: 'الجزء ١٩', startSurah: 25, startVerse: 21, endSurah: 27, endVerse: 55),
    Juz(number: 20, name: 'الجزء ٢٠', startSurah: 27, startVerse: 56, endSurah: 29, endVerse: 45),
    Juz(number: 21, name: 'الجزء ٢١', startSurah: 29, startVerse: 46, endSurah: 33, endVerse: 30),
    Juz(number: 22, name: 'الجزء ٢٢', startSurah: 33, startVerse: 31, endSurah: 36, endVerse: 27),
    Juz(number: 23, name: 'الجزء ٢٣', startSurah: 36, startVerse: 28, endSurah: 39, endVerse: 31),
    Juz(number: 24, name: 'الجزء ٢٤', startSurah: 39, startVerse: 32, endSurah: 41, endVerse: 46),
    Juz(number: 25, name: 'الجزء ٢٥', startSurah: 41, startVerse: 47, endSurah: 45, endVerse: 37),
    Juz(number: 26, name: 'الجزء ٢٦', startSurah: 46, startVerse: 1, endSurah: 51, endVerse: 30),
    Juz(number: 27, name: 'الجزء ٢٧', startSurah: 51, startVerse: 31, endSurah: 57, endVerse: 29),
    Juz(number: 28, name: 'الجزء ٢٨', startSurah: 58, startVerse: 1, endSurah: 66, endVerse: 12),
    Juz(number: 29, name: 'الجزء ٢٩', startSurah: 67, startVerse: 1, endSurah: 77, endVerse: 50),
    Juz(number: 30, name: 'الجزء ٣٠', startSurah: 78, startVerse: 1, endSurah: 114, endVerse: 6),
  ];

  /// إيجاد الجزء الذي تنتمي إليه آية معينة.
  static Juz of(int surah, int verse) {
    for (final juz in all) {
      final afterStart = surah > juz.startSurah ||
          (surah == juz.startSurah && verse >= juz.startVerse);
      final beforeEnd = surah < juz.endSurah ||
          (surah == juz.endSurah && verse <= juz.endVerse);
      if (afterStart && beforeEnd) return juz;
    }
    return all.last;
  }
}
