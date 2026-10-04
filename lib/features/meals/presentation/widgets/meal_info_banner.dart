import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import 'meal_screen_palette.dart';

/// The green info card that sits directly above the dish strip: the meal's category
/// marks on the left and its full name on the right, split by a seam that slides to
/// wherever the name happens to end.
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
    final marks = _marksFor(meal, strings);

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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        // The two columns keep a fixed visual order — marks on the left, name on
        // the right — instead of mirroring with the locale. What this card names
        // is an Arabic dish whatever the UI language is, so the name belongs at
        // the right in both, and the app ships English chrome around Arabic
        // content today. Only the layout is pinned; each Text keeps the ambient
        // direction for its own shaping.
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            _Marks(marks: marks, brightness: brightness),
            const SizedBox(width: 12),
            Expanded(
              // End-aligned so the name keeps its anchor at the card's right
              // edge and the seam rides its left: a long name walks the seam
              // across toward the marks, a short one leaves it close behind.
              child: Row(
                textDirection: TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Seam(brightness: brightness),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      meal.name,
                      key: const Key('meal_screen_full_name'),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: MealScreenPalette.cardText(brightness),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Protein and carbs, one mark each. A meal with neither — the vegetarian,
  /// no-carbs case — falls back to its category so the column is never empty.
  static List<_Mark> _marksFor(Meal meal, AppStrings strings) {
    final marks = <_Mark>[];
    if (meal.proteinType != ProteinType.none) {
      marks.add(
        _Mark(
          meal.proteinType.emoji,
          strings.proteinMarkLabel(meal.proteinType.name),
        ),
      );
    }
    if (meal.carbsType != CarbsType.none) {
      marks.add(
        _Mark(
          meal.carbsType.emoji,
          strings.carbsMarkLabel(meal.carbsType.name),
        ),
      );
    }
    if (marks.isEmpty) {
      marks.add(
        _Mark(
          meal.category.emoji,
          strings.categoryMarkLabel(meal.category.name),
        ),
      );
    }
    return marks;
  }
}

/// The hairline between the two columns. Asked for as "hidden, but present":
/// one stroke at a fraction of the alpha the card's own outline runs at, so the
/// split still reads without a rule being drawn across the card.
class _Seam extends StatelessWidget {
  final Brightness brightness;
  const _Seam({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 6,
      endIndent: 6,
      color: Colors.white.withValues(
        alpha: MealScreenPalette.isDark(brightness) ? 0.14 : 0.22,
      ),
    );
  }
}

class _Marks extends StatelessWidget {
  final List<_Mark> marks;
  final Brightness brightness;

  const _Marks({required this.marks, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      // Start rather than centre: the marks line up along the seam and only the
      // words run ragged, which is what makes two marks read as a list.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < marks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _MarkRow(mark: marks[i], brightness: brightness),
        ],
      ],
    );
  }
}

class _MarkRow extends StatelessWidget {
  final _Mark mark;
  final Brightness brightness;

  const _MarkRow({required this.mark, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The emoji badge the rest of the app marks a food with, rather than a
        // drawn glyph: `beef` as a steak and `pasta` as three noodles read as
        // abstract strokes at this size, where the same food is unmistakable as
        // an emoji.
        Text(mark.emoji, style: const TextStyle(fontSize: 15, height: 1.1)),
        const SizedBox(width: 6),
        Text(
          mark.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: MealScreenPalette.cardSub(brightness),
          ),
        ),
      ],
    );
  }
}

/// One category mark: what it is drawn as, and the single word beside it.
class _Mark {
  final String emoji;
  final String label;

  const _Mark(this.emoji, this.label);
}
