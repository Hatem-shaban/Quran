import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// نافذة اختيار نمط المصحف (مدني / تجويد / طبعات مجمع الملك فهد).
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
              switch (s) {
                MushafStyle.tajweed => Icons.palette_outlined,
                MushafStyle.madani => Icons.menu_book_outlined,
                _ => Icons.auto_stories_outlined,
              },
              color: Theme.of(ctx).colorScheme.primary,
            ),
            title: Text(s.label),
            subtitle: Text(s.description),
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