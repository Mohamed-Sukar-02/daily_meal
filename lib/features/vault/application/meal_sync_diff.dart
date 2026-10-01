import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../data/cloud_vocabulary.dart';
import '../data/models/cloud_meal.dart';
import '../providers/discovery_providers.dart';

/// One field whose cloud copy disagrees with the local row.
class MealCloudDiff {
  /// Localised field name, e.g. "نوع البروتين".
  final String field;
  final String localValue;
  final String cloudValue;

  const MealCloudDiff({
    required this.field,
    required this.localValue,
    required this.cloudValue,
  });
}

/// The fields "Update from cloud" would overwrite, in reading order.
///
/// The photo is deliberately absent: a downloaded meal stores a localised file
/// path, which can never string-match the cloud `imageUrl`, so comparing them
/// would flag every downloaded meal as changed.
List<MealCloudDiff> mealCloudDiffs(
  Meal local,
  CloudMeal cloud,
  AppStrings strings,
) {
  final diffs = <MealCloudDiff>[];

  void compare(String field, String localValue, String cloudValue) {
    if (localValue != cloudValue) {
      diffs.add(
        MealCloudDiff(
          field: field,
          localValue: localValue,
          cloudValue: cloudValue,
        ),
      );
    }
  }

  /// A tag axis counts as changed only when the cloud token actually differs from
  /// the local value's token *and* the two read differently. Comparing the labels
  /// alone was the bug: the cloud folds `dairy` and `none` into `other`, and
  /// `potato`/`grains` into `none`, so every meal carrying one of those values
  /// disagreed with its own cloud copy forever — the sync mark stayed orange, and
  /// "update from cloud" answered by overwriting a tag nobody had touched.
  /// `isProposableAgainstCloud` is built on this list, so the same fold also kept
  /// re-offering those meals for staging and spending the daily quota.
  void compareTag(
    String field, {
    required bool agreesInCloud,
    required String localValue,
    required String cloudValue,
  }) {
    if (agreesInCloud || localValue == cloudValue) return;
    diffs.add(
      MealCloudDiff(
        field: field,
        localValue: localValue,
        cloudValue: cloudValue,
      ),
    );
  }

  compare(strings.mealNameLabel, local.name.trim(), cloud.name.trim());
  compare(
    strings.shortNameLabel,
    (local.shortName ?? '').trim(),
    (cloud.shortName ?? '').trim(),
  );
  compareTag(
    strings.proteinTypeLabel,
    agreesInCloud: MealCloudVocabulary.sameCloudProtein(
        local.proteinType, cloud.proteinType),
    localValue: local.proteinType.label(strings),
    cloudValue: cloudProteinType(cloud.proteinType).label(strings),
  );
  compareTag(
    strings.carbsTypeLabel,
    agreesInCloud:
        MealCloudVocabulary.sameCloudCarbs(local.carbsType, cloud.carbsType),
    localValue: local.carbsType.label(strings),
    cloudValue: cloudCarbsType(cloud.carbsType).label(strings),
  );
  compareTag(
    strings.categoryShortLabel,
    agreesInCloud: MealCloudVocabulary.sameCloudCategory(
        local.category, cloud.category),
    localValue: local.category.label(strings),
    cloudValue: cloudCategory(cloud.category).label(strings),
  );
  compare(
    strings.timeLabel,
    strings.prepMinutesShort(local.prepTime),
    strings.prepMinutesShort(cloud.prepTimeMinutes),
  );
  compare(
    strings.fridaySpecial,
    _flag(local.isFridaySpecial, strings),
    _flag(cloud.isFridaySpecial, strings),
  );
  compare(strings.notesLabel, (local.notes ?? '').trim(), (cloud.notes ?? '').trim());

  return diffs;
}

String _flag(bool on, AppStrings strings) =>
    on ? strings.flagYes : strings.flagNo;
