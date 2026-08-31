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

/// حفظ إعدادات المستخدم (مثل الخط المختار).
class SettingsService extends ChangeNotifier {
  static const _fontKey = 'quran_font';

  SharedPreferences? _prefs;
  QuranFont _font = QuranFont.amiriQuran;

  QuranFont get font => _font;
  String get fontFamily => _font.familyName;

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
  }

  Future<void> setFont(QuranFont font) async {
    if (_font == font) return;
    _font = font;
    await _prefs!.setString(_fontKey, font.name);
    notifyListeners();
  }
}
