import 'package:flutter/material.dart';

import '../models/surah.dart';
import '../utils/arabic_digits.dart';

/// عرض آية واحدة داخل صفحة القراءة.
/// النص يتدفق بشكل طبيعي مع باقي الآيات في الصفحة.
class VerseTile extends StatelessWidget {
  const VerseTile({
    super.key,
    required this.verse,
    required this.isBookmarked,
    this.onTap,
  });

  final Verse verse;
  final bool isBookmarked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          text: verse.text,
          style: TextStyle(
            fontFamily: 'Amiri Quran',
            fontSize: 24,
            height: 2.2,
            color: theme.colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: ' ﴿${toArabicDigits(verse.number)}﴾',
              style: TextStyle(
                fontSize: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      ),
    );
  }
}
