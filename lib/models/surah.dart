/// نموذج السورة والآية.
class Surah {
  final int number;
  final String name;
  final String transliteration;
  final String revelation; // مكية أو مدنية
  final int verseCount;

  const Surah({
    required this.number,
    required this.name,
    required this.transliteration,
    required this.revelation,
    required this.verseCount,
  });

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
        number: json['number'] as int,
        name: json['name'] as String,
        transliteration: json['transliteration'] as String,
        revelation: json['revelation'] as String,
        verseCount: json['verseCount'] as int,
      );
}

class Verse {
  final int chapter;
  final int number;
  final String text;

  const Verse({
    required this.chapter,
    required this.number,
    required this.text,
  });

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
        chapter: json['chapter'] as int,
        number: json['verse'] as int,
        text: json['text'] as String,
      );

  /// مفتاح فريد للآية بالصيغة "سورة:آية"، يُستخدم للعلامات المرجعية.
  String get key => '$chapter:$number';
}
