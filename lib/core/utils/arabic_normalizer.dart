String normalizeArabic(String input) {
  if (input.isEmpty) return '';

  var normalized = input;

  normalized = normalized.replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '');

  normalized = normalized.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

  normalized = normalized.replaceAll('ة', 'ه');
  normalized = normalized.replaceAll('ى', 'ي');
  normalized = normalized.replaceAll('ؤ', 'و');
  normalized = normalized.replaceAll('ئ', 'ي');

  normalized = normalized
      .replaceAll('٠', '0')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9');

  normalized = normalized.trim().replaceAll(RegExp(r'\s+'), ' ');

  normalized = normalized.toLowerCase();

  return normalized;
}

String escapeLikePattern(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
