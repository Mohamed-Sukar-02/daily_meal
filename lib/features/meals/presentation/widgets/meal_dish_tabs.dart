import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import 'meal_screen_palette.dart';

enum MealDishTab { main, side1, side2 }

/// Half-width of the S-curve where the active tab meets the bar.
const double _curve = 24;

/// Corner radius shared by the bar and the clip that shapes the tab.
const double _radius = 16;

/// The dish strip — Main / Side 1 / Side 2 — drawn as a raised bar whose
/// ACTIVE segment is a folder tab cut in the page colour, joined to the bar by
/// a pair of bezier S-curves so tab and page read as one continuous surface.
///
/// The bar's geometry (height, radius, margins, stroke) never changes; only
/// the number of segments does, so a meal with no side dishes shows a single
/// full-width tab rather than a collapsed row.
///
/// No ink splash: Material draws it as a circle/rounded rectangle, which
/// floats off the tab's silhouette. The active slot is marked instead by an
/// accent underline that glides with it, and a tap dips the label.
///
/// Slot order mirrors with the locale: Main sits at the reading start.
class MealDishTabs extends StatelessWidget {
  static const double height = 52;

  /// How far the strip tucks up over the info banner's bottom edge.
  static const double overlap = 18;

  final MealDishTab selected;
  final ValueChanged<MealDishTab> onChanged;

  /// Segments to render, in reading order. Defaults to the full set.
  final List<MealDishTab> tabs;

  const MealDishTabs({
    super.key,
    required this.selected,
    required this.onChanged,
    this.tabs = MealDishTab.values,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final n = tabs.length;
    final activeIndex = math.max(0, tabs.indexOf(selected));
    // Painter works in visual (left-to-right pixel) space.
    final activeVisual = rtl ? n - 1 - activeIndex : activeIndex;
    final visualTarget = activeVisual.toDouble();

    return SizedBox(
      key: const Key('meal_screen_dish_tabs'),
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: visualTarget),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, visualPosition, child) {
          return CustomPaint(
            painter: _FolderTabPainter(
              segmentCount: n,
              activeVisualIndex: activeVisual,
              visualPosition: visualPosition,
              barTop: MealScreenPalette.tabBarTop(brightness),
              barBottom: MealScreenPalette.tabBarBottom(brightness),
              stroke: MealScreenPalette.tabStroke(brightness),
              tabFill: MealScreenPalette.sheet(brightness),
              accent: MealScreenPalette.accent(brightness),
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: _TabButton(
                  key: Key('meal_screen_tab_${tab.name}'),
                  label: switch (tab) {
                    MealDishTab.main => strings.mainDish,
                    MealDishTab.side1 => strings.sideDish1,
                    MealDishTab.side2 => strings.sideDish2,
                  },
                  selected: tab == selected,
                  brightness: brightness,
                  reduceMotion: reduceMotion,
                  onTap: () => onChanged(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  final String label;
  final bool selected;
  final Brightness brightness;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _TabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.brightness,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final brightness = widget.brightness;
    // Material's ink is a circle/rounded-rect that cannot follow the folder
    // tab's S-curve, so it is switched off; press feedback is the label dip
    // and the accent underline the painter glides along with the tab.
    final pressDuration = widget.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 120);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (pressed) {
          if (_pressed != pressed) setState(() => _pressed = pressed);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedOpacity(
              duration: pressDuration,
              opacity: _pressed ? 0.6 : 1,
              child: AnimatedScale(
                duration: pressDuration,
                curve: Curves.easeOut,
                scale: _pressed ? 0.94 : 1,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? MealScreenPalette.tabActiveText(brightness)
                        : MealScreenPalette.tabInactiveText(brightness),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderTabPainter extends CustomPainter {
  final int segmentCount;

  /// Committed (not animated) active slot in visual space — dividers hide
  /// against it while the tab itself slides.
  final int activeVisualIndex;
  final double visualPosition;
  final Color barTop;
  final Color barBottom;
  final Color stroke;
  final Color tabFill;
  final Color accent;

  _FolderTabPainter({
    required this.segmentCount,
    required this.activeVisualIndex,
    required this.visualPosition,
    required this.barTop,
    required this.barBottom,
    required this.stroke,
    required this.tabFill,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0 || segmentCount == 0) return;

    final barRect = Rect.fromLTWH(0, 0, w, h);
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, w - 1, h - 1),
      const Radius.circular(_radius),
    );

    canvas.drawRRect(
      bar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [barTop, barBottom],
        ).createShader(barRect),
    );
    canvas.drawRRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = stroke,
    );

    if (segmentCount > 1) {
      _paintActiveTab(canvas, size);
    }

    // A divider is only drawn between two neighbouring INACTIVE segments.
    final slotW = w / segmentCount;
    final dividerPaint = Paint()
      ..color = stroke
      ..strokeWidth = 1;
    for (var i = 0; i < segmentCount - 1; i++) {
      if (i == activeVisualIndex || i + 1 == activeVisualIndex) continue;
      final x = (i + 1) * slotW;
      canvas.drawLine(Offset(x, 14), Offset(x, h - 14), dividerPaint);
    }
  }

  /// The page-coloured tab plus its own outline, clipped to the bar so the
  /// curve never spills above it.
  void _paintActiveTab(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final slotW = w / segmentCount;

    final left = visualPosition * slotW;
    final right = left + slotW;
    // At the outer edges push the curve outside the slot so the bar's clip
    // radius becomes the tab's rounded top corner, as in the reference.
    final leftX = left - _curve * math.max(0, 1 - visualPosition);
    final rightX =
        right + _curve * math.max(0, visualPosition - (segmentCount - 2));

    final edge = Path()
      ..moveTo(leftX - _curve, h + 1)
      ..cubicTo(leftX, h + 1, leftX, 0.5, leftX + _curve, 0.5)
      ..lineTo(rightX - _curve, 0.5)
      ..cubicTo(rightX, 0.5, rightX, h + 1, rightX + _curve, h + 1);

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        const Radius.circular(_radius),
      ),
    );
    canvas.drawPath(Path.from(edge)..close(), Paint()..color = tabFill);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = stroke,
    );

    /// The active mark: a short accent bar under the label that rides along
    /// with the sliding tab, standing in for the ink splash.
    final markWidth = math.min(slotW * 0.44, 56.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + (slotW - markWidth) / 2,
          h / 2 + 13,
          markWidth,
          3,
        ),
        const Radius.circular(1.5),
      ),
      Paint()..color = accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FolderTabPainter old) =>
      old.segmentCount != segmentCount ||
      old.activeVisualIndex != activeVisualIndex ||
      old.visualPosition != visualPosition ||
      old.barTop != barTop ||
      old.barBottom != barBottom ||
      old.stroke != stroke ||
      old.tabFill != tabFill ||
      old.accent != accent;
}
