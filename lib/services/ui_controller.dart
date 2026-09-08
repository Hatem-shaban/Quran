import 'package:flutter/foundation.dart';

/// حالة واجهة مشتركة بين الهيكل الرئيسي (الشريط السفلي) وشاشة القراءة.
///
/// عندما يتحول القارئ إلى وضع التركيز (إخفاء الشريطين العلوي والسفلي)،
/// يُحدَّث `chromeVisible` ليخفي الهيكل الرئيسي شريط التنقل السفلي أيضًا،
/// فتمتلئ الصفحة بكامل الشاشة.
class UiController {
  /// هل عناصر الواجهة (الشريط العلوي + الشريط السفلي) ظاهرة؟
  final ValueNotifier<bool> chromeVisible = ValueNotifier<bool>(true);

  /// إظهار/إخفاء عناصر الواجهة.
  void toggleChrome() => chromeVisible.value = !chromeVisible.value;

  /// إظهار عناصر الواجهة (تُستدعى عند مغادرة شاشة القراءة).
  void showChrome() => chromeVisible.value = true;

  /// تحرير الموارد.
  void dispose() => chromeVisible.dispose();
}
