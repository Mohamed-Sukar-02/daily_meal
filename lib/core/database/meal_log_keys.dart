/// Stable keys that live in `MealHistory.mealName` when a log row has no meal
/// to name.
///
/// A history row is a snapshot: it survives the meal it points at being renamed
/// or deleted, which is why `mealName` exists at all. That also makes it the
/// wrong place for display copy — text stored there is frozen in the language
/// the app happened to be in at the time, and it can never be re-translated.
/// So a row that is not about a real dish stores one of these keys, and
/// `AppStrings.historyEntryDisplayName` turns it into the current language at
/// render time.
///
/// `takeout` and `skipped` are the long-standing members of the set;
/// `leftover` is the same treatment for a leftovers log, which used to bake a
/// localised prefix into the name (`'(بقايا امبارح) كشري'`). Legacy rows that
/// still hold that prefix are normalised on read.
class MealLogKeys {
  const MealLogKeys._();

  /// Ate out — nothing from the vault was cooked.
  static const String takeout = 'takeout';

  /// No meal happened today.
  static const String skipped = 'skipped';

  /// Reheat with no known source dish (the vault has nothing recent to point at).
  static const String leftover = 'leftover';

  /// Arabic/English leftovers labels that older builds wrote into `mealName`.
  /// Migration copy, not UI copy: it must stay put even when the app language
  /// changes, which is exactly the mistake that produced it.
  static const List<String> legacyLeftoverPrefixes = [
    '(بقايا امبارح)',
    'بقايا امبارح',
    '(Leftovers)',
    'Leftovers',
  ];

  /// `mealName` with a baked-in leftovers label removed, trimmed.
  ///
  /// Returns the empty string when the whole value *was* the label (the
  /// "no source dish" case), so callers can fall back to the plain
  /// "بواقي أكل / Leftover" wording.
  static String stripLegacyLeftoverLabel(String mealName) {
    var value = mealName.trim();
    for (final prefix in legacyLeftoverPrefixes) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
        break;
      }
      if (value.endsWith(prefix)) {
        value = value.substring(0, value.length - prefix.length).trim();
        break;
      }
    }
    return value;
  }
}
