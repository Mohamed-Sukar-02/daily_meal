import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dominant_colour.dart';
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

/// The compositions the home recommendation list deals out across its cards.
///
/// Every variant carries exactly the same information — the photo, the protein,
/// the name, the time, the category, the honour flags, the love toggle and the
/// cook action — and differs only in how the tile is cut.
/// That is the whole point: three identical cards in one list read as one card
/// repeated three times, so which side the photo takes, how far the tinted
/// panel leans over it and which corner the controls sit in all move between
/// neighbours. [MealCardVariant] values are chosen by the caller (see
/// `home_screen.dart`), never by the meal, so the view stays pure presentation.
enum MealCardVariant {
  /// The mockup's first card: the photo bites a bay into the panel and the
  /// heart sits low on the photo.
  photoWide(
    panelShare: 0.50,
    seamBulge: -30,
    panelAtStart: false,
    controlsAtTop: false,
  ),

  /// The mockup's second card: a narrow photo and the panel leaning well over
  /// it, the heart high.
  panelWide(
    panelShare: 0.58,
    seamBulge: 32,
    panelAtStart: true,
    controlsAtTop: true,
  ),

  /// The mockup's third card: a balanced split with a shallow seam.
  photoWideSoft(
    panelShare: 0.52,
    seamBulge: 16,
    panelAtStart: false,
    controlsAtTop: true,
  );

  const MealCardVariant({
    required this.panelShare,
    required this.seamBulge,
    required this.panelAtStart,
    required this.controlsAtTop,
  });

  /// How much of the tile's width the panel claims where the seam meets the
  /// top and bottom edges. The photo keeps the rest and bleeds under the panel.
  final double panelShare;

  /// How far the seam bows at mid-height, in logical pixels. Positive leans the
  /// panel into the photo, negative lets the photo cut a bay into the panel —
  /// the two shapes the approved cards alternate between.
  final double seamBulge;

  /// Which reading edge the panel is anchored to. `start` means the panel
  /// sits on the right in Arabic and on the left in English, so the alternation
  /// mirrors with the text instead of fighting it.
  final bool panelAtStart;

  /// The love toggle floats on the photo's far edge; which of its two corners
  /// it takes is the variant's doing.
  final bool controlsAtTop;
}

/// Lightweight, reusable meal view — the single visual vocabulary for a
/// meal's hero photo, name and meta strip (protein, carbs, prep time,
/// category, Friday special).
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

  /// Which cut of the tile the [MealViewShape.quick] card draws. Ignored by
  /// [MealViewShape.detail], which has one shape of its own.
  final MealCardVariant cardVariant;

  const QuickMealView({
    super.key,
    required this.name,
    this.photoPath,
    required this.proteinType,
    required this.carbsType,
    this.category,
    this.prepTimeMinutes,
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
    this.cardVariant = MealCardVariant.photoWide,
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
    MealCardVariant cardVariant = MealCardVariant.photoWide,
  }) {
    return QuickMealView(
      key: key,
      name: meal.name,
      photoPath: meal.photoPath,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      category: meal.category,
      prepTimeMinutes: meal.prepTime,
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
      cardVariant: cardVariant,
    );
  }

  static const double _heroRadius = 22;
  static const BorderRadius _heroBorderRadius =
      BorderRadius.all(Radius.circular(_heroRadius));

  // --- Metrics of the quick card, measured from the home mockups -----------
  // They are design constants rather than parameters: every caller of the
  // quick shape has to reproduce the approved card exactly, so there is
  // nothing for a surface to choose here. What does vary per card is the cut,
  // and that lives in [MealCardVariant].

  static const double _quickCardRadius = 26;
  static const BorderRadius _quickCardBorderRadius =
      BorderRadius.all(Radius.circular(_quickCardRadius));

  /// Fixed tile height. The card used to be a wide, short photo band with the
  /// text stacked under it, which made three recommendations taller than the
  /// screen; cutting the tile sideways buys the list its third card back.
  static const double _quickTileHeight = 192;

  /// Inset of the panel's text from the tile's start, top and bottom edges.
  static const double _quickPad = 16;

  /// Clearance kept between the text block and the seam, so a name never sits
  /// on the edge the photo breaks through.
  static const double _quickSeamGap = 14;

  static const double _quickControlInset = 12;
  static const double _quickControlSize = 40;
  static const double _quickMetaSize = 12.5;

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

  /// The tile the home list shows: the meal's photo bleeding to every edge of
  /// the card, a panel tinted by the dish curved over one side of it carrying
  /// the words, and the two controls floating on the photo's far corners.
  ///
  /// Which side is which, how far the panel leans across the seam and which
  /// corner each control takes all come from [cardVariant], so three
  /// recommendations in one list never draw the same card three times.
  Widget _buildQuickCard(
    BuildContext context,
    Brightness brightness,
    AppStrings strings,
  ) {
    final variant = cardVariant;
    final direction = Directionality.of(context);
    final panelOnLeft = variant.panelAtStart
        ? direction == TextDirection.ltr
        : direction == TextDirection.rtl;
    final ink = AppPalette.panelInk(brightness);

    return Container(
      key: const Key('quick_meal_view'),
      height: _quickTileHeight,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // The seam meets the tile's top and bottom edges at [seamX] and bows
          // to [seamX + lean] at mid-height — which is where the words live, so
          // the panel's usable width is the bowed one, not the edge one.
          final seamX =
              panelOnLeft ? w * variant.panelShare : w * (1 - variant.panelShare);
          final lean = panelOnLeft ? variant.seamBulge : -variant.seamBulge;
          final topX = seamX - lean * 1.5;
          final bottomX = seamX + lean * 1.5;
          final minSeam = topX < bottomX ? topX : bottomX;
          final maxSeam = topX > bottomX ? topX : bottomX;
          final panelMid = panelOnLeft ? minSeam : w - maxSeam;
          final textWidth =
              (panelMid - _quickPad - _quickSeamGap).clamp(0.0, w);
          // The photo is centred in the strip the panel leaves it, not in the
          // whole tile. Boxed to the full tile it would sit behind the panel's
          // own half, and a dish that fills the frame ends up with its edge
          // under the words.
          //
          // The box has to reach as far as the seam's *least* coverage, which
          // is the top and bottom edges when the panel bows outward at mid
          // height and the other way round when it bites in. Stopping at the
          // bow instead leaves the card's own background showing in the corners
          // the panel has moved away from.
          final seamEdge = panelOnLeft ? minSeam : maxSeam;
          final photoBox = Rect.fromLTRB(
            panelOnLeft ? seamEdge : 0,
            0,
            panelOnLeft ? w : seamEdge,
            _quickTileHeight,
          );
          // Which edge the words hug follows the edge the panel is anchored to:
          // the mockup's first card prints against the left, its second against
          // the right. Leaving that to the ambient direction alone would pull
          // every card's text to the seam instead.
          final atStart = variant.panelAtStart;

          return InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: photoBox,
                  child: MealImage(
                    photoPath: photoPath,
                    // Downscale big cloud photos while decoding: 3 cards at once.
                    cacheWidth: photoCacheWidth,
                    fallback: _QuickHeroPlaceholder(brightness: brightness),
                  ),
                ),
                Positioned.fill(
                  child: _PanelSurface(
                    photoPath: photoPath,
                    tone: _panelTone(proteinType),
                    brightness: brightness,
                    variant: variant,
                    panelOnLeft: panelOnLeft,
                  ),
                ),
                PositionedDirectional(
                  top: _quickPad,
                  bottom: _quickPad,
                  start: atStart ? _quickPad : null,
                  end: atStart ? null : _quickPad,
                  width: textWidth,
                  // The tile has a fixed height, so at a large system font the
                  // text block is scaled down as a unit instead of overflowing
                  // the photo it sits beside.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: atStart
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    child: SizedBox(
                      width: textWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: atStart
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.end,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: atStart
                                ? WrapAlignment.start
                                : WrapAlignment.end,
                            children: [
                              if (proteinType != ProteinType.none)
                                _quickPill(
                                  brightness,
                                  _proteinStyle(proteinType, brightness),
                                  proteinType.emoji,
                                  proteinType.label(strings),
                                  cap: textWidth,
                                ),
                              if (isFridaySpecial)
                                _quickPill(
                                  brightness,
                                  AppPalette.chipGold(brightness),
                                  '🔥',
                                  strings.fridaySpecial,
                                  cap: textWidth,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                atStart ? TextAlign.start : TextAlign.end,
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: atStart
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            children: [
                              _quickMeta(
                                AppPalette.chipGold(brightness).foreground,
                                AppGlyph.clock,
                                formatPrepTime(prepTimeMinutes ?? 0, strings),
                                cap: textWidth,
                              ),
                              if (category != null) ...[
                                const SizedBox(height: 6),
                                _quickMeta(
                                  AppPalette.panelInkSoft(brightness),
                                  AppGlyph.oven,
                                  category!.label(strings),
                                  cap: textWidth,
                                ),
                              ],
                            ],
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 14),
                            SizedBox(width: textWidth, child: footer!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // The heart floats on the photo's outer edge, where no word can
                // sit under it.
                if (onToggleFavorite != null)
                  PositionedDirectional(
                    top: variant.controlsAtTop ? _quickControlInset : null,
                    bottom: variant.controlsAtTop ? null : _quickControlInset,
                    start: atStart ? null : _quickControlInset,
                    end: atStart ? _quickControlInset : null,
                    child: _QuickLoveButton(
                      key: const Key('quick_love_button'),
                      size: _quickControlSize,
                      isFavorite: isFavorite,
                      onToggle: onToggleFavorite,
                      brightness: brightness,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Filled mark on the panel: the dish's protein, and the Friday honour when
  /// the meal carries one.
  ///
  /// The surface is the panel's own ink thinned rather than a chip colour, so
  /// the mark reads on every hue the panel can take; only its text keeps the
  /// chip's accent.
  Widget _quickPill(
    Brightness brightness,
    ChipStyle style,
    String emoji,
    String label, {
    required double cap,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
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

  /// Unfilled fact on the panel — time, category. Same glyph-plus-label shape
  /// as the pill with the surface dropped, so the two rows cannot be mistaken
  /// for each other.
  Widget _quickMeta(
    Color color,
    AppGlyph glyph,
    String label, {
    required double cap,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(glyph, color: color, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _quickMetaSize,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The panel's hue when there is no photo to read one from.
  ///
  /// A card with a picture takes its colour from that picture (see
  /// [_PanelSurface]); a card without one still has to look like it was chosen
  /// rather than left empty, so it borrows the hue the dish's protein is known
  /// for — beef claret, molokhia green, koshary brown. Deliberately its own map
  /// next to [_proteinStyle]: that one picks an accent for a cell of the spec
  /// strip, while this picks the surface the dish is served on.
  static PanelTone _panelTone(ProteinType p) {
    switch (p) {
      case ProteinType.beef:
        return PanelTone.claret;
      case ProteinType.chicken:
        return PanelTone.forest;
      case ProteinType.fish:
        return PanelTone.teal;
      case ProteinType.legume:
        return PanelTone.umber;
      case ProteinType.dairy:
        return PanelTone.amber;
      case ProteinType.none:
        return PanelTone.slate;
    }
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  /// Rounded photo with the meal's "honours" (Friday special) floating as a
  /// colour-coded capsule in the leading top corner, so the photo itself stays
  /// clean while the flag that sells the meal reads first.
  Widget _buildHero(Brightness brightness, AppStrings strings) {
    final badges = <Widget>[
      if (isFridaySpecial)
        _HonourBadge(
          style: AppPalette.chipGold(brightness),
          glyph: AppGlyph.flame,
          label: strings.fridaySpecial,
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

/// The tinted panel of a quick card.
///
/// Its hue comes from the meal's own photograph — that is what makes a list of
/// recommendations read as three dishes rather than three copies of one card,
/// and why the cut of the tile is not the only thing that moves between
/// neighbours. Only the hue is asked of the photo; [AppPalette] puts it into the
/// app's lightness envelope so the name printed on the panel stays readable no
/// matter what the picture turns out to be.
///
/// A meal with no photo, or one whose colour cannot be found, keeps [tone] —
/// the hue picked for its protein.
class _PanelSurface extends StatefulWidget {
  final String? photoPath;
  final PanelTone tone;
  final Brightness brightness;
  final MealCardVariant variant;
  final bool panelOnLeft;

  const _PanelSurface({
    required this.photoPath,
    required this.tone,
    required this.brightness,
    required this.variant,
    required this.panelOnLeft,
  });

  @override
  State<_PanelSurface> createState() => _PanelSurfaceState();
}

class _PanelSurfaceState extends State<_PanelSurface> {
  Color? _seed;

  /// The photo [_seed] was read from, so a late answer about a dish the card no
  /// longer shows cannot land on top of the one it replaced.
  String? _seededFor;

  @override
  void initState() {
    super.initState();
    _read(widget.photoPath);
  }

  @override
  void didUpdateWidget(covariant _PanelSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reroll swaps the meal behind this same element, and the previous dish's
    // colour must not be allowed to stay on the new one.
    if (oldWidget.photoPath != widget.photoPath) _read(widget.photoPath);
  }

  void _read(String? path) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) {
      if (_seededFor != null) {
        setState(() {
          _seed = null;
          _seededFor = null;
        });
      }
      return;
    }
    _seededFor = value;
    DominantColour.of(value).then((colour) {
      if (!mounted || _seededFor != value) return;
      setState(() => _seed = colour);
    });
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed;
    return ClipPath(
      clipper: _SeamClipper(
        panelShare: widget.variant.panelShare,
        seamBulge: widget.variant.seamBulge,
        panelOnLeft: widget.panelOnLeft,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: seed == null
              ? AppPalette.panelGradient(widget.tone, widget.brightness)
              : AppPalette.panelGradientFromSeed(seed, widget.brightness),
        ),
        child: _PanelOrnaments(
          variant: widget.variant,
          brightness: widget.brightness,
        ),
      ),
    );
  }
}

/// The shape of a quick card's panel: a rectangle on its own reading edge with
/// the opposite edge bowed into the photo.
///
/// The bow is drawn in physical coordinates because `CustomClipper` has no
/// notion of reading direction, so the caller resolves which side the panel
/// landed on and [panelOnLeft] mirrors the curve to match. [seamBulge] keeps
/// its meaning either way: positive always leans into the photo.
class _SeamClipper extends CustomClipper<Path> {
  final double panelShare;
  final double seamBulge;
  final bool panelOnLeft;

  const _SeamClipper({
    required this.panelShare,
    required this.seamBulge,
    required this.panelOnLeft,
  });

  @override
  Path getClip(Size size) {
    final anchor = panelOnLeft ? 0.0 : size.width;
    final seamX = panelOnLeft
        ? size.width * panelShare
        : size.width * (1 - panelShare);
    final lean = panelOnLeft ? seamBulge : -seamBulge;
    
    final topX = seamX - lean * 1.5;
    final bottomX = seamX + lean * 1.5;
    
    return Path()
      ..moveTo(anchor, 0)
      ..lineTo(topX, 0)
      ..cubicTo(
        topX,
        size.height * 0.3,
        bottomX,
        size.height * 0.7,
        bottomX,
        size.height,
      )
      ..lineTo(anchor, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _SeamClipper oldClipper) =>
      oldClipper.panelShare != panelShare ||
      oldClipper.seamBulge != seamBulge ||
      oldClipper.panelOnLeft != panelOnLeft;
}

/// Faint botanical marks on the panel of a quick card.
///
/// They sit inside the same clip as the panel, so the seam cuts through
/// whichever one reaches it — the finish the mockups draw. Positions are
/// directional, so the scatter mirrors with the panel instead of drifting onto
/// the photo.
class _PanelOrnaments extends StatelessWidget {
  final MealCardVariant variant;
  final Brightness brightness;

  const _PanelOrnaments({
    required this.variant,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final colour = AppPalette.panelOrnament(brightness);
    // -1 puts a mark toward the panel's own reading edge, +1 toward the seam.
    final side = variant.panelAtStart ? -1.0 : 1.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        _mark(AppGlyph.leaf, side * 0.82, -0.66, 30, 0.6, colour),
        _mark(AppGlyph.sprig, side * 0.12, 0.78, 22, -0.45, colour),
        _mark(AppGlyph.leaf, side * 0.52, 0.34, 17, 2.3, colour),
      ],
    );
  }

  Widget _mark(AppGlyph glyph, double x, double y, double size, double angle,
      Color colour) {
    return Align(
      alignment: AlignmentDirectional(x, y),
      child: Transform.rotate(
        angle: angle,
        child: AppIcon(glyph, color: colour, size: size),
      ),
    );
  }
}

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
    super.key,
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
