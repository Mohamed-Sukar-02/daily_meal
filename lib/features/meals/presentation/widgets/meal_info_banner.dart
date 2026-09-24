import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import 'meal_screen_palette.dart';

/// The dark-green info card that directly precedes the dish tabs —
/// mockup-exact: two text columns with a divider, nothing else.
///
/// Height is FIXED ([MealInfoBanner.height]) so the parent's interlock
/// painter can fuse the tab strip into the card's bottom edge with exact
/// seam geometry, and the content (ellipsized, two lines max) is designed
/// to stay comfortably above that seam. White-ish outline + LTR column
/// order, both locked to the mockups: the meal column is at the left and
/// the tag column at the right in every locale.
class MealInfoBanner extends StatelessWidget {
  static const double height = 86;

  final Meal meal;
  final Brightness brightness;

  const MealInfoBanner({
    super.key,
    required this.meal,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final short = (meal.shortName?.trim().isNotEmpty == true)
        ? meal.shortName!.trim()
        : meal.name;

    final leftSubtitle = _leftSubtitle(meal, strings);
    final rightTags = _rightTags(meal, strings);

    return Container(
      key: const Key('meal_screen_info_card'),
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MealScreenPalette.infoCard(brightness),
            MealScreenPalette.infoCardDeep(brightness),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: MealScreenPalette.interlockStroke(brightness),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
        child: IntrinsicHeight(
          // Mockup truth: meal-name column at the LEFT, tag column at
          // the RIGHT, in every locale (mirrors `MealDishTabs`).
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left column ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        short,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: MealScreenPalette.infoOnGreen(brightness),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leftSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color:
                              MealScreenPalette.infoOnGreenMuted(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Divider ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                // ── Right column ───────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.freshAndNatural,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: MealScreenPalette.infoOnGreen(brightness),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rightTags,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color:
                              MealScreenPalette.infoOnGreenMuted(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _leftSubtitle(Meal meal, AppStrings strings) {
    final parts = <String>[];
    if (meal.proteinType != ProteinType.none) {
      parts.add(meal.proteinType.label(strings));
    }
    if (meal.carbsType != CarbsType.none) {
      parts.add(meal.carbsType.label(strings));
    }
    if (parts.isEmpty) {
      parts.add(meal.category.label(strings));
    }
    return parts.join(', ');
  }

  static String _rightTags(Meal meal, AppStrings strings) {
    final parts = <String>[strings.healthyTag];
    if (meal.isBudgetFriendly) {
      parts.add(strings.balancedTag);
    } else {
      parts.add(strings.deliciousTag);
    }
    if (meal.isFridaySpecial) {
      parts.add(strings.fridaySpecial);
    }
    return parts.join(', ');
  }
}
