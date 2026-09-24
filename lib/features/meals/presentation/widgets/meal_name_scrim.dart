import 'package:flutter/material.dart';

import 'meal_screen_palette.dart';

/// The soft tonal bloom that makes the full meal name readable over a busy
/// photo — deliberately NOT a box: no border, no blur card, no hard edge.
///
/// It is an ellipse anchored to the corner where the text *starts* (bottom
/// right in RTL, bottom left in LTR) and dissolves in two directions at once:
/// upward into the photo and horizontally past the end of the text.
///
/// Painted once per layout, so it costs nothing per frame.
class MealNameScrim extends StatelessWidget {
  final Brightness brightness;
  final double heroHeight;

  const MealNameScrim({
    super.key,
    required this.brightness,
    required this.heroHeight,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return IgnorePointer(
      child: CustomPaint(
        painter: _EllipticalScrimPainter(
          color: MealScreenPalette.scrim(brightness),
          peak: MealScreenPalette.scrimPeak(brightness),
          anchorRight: rtl,
          radiusX: heroHeight * 0.62,
          radiusY: heroHeight * 0.45,
        ),
      ),
    );
  }
}

class _EllipticalScrimPainter extends CustomPainter {
  final Color color;
  final double peak;
  final bool anchorRight;
  final double radiusX;
  final double radiusY;

  _EllipticalScrimPainter({
    required this.color,
    required this.peak,
    required this.anchorRight,
    required this.radiusX,
    required this.radiusY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radiusY <= 0 || radiusX <= 0) return;

    final anchorX = anchorRight ? size.width : 0.0;
    // Flutter's RadialGradient is circular, so squeeze the x-axis to turn the
    // circle into the ellipse the reference calls for.
    final k = radiusX / radiusY;

    canvas.save();
    canvas.translate(anchorX, size.height);
    canvas.scale(k, 1);

    final shader = RadialGradient(
      colors: [
        color.withValues(alpha: peak),
        color.withValues(alpha: peak * 0.82),
        color.withValues(alpha: peak * 0.40),
        color.withValues(alpha: 0),
      ],
      stops: const [0, 0.26, 0.55, 0.82],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: radiusY));

    canvas.drawRect(
      Rect.fromLTRB(-anchorX / k, -size.height, (size.width - anchorX) / k, 0),
      Paint()..shader = shader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EllipticalScrimPainter old) =>
      old.color != color ||
      old.peak != peak ||
      old.anchorRight != anchorRight ||
      !old.radiusX.closeTo(radiusX) ||
      !old.radiusY.closeTo(radiusY);
}

extension on double {
  bool closeTo(double other) => (this - other).abs() < 0.01;
}
