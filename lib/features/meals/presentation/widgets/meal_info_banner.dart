import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import 'meal_screen_palette.dart';

/// The green info card that sits directly above the dish strip — two text
/// columns split by a single vertical hairline.
///
/// Height is FIXED ([MealInfoBanner.height]) so the parent can tuck the dish
/// strip up over its bottom edge ([MealDishTabs.overlap]) with deterministic
/// seam geometry; the content is ellipsized to stay clear of that zone. The
/// square bottom corners are intentionally covered by the strip, which is how
/// card and tab bar fuse into one shape.
class MealInfoBanner extends StatelessWidget {
  static const double height = 96;

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

    return Container(
      key: const Key('meal_screen_info_card'),
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MealScreenPalette.cardTop(brightness),
            MealScreenPalette.cardBottom(brightness),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: MealScreenPalette.cardStroke(brightness)),
          left: BorderSide(color: MealScreenPalette.cardStroke(brightness)),
          right: BorderSide(color: MealScreenPalette.cardStroke(brightness)),
        ),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.60)
                : const Color(0xFF14301F).withValues(alpha: 0.35),
            blurRadius: brightness == Brightness.dark ? 24 : 20,
            spreadRadius: -12,
            offset: Offset(0, brightness == Brightness.dark ? -8 : -6),
          ),
        ],
      ),
      child: Padding(
        // Bottom padding clears the 18pt the dish strip tucks up over us.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Column(
                  brightness: brightness,
                  title: short,
                  subtitle: _ingredients(meal, strings),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Container(
                  width: 1,
                  color: MealScreenPalette.cardDivider(brightness),
                ),
              ),
              Expanded(
                child: _Column(
                  brightness: brightness,
                  title: strings.freshAndNatural,
                  subtitle: _tags(meal, strings),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ingredients(Meal meal, AppStrings strings) {
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

  static String _tags(Meal meal, AppStrings strings) {
    final parts = <String>[strings.healthyTag];
    parts.add(
      meal.isBudgetFriendly ? strings.balancedTag : strings.deliciousTag,
    );
    if (meal.isFridaySpecial) {
      parts.add(strings.fridaySpecial);
    }
    return parts.join(', ');
  }
}

class _Column extends StatelessWidget {
  final Brightness brightness;
  final String title;
  final String subtitle;

  const _Column({
    required this.brightness,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: MealScreenPalette.cardText(brightness),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
            color: MealScreenPalette.cardSub(brightness),
          ),
        ),
      ],
    );
  }
}
