/// تحويل الأرقام اللاتينية إلى أرقام عربية مشرقية (٠١٢٣...).
String toArabicDigits(int number) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return number.toString().split('').map((d) => digits[int.parse(d)]).join();
}

/// تحويل الأرقام العربية المشرقية واللاتينية إلى عدد صحيح.
int? parseArabicDigits(String input) {
  final clean = input.trim().replaceAllMapped(
    RegExp(r'[٠-٩]'),
    (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString(),
  );
  return int.tryParse(clean);
}

