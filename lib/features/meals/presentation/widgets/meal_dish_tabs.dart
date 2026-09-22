import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import 'meal_screen_palette.dart';

enum MealDishTab { main, side1, side2 }

/// Curved dark/cream tab strip under the info banner — Main / Side 1 / Side 2.
///
/// Selected tab uses the mockup accent green; idle tabs use muted tone.
/// Tapping notifies [onChanged] so the parent can swap the dish panel later
/// (backend composition still pending — frontend shell only).
class MealDishTabs extends StatelessWidget {
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

    return Container(
      key: const Key('meal_screen_dish_tabs'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? MealScreenPalette.darkTabBar
            : MealScreenPalette.lightCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: MealScreenPalette.cardBorder(brightness),
        ),
        boxShadow: [
          if (brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? MealScreenPalette.accent(brightness).withValues(
                      alpha: brightness == Brightness.dark ? 0.18 : 0.12,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
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
    );
  }
}
