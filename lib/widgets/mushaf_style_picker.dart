import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// نافذة اختيار نمط المصحف (مدني / تجويد ملون).
/// تُرجع النمط المختار أو null عند الإلغاء.
Future<MushafStyle?> showMushafStylePicker(
  BuildContext context,
  SettingsService settings,
) {
  return showDialog<MushafStyle>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('نمط المصحف'),
      children: [
        for (final s in MushafStyle.values)
          ListTile(
            leading: Icon(
              s == MushafStyle.tajweed
                  ? Icons.palette_outlined
                  : Icons.menu_book_outlined,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            title: Text(s.label),
            subtitle: Text(
              s == MushafStyle.tajweed
                  ? 'ملوّن بأحكام التجويد'
                  : 'الرسم العثماني الرسمي',
            ),
            trailing: s == settings.style
                ? Icon(Icons.check_circle,
                    color: Theme.of(ctx).colorScheme.primary)
                : const Icon(Icons.circle_outlined),
            onTap: () => Navigator.of(ctx).pop(s),
          ),
      ],
    ),
  );
}