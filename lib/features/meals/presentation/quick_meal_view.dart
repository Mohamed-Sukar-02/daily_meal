import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/meal_image.dart';

/// Formats preparation time through [AppStrings.minutes], which applies the
/// correct plural form for the active locale (Arabic has four plural buckets).
String formatPrepTime(int minutes, AppStrings strings) =>
    strings.minutes(minutes);

/// Which approved shape of the meal view a surface asks for.
///
/// The two shapes are the two card designs the mockups approved; they share
/// every input (photo, name, protein, time, category, the honour flags) and
/// differ only in how that data is laid out and how much chrome is drawn:
///
///  * [detail] — the editorial treatment: tall rounded hero carrying the
///    honour capsules, a category overline above the name and an equal-width
///    spec strip. It draws no surface of its own, so it sits inside a sheet, a
///    card or a page background. This is the default.
///  * [quick] — the quick entry-point card: an elevated surface with its own
///    tap target, a wide inset hero band with a floating love toggle, colour
///    pills for protein / time / category, an honour wrap and a footer action.
///    This is what the home recommendation list shows.
enum MealViewShape { detail, quick }

/// Lightweight, reusable meal view — the single visual vocabulary for a
/// meal's hero photo, name and meta strip (protein, carbs, prep time,
/// category, budget, Friday special).
///
/// It is the *entry point view* for meals across the app:
///  * The home recommendation list embeds it as [MealViewShape.quick], which
///    makes the card the quick entry-point view of a meal rather than a
///    page-only widget (tap it and the details sheet opens).
///  * [MealDetailsSheet] renders it as the header of every meal it presents and
///    passes its love / bookmark control through [QuickMealView.nameTrailing].
///  * Any future list, card or dialog can embed the exact same presentation
///    via [QuickMealView.fromMeal] instead of re-rolling pills and badges.
///
/// In [MealViewShape.detail] the widget draws no outer card of its own: it is a
/// rounded hero plus body, so it can sit inside a sheet, a card or a page
/// background without nesting surfaces. [MealViewShape.quick] is the one
/// caller that asks for the surface, because there the card *is* the entry
/// point.
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

  /// Loved state. [MealViewShape.quick] reads it for the glyph of its floating
  /// heart and for the "مفضلة" pill; [MealViewShape.detail] leaves the love
  /// control to [nameTrailing] and draws nothing from this flag.
  final bool isFavorite;

  /// Which approved card design this surface asks for. See [MealViewShape].
  final MealViewShape shape;

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

  /// Tap target of the [MealViewShape.quick] card surface — the entry point
  /// that opens the meal. Ignored by [MealViewShape.detail], which is never a
  /// surface of its own.
  final VoidCallback? onTap;

  /// Love toggle wired to the heart floating on the quick card's hero. Left
  /// null by a caller that has no local row to love.
  final VoidCallback? onToggleFavorite;

  /// Action row drawn under the body of the quick card (the "Cook This" pill).
  /// A slot rather than a callback so the view stays free of home-feature
  /// widgets: the caller hands in whatever action its context asks for.
  final Widget? footer;

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
    this.isFavorite = false,
    this.shape = MealViewShape.detail,
    this.photoHeight = 210,
    this.photoCacheWidth = 720,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.nameTrailing,
    this.onTap,
    this.onToggleFavorite,
    this.footer,
  });

  /// Normalises a local vault [Meal] into the view.
  factory QuickMealView.fromMeal(
    Meal meal, {
    Key? key,
    MealViewShape shape = MealViewShape.detail,
    double photoHeight = 210,
    int photoCacheWidth = 720,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    Widget? nameTrailing,
    VoidCallback? onTap,
    VoidCallback? onToggleFavorite,
    Widget? footer,
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
      isFavorite: meal.isFavorite,
      shape: shape,
      photoHeight: photoHeight,
      photoCacheWidth: photoCacheWidth,
      padding: padding,
      nameTrailing: nameTrailing,
      onTap: onTap,
      onToggleFavorite: onToggleFavorite,
      footer: footer,
    );
  }

  static const double _heroRadius = 22;
  static const BorderRadius _heroBorderRadius =
      BorderRadius.all(Radius.circular(_heroRadius));

  // --- Metrics of the quick card, measured from the home mockups -----------
  // They are design constants rather than parameters: every caller of the
  // quick shape has to reproduce the approved card exactly, so there is
  // nothing for a surface to choose here.

  /// Hero photo aspect ratio measured from the mockups (≈852×215).
  static const double _quickHeroAspectRatio = 3.96;
  static const double _quickHeroRadius = 14;
  static const double _quickCardRadius = 20;
  static const BorderRadius _quickHeroBorderRadius =
      BorderRadius.all(Radius.circular(_quickHeroRadius));
  static const BorderRadius _quickCardBorderRadius =
      BorderRadius.all(Radius.circular(_quickCardRadius));
  /// The heart floats on the physical right of the hero in both directions,
  /// exactly where the mockups pin it — hence `right`, not `end`.
  static const double _quickHeartInset = 10;
  static const double _quickHeartSize = 40;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    if (shape == MealViewShape.quick) {
      return _buildQuickCard(context, brightness, strings);
    }

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
  // Quick card — the home recommendation surface (MealViewShape.quick)
  // ---------------------------------------------------------------------------

  /// The elevated card the home list shows: a card surface that owns the tap,
  /// an inset wide hero with the love toggle floating on it, the name, the
  /// protein / time / category pills, the honour wrap and the footer action.
  ///
  /// Rebuilt 1:1 from the approved mockups — the metrics live in the
  /// `_quick*` constants above, not in parameters, so the card cannot drift
  /// per caller.
  Widget _buildQuickCard(
    BuildContext context,
    Brightness brightness,
    AppStrings strings,
  ) {
    return Container(
      key: const Key('quick_meal_view'),
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: _quickCardBorderRadius,
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.35)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQuickHero(brightness),
              const SizedBox(height: 12),
              // Title — Flexible to handle 1.6x/2.0x scaling on 320px
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 10),
              // Main chips (protein / time / category) — own Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickChip(
                    context,
                    AppPalette.chipRose(brightness),
                    AppGlyph.steak,
                    proteinType.label(strings),
                  ),
                  _quickChip(
                    context,
                    AppPalette.chipGold(brightness),
                    AppGlyph.clock,
                    formatPrepTime(prepTimeMinutes ?? 0, strings),
                  ),
                  if (category != null)
                    _quickChip(
                      context,
                      AppPalette.chipViolet(brightness),
                      AppGlyph.oven,
                      category!.label(strings),
                    ),
                  // Dummy to ensure only the badges Wrap below has exactly
                  // three children — the shape the card was approved with.
                  const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 8),
              // Badges (Friday / Budget / Favorite) — separate Wrap with the
              // exact spacing the card was approved with (8 / 6) and 3 children.
              if (_quickBadges(context, strings, brightness).isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _quickBadges(context, strings, brightness),
                ),
              if (_quickBadges(context, strings, brightness).isNotEmpty)
                const SizedBox(height: 8),
              // Actions
              if (footer != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickHero(Brightness brightness) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: _quickHeroAspectRatio,
          child: ClipRRect(
            borderRadius: _quickHeroBorderRadius,
            child: MealImage(
              photoPath: photoPath,
              // Downscale big cloud photos while decoding: 3 cards at once.
              cacheWidth: photoCacheWidth,
              fallback: _QuickHeroPlaceholder(brightness: brightness),
            ),
          ),
        ),
        if (onToggleFavorite != null)
          Positioned(
            top: _quickHeartInset,
            right: _quickHeartInset,
            child: _QuickLoveButton(
              size: _quickHeartSize,
              isFavorite: isFavorite,
              onToggle: onToggleFavorite,
              brightness: brightness,
            ),
          ),
      ],
    );
  }

  List<Widget> _quickBadges(
    BuildContext context,
    AppStrings strings,
    Brightness brightness,
  ) {
    final badges = <Widget>[
      if (isFridaySpecial)
        _quickChip(
          context,
          AppPalette.chipGold(brightness),
          AppGlyph.star,
          strings.fridaySpecial,
          fontSize: 11,
        ),
      if (isBudgetFriendly)
        _quickChip(
          context,
          AppPalette.chipGreen(brightness),
          AppGlyph.wallet,
          strings.budgetFriendly,
          fontSize: 11,
        ),
      if (isFavorite)
        _quickChip(
          context,
          AppPalette.chipRose(brightness),
          AppGlyph.heartFill,
          strings.favorite,
          fontSize: 11,
        ),
    ];
    return badges;
  }

  /// Colour pill of the quick card: glyph + label on a tinted surface, capped
  /// so a long Arabic enum label can never push the row open.
  Widget _quickChip(
    BuildContext context,
    ChipStyle style,
    AppGlyph glyph,
    String label, {
    double fontSize = 12,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(glyph, color: style.foreground, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: style.foreground,
                      ),
                ),
              ),
            ),
          ],
        ),
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

/// Empty-photo stand-in of the quick card. The detail shape draws its own
/// ringed [_HeroPlaceholder]; the card keeps the flat brand gradient it was
/// approved with, and keeps the `meal_photo_placeholder` key so tooling that
/// looks for "this meal has no photo yet" still finds one.
class _QuickHeroPlaceholder extends StatelessWidget {
  final Brightness brightness;

  const _QuickHeroPlaceholder({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('meal_photo_placeholder'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppPalette.tabContainer(brightness),
            AppPalette.card(brightness),
          ],
        ),
      ),
      child: Center(
        child: AppIcon(
          AppGlyph.pot,
          color: AppPalette.textSecondary(brightness),
          size: 34,
        ),
      ),
    );
  }
}

/// Love toggle floating on the quick card's hero. It owns its own pressed
/// state so the heart pops instantly on tap, while the write it triggers
/// ([_onToggle]) is what eventually re-comes through [isFavorite].
class _QuickLoveButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback? onToggle;
  final Brightness brightness;
  final double size;

  const _QuickLoveButton({
    required this.isFavorite,
    required this.onToggle,
    required this.brightness,
    required this.size,
  });

  @override
  State<_QuickLoveButton> createState() => _QuickLoveButtonState();
}

class _QuickLoveButtonState extends State<_QuickLoveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _QuickLoveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _isFavorite = widget.isFavorite;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_controller.isAnimating) return;
    setState(() {
      _isFavorite = !_isFavorite;
    });
    _controller.forward(from: 0.0);
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.45)
          : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _handleTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: AppIcon(
                _isFavorite ? AppGlyph.heartFill : AppGlyph.heartOutline,
                color: AppPalette.heartCoral,
                size: 20,
              ),
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
