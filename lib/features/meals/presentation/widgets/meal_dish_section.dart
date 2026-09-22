import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';

/// Which dish pane the user is inspecting on [MealScreen].
///
/// Frontend-only for now — the backend will later fill each pane with real
/// composition data. Side panes stay available in the UI shell so the layout
/// matches the mockup even when the meal has no side-dish payload yet.
enum MealDishTab { main, side1, side2 }

/// Tab strip + selected-pane shell for Main / Side 1 / Side 2.
///
/// Outer chrome matches the mockup exactly (pill tabs, hairline, soft card).
/// Inner content is intentionally a lightweight placeholder — the user still
/// has backend wiring and interior design pending for this block.
class MealDishSection extends StatelessWidget {
  final MealDishTab selected;
  final ValueChanged<MealDishTab> onChanged;

  /// When false, Side 1 is hidden. Frontend default: show both sides so the
  /// mockup chrome is complete; callers can hide empty sides later.
  final bool showSide1;
  final bool showSide2;

  /// Optional body for the currently selected tab. When null a gentle empty
  /// state is rendered so the layout never collapses.
  final Widget? panelBody;

  const MealDishSection({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showSide1 = true,
    this.showSide2 = true,
    this.panelBody,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Column(
      key: const Key('meal_screen_dish_tabs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _DishTab(
                key: const Key('meal_screen_tab_main'),
                label: strings.mainDish,
                selected: selected == MealDishTab.main,
                brightness: brightness,
                onTap: () => onChanged(MealDishTab.main),
              ),
              if (showSide1) ...[
                const SizedBox(width: 8),
                _DishTab(
                  key: const Key('meal_screen_tab_side1'),
                  label: strings.sideDish1,
                  selected: selected == MealDishTab.side1,
                  brightness: brightness,
                  onTap: () => onChanged(MealDishTab.side1),
                ),
              ],
              if (showSide2) ...[
                const SizedBox(width: 8),
                _DishTab(
                  key: const Key('meal_screen_tab_side2'),
                  label: strings.sideDish2,
                  selected: selected == MealDishTab.side2,
                  brightness: brightness,
                  onTap: () => onChanged(MealDishTab.side2),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Container(
            key: ValueKey(selected),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppPalette.card(brightness),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.hairline(brightness)),
              boxShadow: [
                BoxShadow(
                  color: brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.28)
                      : const Color(0xFF1E293B).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: KeyedSubtree(
              key: const Key('meal_screen_dish_panel'),
              child: panelBody ??
                  _EmptyDishPanel(
                    label: _labelFor(selected, strings),
                    brightness: brightness,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  static String _labelFor(MealDishTab tab, AppStrings strings) {
    switch (tab) {
      case MealDishTab.main:
        return strings.mainDish;
      case MealDishTab.side1:
        return strings.sideDish1;
      case MealDishTab.side2:
        return strings.sideDish2;
    }
  }
}

class _DishTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  const _DishTab({
    super.key,
    required this.label,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.brandGreen
                : AppPalette.tabContainer(brightness),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppPalette.brandGreen
                  : AppPalette.hairline(brightness),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? Colors.white
                  : AppPalette.textSecondary(brightness),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDishPanel extends StatelessWidget {
  final String label;
  final Brightness brightness;

  const _EmptyDishPanel({required this.label, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppPalette.textSecondary(brightness),
          ),
        ),
        const SizedBox(height: 6),
        // Soft skeleton bars — visual cue that content arrives from backend.
        _SkeletonBar(brightness: brightness, widthFactor: 0.92),
        const SizedBox(height: 8),
        _SkeletonBar(brightness: brightness, widthFactor: 0.68),
        const SizedBox(height: 8),
        _SkeletonBar(brightness: brightness, widthFactor: 0.78),
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final Brightness brightness;
  final double widthFactor;

  const _SkeletonBar({required this.brightness, required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: AppPalette.tabContainer(brightness),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
