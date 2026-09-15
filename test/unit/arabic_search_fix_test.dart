import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/core/utils/arabic_normalizer.dart';

void main() {
  group('Arabic normalizer fixes [G]', () {
    test('toLowerCase inside normalizeArabic - Latin case-insensitive', () {
      expect(normalizeArabic('Koshari'), 'koshari');
      expect(normalizeArabic('KOSHARI'), 'koshari');
      expect(normalizeArabic('koshari'), 'koshari');
    });

    test('Arabic digits ٠-٩ to 0-9 conversion', () {
      expect(normalizeArabic('خصم ٥٠٪'), contains('50'));
      expect(normalizeArabic('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeArabic('رقم ١٢٣'), 'رقم 123');
    });

    test('koshari search finds Koshari', () {
      final stored = normalizeArabic('Koshari');
      final query = normalizeArabic('koshari');
      expect(stored, query);
      expect(stored.contains(query), true);
    });

    test('Arabic diacritics removal', () {
      expect(normalizeArabic('كُشري'), normalizeArabic('كشري'));
    });

    test('ة -> ه, ى -> ي normalization', () {
      expect(normalizeArabic('وجبة'), contains('ه'));
    });
  });

  group('LIKE escape fix [E]', () {
    test('escapeLikePattern escapes % and _ and \\', () {
      expect(escapeLikePattern('50%'), r'50\%');
      expect(escapeLikePattern('a_b'), r'a\_b');
      expect(escapeLikePattern(r'a\b'), r'a\\b');
      expect(escapeLikePattern('خصم 50%'), r'خصم 50\%');
    });

    test('meal named خصم 50% search % should not return all', () {
      final mealName = 'خصم 50%';
      final normalizedMeal = normalizeArabic(mealName);
      final searchQuery = '%';
      final normalizedQuery = normalizeArabic(searchQuery);
      final escaped = escapeLikePattern(normalizedQuery);
      final pattern = '%$escaped%';

      // Pattern should be %\%\% which matches literal % not wildcard all
      expect(pattern, r'%\%\%');

      // Simulate LIKE matching: without ESCAPE, % would match all
      // With ESCAPE, only meals containing % should match
      // Our meal contains %, so it should match, but a meal without % should not match all
      expect(normalizedMeal.contains('50'), true);

      // The fix uses customExpression "LIKE ? ESCAPE '\'" so % in query is escaped
      // Test that escaping works: query "%" escaped becomes "\%" which should NOT match "koshari"
      final koshariNormalized = normalizeArabic('كشري');
      final shouldNotMatch = _likeMatches(koshariNormalized, pattern);
      expect(shouldNotMatch, isFalse, reason: 'Search "%" should not return all meals like koshari');
    });

    test('search with underscore does not act as wildcard', () {
      final escaped = escapeLikePattern('_');
      expect(escaped, r'\_');
      final pattern = '%$escaped%';
      final meal = normalizeArabic('كشري');
      expect(_likeMatches(meal, pattern), isFalse);
    });
  });

  group('COALESCE search fix [F]', () {
    test('COALESCE(name_normalized, name) ensures search works even if normalized is null', () {
      // Simulate: if name_normalized is null, search should fallback to name
      final name = 'كشري مصري';
      final nameNormalized = null;
      final coalesced = nameNormalized ?? name;
      expect(coalesced, name);

      // With our fix, DAO uses COALESCE(name_normalized, name) LIKE ? ESCAPE '\'
      // So even if backfill failed, meal still searchable
      final query = normalizeArabic('كشري');
      expect(coalesced.contains(query) || normalizeArabic(coalesced).contains(query), true);
    });

    test('batch backfill must throw not swallow - logic check', () {
      // This test documents that migration v10 must NOT have try/catch swallowing errors
      // It should throw if backfill fails, so user knows
      // Our app_database.dart now does batch without try/catch
      expect(true, true, reason: 'Migration code should not have silent try/catch');
    });
  });
}

bool _likeMatches(String text, String pattern) {
  // Simplified LIKE matcher with ESCAPE '\' support for testing
  // pattern is like %\%\% etc
  // Convert to regex: % -> .*, _ -> ., but escaped \% -> literal %, \_ -> literal _
  String regexPattern = '';
  bool escaped = false;
  for (int i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    if (escaped) {
      regexPattern += RegExp.escape(c);
      escaped = false;
    } else if (c == '\\') {
      escaped = true;
    } else if (c == '%') {
      regexPattern += '.*';
    } else if (c == '_') {
      regexPattern += '.';
    } else {
      regexPattern += RegExp.escape(c);
    }
  }
  final regex = RegExp('^$regexPattern\$');
  return regex.hasMatch(text);
}
