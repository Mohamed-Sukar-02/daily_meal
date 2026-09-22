import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/widgets/app_icons.dart';
import 'meal_screen_palette.dart';

/// The dark-green info card that overlaps the bottom of the hero photo.
///
/// Layout mirrors the mockup 1:1:
/// ```
/// ┌──────────────────────────┬──────────────────────────┐
/// │  Title (short / name)    │  Fresh & Natural         │
/// │  protein, carbs, …       │  healthy, balanced, …    │
/// ├──────────────────────────┴──────────────────────────┤
/// │  🌿 budget/category              ⏱ 30 min           │
/// └─────────────────────────────────────────────────────┘
/// ```
/// Top corners rounded; bottom edge is a soft wave that seats into the
/// sheet below (drawn by the parent clip / stack).
class MealInfoBanner extends StatelessWidget {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: IntrinsicHeight(
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
          // ── Bottom meta row (leaf + clock) ─────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Row(
              children: [
                AppIcon(
                  AppGlyph.wallet,
                  color: MealScreenPalette.infoOnGreen(brightness),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    meal.isBudgetFriendly
                        ? strings.budgetFriendly
                        : meal.category.label(strings),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MealScreenPalette.infoOnGreen(brightness),
                    ),
                  ),
                ),
                const Spacer(),
                AppIcon(
                  AppGlyph.clock,
                  color: MealScreenPalette.infoOnGreen(brightness),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  strings.prepMinutesShort(meal.prepTime > 0 ? meal.prepTime : 0),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MealScreenPalette.infoOnGreen(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
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
