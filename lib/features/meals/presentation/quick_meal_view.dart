import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/meal_image.dart';

/// Lightweight, reusable meal view — the single visual vocabulary for a
/// meal's hero photo, name and badge row (protein, carbs, prep time, budget,
/// category, Friday special).
///
/// It is the *entry point view* for meals across the app:
///  * [MealScreen] wraps it with notes and actions (edit / delete / propose).
///  * Any future list, card or dialog can embed the exact same presentation
///    via [QuickMealView.fromMeal] instead of re-rolling pills and badges.
///
/// Pure presentation: no providers, no Firebase, no display literals —
/// every string comes from [AppStrings] (repo rule).
class QuickMealView extends StatelessWidget {
  final String name;
  final String? photoPath;
  final ProteinType proteinType;
  final CarbsType carbsType;
  final MealCategory? category;
  final int? prepTimeMinutes;
  final bool isBudgetFriendly;
  final bool isFridaySpecial;

  /// Hero photo height (the details sheet uses 210; the full screen 260).
  final double photoHeight;

  /// Decode budget for the hero photo — keeps large picks out of the image
  /// cache at list/screen scale (perf rule of the app: always cacheWidth).
  final int photoCacheWidth;

  final EdgeInsetsGeometry contentPadding;

  const QuickMealView({
    super.key,
    required this.name,
    this.photoPath,
    required this.proteinType,
    required this.carbsType,
    this.category,
    this.prepTimeMinutes,
    this.isBudgetFriendly = false,
    this.isFridaySpecial = false,
    this.photoHeight = 210,
    this.photoCacheWidth = 720,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  /// Normalises a local vault [Meal] into the view.
  factory QuickMealView.fromMeal(
    Meal meal, {
    Key? key,
    double photoHeight = 210,
    int photoCacheWidth = 720,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  }) {
    return QuickMealView(
      key: key,
      name: meal.name,
      photoPath: meal.photoPath,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      category: meal.category,
      prepTimeMinutes: meal.prepTime,
      isBudgetFriendly: meal.isBudgetFriendly,
      isFridaySpecial: meal.isFridaySpecial,
      photoHeight: photoHeight,
      photoCacheWidth: photoCacheWidth,
      contentPadding: contentPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Column(
      key: const Key('quick_meal_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: photoHeight,
          child: MealImage(
            photoPath: photoPath,
            cacheWidth: photoCacheWidth,
            fallback: Container(
              color: AppPalette.tabContainer(brightness),
              child: Center(
                child: AppIcon(
                  AppGlyph.pot,
                  color: AppPalette.textSecondary(brightness),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: contentPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: AppPalette.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 12),
              buildBadges(brightness, strings),
            ],
          ),
        ),
      ],
    );
  }

  /// Badge wrap shared by every surface: protein (emoji + label), carbs,
  /// prep time, budget flag, category and the Friday-special chip.
  Widget buildBadges(Brightness brightness, AppStrings strings) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (proteinType != ProteinType.none)
          _pill(
            brightness,
            _proteinStyle(proteinType, brightness),
            [
              Text(proteinType.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                proteinType.label(strings),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _proteinStyle(proteinType, brightness).foreground,
                ),
              ),
            ],
          ),
        if (carbsType != CarbsType.none)
          _pill(
            brightness,
            _neutralStyle(brightness),
            [
              Text(
                carbsType.label(strings),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textSecondary(brightness),
                ),
              ),
            ],
            border: Border.all(color: AppPalette.hairline(brightness)),
          ),
        if (prepTimeMinutes != null)
          _pill(
            brightness,
            AppPalette.chipViolet(brightness),
            [
              AppIcon(
                AppGlyph.clock,
                color: AppPalette.chipViolet(brightness).foreground,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                strings.minutes(prepTimeMinutes!),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.chipViolet(brightness).foreground,
                ),
              ),
            ],
          ),
        if (isBudgetFriendly)
          _pill(
            brightness,
            AppPalette.chipGreen(brightness),
            [
              const Text('🌿', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                strings.budgetFriendly,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.chipGreen(brightness).foreground,
                ),
              ),
            ],
          ),
        if (category != null)
          _pill(
            brightness,
            _neutralStyle(brightness),
            [
              AppIcon(
                AppGlyph.pot,
                color: AppPalette.textSecondary(brightness),
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                category!.label(strings),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textSecondary(brightness),
                ),
              ),
            ],
            border: Border.all(color: AppPalette.hairline(brightness)),
          ),
        if (isFridaySpecial)
          _pill(
            brightness,
            AppPalette.chipGold(brightness),
            [
              AppIcon(
                AppGlyph.flame,
                color: AppPalette.chipGold(brightness).foreground,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                strings.fridaySpecial,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.chipGold(brightness).foreground,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // Pill & palette helpers mirror `MealDetailsSheet`'s private builders so
  // every meal surface renders identical chips (deliberate duplication over a
  // risky refactor of the sheet, which existing widget tests exercise).
  Widget _pill(
    Brightness brightness,
    ChipStyle style,
    List<Widget> children, {
    Border? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  static ChipStyle _neutralStyle(Brightness b) {
    return ChipStyle(
      background: AppPalette.tabContainer(b),
      foreground: AppPalette.textSecondary(b),
    );
  }

  static ChipStyle _proteinStyle(ProteinType p, Brightness b) {
    switch (p) {
      case ProteinType.chicken:
        return AppPalette.chipGold(b);
      case ProteinType.beef:
        return AppPalette.chipRose(b);
      case ProteinType.fish:
        return AppPalette.chipBlue(b);
      case ProteinType.legume:
        return AppPalette.chipGreen(b);
      case ProteinType.dairy:
        return AppPalette.chipViolet(b);
      case ProteinType.none:
        return AppPalette.chipGreen(b);
    }
  }
}
