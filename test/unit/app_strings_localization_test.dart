import 'dart:io';

import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Locale;

/// Every display getter in `AppStrings` must answer in *both* languages.
///
/// The repo rule everyone quotes is "no display literal outside `AppStrings`";
/// this guards the other half of it, which is the half that broke: a getter can
/// sit inside the string table, be read by every widget correctly, and still
/// hardcode one language. `cookThis` — the button that commits the day — did
/// exactly that (`'Cook This'` with no `isEn` branch), so the primary CTA of
/// the app rendered in English on an Arabic screen.
///
/// The check reads the source rather than the built table because a getter with
/// one branch is *valid* Dart and no widget test would notice unless someone
/// happens to look at that button in the other language.
///
/// [localeNeutralGetters] is the honest exception list: `EN`/`AR` are the
/// language switch's own labels (they name a language, not a UI string), and
/// `user@example.com` is a sample address. Anything added here must be a value
/// that is genuinely the same in both locales.
void main() {
  const localeNeutralGetters = {
    'languageCodeEn',
    'languageCodeAr',
    'defaultUserEmail',
  };

  test('every AppStrings display getter carries both languages', () {
    final file = File('lib/core/localization/app_strings.dart');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'expects the package root as the working directory (flutter test)',
    );

    final pattern = RegExp(r'^\s*String get (\w+) *=> *(.*)$');
    final offenders = <String>[];
    for (final line in file.readAsLinesSync()) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)!;
      final body = match.group(2)!;
      if (localeNeutralGetters.contains(name)) continue;
      // Only single-line bodies can be judged here: a getter whose text starts on
      // the next line is `=> isEn` on this line by the file's own formatting.
      if (body.contains("'") && !body.contains('isEn')) offenders.add(name);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'display getters with no `isEn` branch show one language in both: '
          '${offenders.join(', ')}. Add the missing branch, or list the getter in '
          'localeNeutralGetters only if the value is identical in both locales.',
    );
  });

  test('the day-committing CTA and the profile fallback are localised', () {
    const arabic = AppStrings(Locale('ar'));
    const english = AppStrings(Locale('en'));

    expect(arabic.cookThis, isNotEmpty);
    expect(arabic.cookThis, isNot(english.cookThis));
    expect(arabic.defaultUserName, isNot(english.defaultUserName));
    // The CTA must stay short: the pill wraps it in a FittedBox next to the chef
    // hat, and a long Arabic label would scale the text down to nothing.
    expect(arabic.cookThis.length, lessThan(18));
  });
}
