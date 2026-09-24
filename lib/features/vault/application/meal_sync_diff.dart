import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
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

  compare(strings.mealNameLabel, local.name.trim(), cloud.name.trim());
  compare(
    strings.shortNameLabel,
    (local.shortName ?? '').trim(),
    (cloud.shortName ?? '').trim(),
  );
  compare(
    strings.proteinTypeLabel,
    local.proteinType.label(strings),
    cloudProteinType(cloud.proteinType).label(strings),
  );
  compare(
    strings.carbsTypeLabel,
    local.carbsType.label(strings),
    cloudCarbsType(cloud.carbsType).label(strings),
  );
  compare(
    strings.categoryShortLabel,
    local.category.label(strings),
    cloudCategory(cloud.category).label(strings),
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
  compare(
    strings.budgetFriendly,
    _flag(local.isBudgetFriendly, strings),
    _flag(cloud.isBudgetFriendly, strings),
  );
  compare(strings.notesLabel, (local.notes ?? '').trim(), (cloud.notes ?? '').trim());

  return diffs;
}

String _flag(bool on, AppStrings strings) =>
    on ? strings.flagYes : strings.flagNo;
