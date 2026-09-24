import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/meal_image.dart';

/// Lightweight, reusable meal view — the single visual vocabulary for a
/// meal's hero photo, name and meta strip (protein, carbs, prep time,
/// category, budget, Friday special).
///
/// It is the *entry point view* for meals across the app:
///  * [MealDetailsSheet] renders it as the header of every meal it presents and
///    passes its love / bookmark control through [QuickMealView.nameTrailing].
///  * Any future list, card or dialog can embed the exact same presentation
///    via [QuickMealView.fromMeal] instead of re-rolling pills and badges.
///
/// The widget draws no outer card of its own: it is a rounded hero plus body,
/// so it can sit inside a sheet, a card or a page background without nesting
/// surfaces.
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

  /// Inset around the whole view. The hero is rounded, so it needs horizontal
  /// breathing room rather than the full-bleed treatment it used to have.
  final EdgeInsetsGeometry padding;

  /// Action rendered beside the name block (love / bookmark toggle).
  final Widget? nameTrailing;

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
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.nameTrailing,
  });

  /// Normalises a local vault [Meal] into the view.
  factory QuickMealView.fromMeal(
    Meal meal, {
    Key? key,
    double photoHeight = 210,
    int photoCacheWidth = 720,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    Widget? nameTrailing,
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
      padding: padding,
      nameTrailing: nameTrailing,
    );
  }

  static const double _heroRadius = 22;
  static const BorderRadius _heroBorderRadius =
      BorderRadius.all(Radius.circular(_heroRadius));

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final cells = _specCells(brightness, strings);

    return Padding(
      key: const Key('quick_meal_view'),
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: photoHeight, child: _buildHero(brightness, strings)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildIdentity(brightness, strings)),
              if (nameTrailing != null) ...[
                const SizedBox(width: 12),
                nameTrailing!,
              ],
            ],
          ),
          if (cells.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: AppPalette.hairline(brightness)),
            const SizedBox(height: 14),
            _SpecStrip(cells: cells),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  /// Rounded photo with the meal's "honours" (Friday special / budget) floating
  /// as colour-coded capsules in the leading top corner, so the photo itself
  /// stays clean while the two flags that sell the meal read first.
  Widget _buildHero(Brightness brightness, AppStrings strings) {
    final badges = <Widget>[
      if (isFridaySpecial)
        _HonourBadge(
          style: AppPalette.chipGold(brightness),
          glyph: AppGlyph.flame,
          label: strings.fridaySpecial,
        ),
      if (isBudgetFriendly)
        _HonourBadge(
          style: AppPalette.chipGreen(brightness),
          glyph: AppGlyph.wallet,
          label: strings.budgetFriendly,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: _heroBorderRadius,
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.45)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.12),
            blurRadius: brightness == Brightness.dark ? 22 : 18,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _heroBorderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MealImage(
              photoPath: photoPath,
              cacheWidth: photoCacheWidth,
              alignment: Alignment.topCenter,
              fallback: _HeroPlaceholder(brightness: brightness),
            ),
            if (badges.isNotEmpty)
              PositionedDirectional(
                top: 12,
                start: 12,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Identity: category overline + name
  // ---------------------------------------------------------------------------

  Widget _buildIdentity(Brightness brightness, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (category != null) ...[
          Text(
            category!.label(strings),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: AppPalette.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary(brightness),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Spec strip
  // ---------------------------------------------------------------------------

  /// The "what is in it / how long does it take" facts, as equal-width labelled
  /// cells instead of a wrap of same-weight pills — protein is the headline,
  /// so every cell now carries its own caption and reads at a glance.
  List<_SpecCell> _specCells(Brightness brightness, AppStrings strings) {
    return [
      if (proteinType != ProteinType.none)
        _SpecCell(
          label: strings.proteinTypeLabel,
          value: proteinType.label(strings),
          style: _proteinStyle(proteinType, brightness),
          child: Text(proteinType.emoji, style: const TextStyle(fontSize: 15)),
        ),
      if (carbsType != CarbsType.none)
        _SpecCell(
          label: strings.carbsTypeLabel,
          value: carbsType.label(strings),
          style: _neutralStyle(brightness),
          child: AppIcon(AppGlyph.pot, color: _neutralStyle(brightness).foreground, size: 15),
        ),
      if (prepTimeMinutes != null)
        _SpecCell(
          label: strings.timeLabel,
          value: strings.prepMinutesShort(prepTimeMinutes!),
          style: AppPalette.chipViolet(brightness),
          child: AppIcon(
            AppGlyph.clock,
            color: AppPalette.chipViolet(brightness).foreground,
            size: 15,
          ),
        ),
    ];
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

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// Empty-photo stand-in: a soft brand-tinted surface with a ringed pot, so the
/// hero keeps its shape instead of collapsing into a grey rectangle.
class _HeroPlaceholder extends StatelessWidget {
  final Brightness brightness;

  const _HeroPlaceholder({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.tabContainer(brightness),
            AppPalette.brandGreen.withValues(alpha: 0.14),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.card(brightness).withValues(alpha: 0.70),
            border: Border.all(
              color: AppPalette.brandGreen.withValues(alpha: 0.28),
            ),
          ),
          child: Center(
            child: AppIcon(
              AppGlyph.pot,
              color: AppPalette.textSecondary(brightness),
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

/// Colour-coded capsule that floats over the hero photo. It keeps the palette's
/// accessible chip foreground on an opaque chip background, then adds a same-hue
/// ring and a drop shadow so it stays legible against any photo.
class _HonourBadge extends StatelessWidget {
  final ChipStyle style;
  final AppGlyph glyph;
  final String label;

  const _HonourBadge({
    required this.style,
    required this.glyph,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.foreground.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(glyph, color: style.foreground, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: style.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecCell {
  final String label;
  final String value;
  final ChipStyle style;
  final Widget child;

  const _SpecCell({
    required this.label,
    required this.value,
    required this.style,
    required this.child,
  });
}

/// Equal-width spec cells split by hairlines. Cells stretch to the row's height
/// so the dividers run the full length of the strip.
class _SpecStrip extends StatelessWidget {
  final List<_SpecCell> cells;

  const _SpecStrip({required this.cells});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Container(width: 1, color: AppPalette.hairline(brightness)),
          ),
        );
      }
      children.add(Expanded(child: _CellBody(cell: cells[i])));
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CellBody extends StatelessWidget {
  final _SpecCell cell;

  const _CellBody({required this.cell});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cell.style.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: cell.style.foreground.withValues(alpha: 0.18),
                ),
              ),
              alignment: Alignment.center,
              child: cell.child,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cell.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textSecondary(brightness),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          cell.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary(brightness),
          ),
        ),
      ],
    );
  }
}
