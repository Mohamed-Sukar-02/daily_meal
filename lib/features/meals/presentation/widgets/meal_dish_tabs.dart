import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import 'meal_screen_palette.dart';

enum MealDishTab { main, side1, side2 }

/// Curved tab strip — Main / Side 1 / Side 2 — locked to the meal-screen
/// mockups:
///  * the strip keeps a fixed LTR slot order (Main at the left) in every
///    locale, exactly like the reference images;
///  * white-ish outline, dark fill;
///  * the SELECTED tab is raised a few pixels above the strip edge and filled
///    with the info-banner deep green, so when the parent opens the borders
///    around it (see `_InterlockedInfoTabs`) tab and banner read as one
///    fused shape.
/// Fixed height (46) so the parent's fusion painter can compute the seam
/// geometry deterministically.
class MealDishTabs extends StatelessWidget {
  static const double height = 46;

  final MealDishTab selected;
  final ValueChanged<MealDishTab> onChanged;

  const MealDishTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return SizedBox(
      key: const Key('meal_screen_dish_tabs'),
      height: height,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: MealScreenPalette.tabBar(brightness),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: MealScreenPalette.interlockStroke(brightness),
            width: 1.2,
          ),
        ),
        // Mockup truth: slot order is Main → Side1 → Side2 left-to-right in
        // every locale, so the fused-tab geometry stays identical RTL/LTR.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              _Tab(
                key: const Key('meal_screen_tab_main'),
                label: strings.mainDish,
                selected: selected == MealDishTab.main,
                brightness: brightness,
                onTap: () => onChanged(MealDishTab.main),
              ),
              _Sep(brightness: brightness),
              _Tab(
                key: const Key('meal_screen_tab_side1'),
                label: strings.sideDish1,
                selected: selected == MealDishTab.side1,
                brightness: brightness,
                onTap: () => onChanged(MealDishTab.side1),
              ),
              _Sep(brightness: brightness),
              _Tab(
                key: const Key('meal_screen_tab_side2'),
                label: strings.sideDish2,
                selected: selected == MealDishTab.side2,
                brightness: brightness,
                onTap: () => onChanged(MealDishTab.side2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  final Brightness brightness;
  const _Sep({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: MealScreenPalette.muted(brightness).withValues(alpha: 0.35),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  const _Tab({
    super.key,
    required this.label,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          // The raised fill that pokes above the strip edge (selected only).
          // Horizontal inset 3 matches the parent's seam-erasure band exactly,
          // so the tab bridge never paints over the strip outline.
          child: Transform.translate(
            offset: selected ? const Offset(0, -4) : Offset.zero,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: selected ? 3 : 0),
              padding: EdgeInsets.only(
                top: selected ? 8 : 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? MealScreenPalette.infoCardDeep(brightness)
                    : Colors.transparent,
                borderRadius: selected
                    ? const BorderRadius.vertical(
                        top: Radius.circular(12),
                        bottom: Radius.circular(18),
                      )
                    : BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? MealScreenPalette.accent(brightness)
                      : MealScreenPalette.tabIdle(brightness),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
