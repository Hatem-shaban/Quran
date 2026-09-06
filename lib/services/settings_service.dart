import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available fonts for Quran text rendering.
enum QuranFont {
  amiriQuran('Amiri Quran', 'Amiri Quran'),
  scheherazade('Scheherazade New', 'Scheherazade New'),
  notoNaskh('Noto Naskh Arabic', 'Noto Naskh Arabic'),
  amiri('Amiri', 'Amiri'),
  lateef('Lateef', 'Lateef'),
  cairo('Cairo', 'Cairo'),
  tajawal('Tajawal', 'Tajawal'),
  almarai('Almarai', 'Almarai');

  const QuranFont(this.displayName, this.familyName);

  /// Display name shown in the UI.
  final String displayName;

  /// Font family name used in TextStyle.
  final String familyName;
}

/// أنماط صفحات المصحف المضمّنة في التطبيق.
enum MushafStyle {
  madani(
    'المصحف المدني',
    'assets/pages',
    'png',
    1024,
    1656,
  ),
  tajweed(
    'مصحف التجويد الملون',
    'assets/tajweed',
    'jpg',
    645,
    1000,
  );

  const MushafStyle(this.label, this.folder, this.ext, this.imgW, this.imgH);

  /// الاسم المعروض للمستخدم.
  final String label;

  /// مجلد الأصول الذي يحتوي صور الصفحات.
  final String folder;

  /// امتداد ملفات الصور.
  final String ext;

  /// أبعاد صورة الصفحة المرجعية.
  final double imgW;
  final double imgH;

  /// مسار صورة صفحة معينة (١-٦٠٤).
  String pageAsset(int page) =>
      '$folder/page${page.toString().padLeft(3, '0')}.$ext';
}

/// حفظ إعدادات المستخدم (الخط المختار ونمط المصحف).
class SettingsService extends ChangeNotifier {
  static const _fontKey = 'quran_font';
  static const _mushafStyleKey = 'mushaf_style';

  SharedPreferences? _prefs;
  QuranFont _font = QuranFont.amiriQuran;
  MushafStyle _style = MushafStyle.madani;

  QuranFont get font => _font;
  String get fontFamily => _font.familyName;

  MushafStyle get style => _style;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs!.getString(_fontKey);
    if (saved != null) {
      try {
        _font = QuranFont.values.firstWhere((f) => f.name == saved);
      } catch (_) {
        _font = QuranFont.amiriQuran;
      }
    }
    final styleSaved = _prefs!.getString(_mushafStyleKey);
    if (styleSaved != null) {
      try {
        _style = MushafStyle.values.firstWhere((s) => s.name == styleSaved);
      } catch (_) {
        _style = MushafStyle.madani;
      }
    }
  }

  Future<void> setFont(QuranFont font) async {
    if (_font == font) return;
    _font = font;
    await _prefs!.setString(_fontKey, font.name);
    notifyListeners();
  }

  Future<void> setStyle(MushafStyle style) async {
    if (_style == style) return;
    _style = style;
    await _prefs!.setString(_mushafStyleKey, style.name);
    notifyListeners();
  }
}
