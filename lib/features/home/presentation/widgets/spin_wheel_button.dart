import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import 'emphasis_marks.dart';

/// Paints the rainbow ring of the roulette button.
class _RainbowRingPainter extends CustomPainter {
  final List<Color> colors;
  final double thickness;

  _RainbowRingPainter({required this.colors, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (math.min(size.width, size.height) - thickness) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..shader = SweepGradient(
        colors: [...colors, colors.first],
        startAngle: 0,
        endAngle: math.pi * 2,
      ).createShader(rect.deflate(thickness / 2));

    canvas.drawCircle(rect.center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RainbowRingPainter oldDelegate) =>
      oldDelegate.thickness != thickness;
}

/// Paints the six coloured wedges inside the wheel.
class _PiePainter extends CustomPainter {
  final List<Color> colors;

  _PiePainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sweep = math.pi * 2 / colors.length;
    for (var i = 0; i < colors.length; i++) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep,
        sweep,
        true,
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => false;
}

/// Paints text curved along a circular arc centered at [center] with radius [radius].
class _CurvedTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final double radius;
  final Offset center;
  final bool isRtl;

  _CurvedTextPainter({
    required this.text,
    required this.style,
    required this.radius,
    required this.center,
    required this.isRtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final displayChars = _prepareGlyphs(text, isRtl);
    if (displayChars.isEmpty) return;

    final painters = <TextPainter>[];
    final glyphAngles = <double>[];
    double totalAngle = 0;

    for (final char in displayChars) {
      final tp = TextPainter(
        text: TextSpan(text: char, style: style),
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      )..layout();
      painters.add(tp);

      final factor = isRtl ? 0.90 : 1.05;
      final angle = (tp.width * factor) / radius;
      glyphAngles.add(angle);
      totalAngle += angle;
    }

    // Centered at top of circle (-pi / 2)
    const centerAngle = -math.pi / 2;

    if (isRtl) {
      // Arabic reads right-to-left: first glyph starts at right, advances counter-clockwise (towards left)
      double currentAngle = centerAngle + (totalAngle / 2);
      for (int i = 0; i < painters.length; i++) {
        final tp = painters[i];
        final halfSpan = glyphAngles[i] / 2;
        final theta = currentAngle - halfSpan;
        currentAngle -= glyphAngles[i];

        _paintGlyph(canvas, tp, theta);
      }
    } else {
      // English / LTR reads left-to-right: first glyph starts at left, advances clockwise (towards right)
      double currentAngle = centerAngle - (totalAngle / 2);
      for (int i = 0; i < painters.length; i++) {
        final tp = painters[i];
        final halfSpan = glyphAngles[i] / 2;
        final theta = currentAngle + halfSpan;
        currentAngle += glyphAngles[i];

        _paintGlyph(canvas, tp, theta);
      }
    }
  }

  void _paintGlyph(Canvas canvas, TextPainter tp, double theta) {
    final x = center.dx + radius * math.cos(theta);
    final y = center.dy + radius * math.sin(theta);

    // Tangent angle to make text upright (top pointing outward)
    final tangent = theta + (math.pi / 2);

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(tangent);
    canvas.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  static List<String> _prepareGlyphs(String text, bool isRtl) {
    if (isRtl) {
      // Shape standard Arabic 'لف العجلة' into connected Presentation Forms-B glyphs
      // so cursive connections are preserved when painted along the arc
      if (text.contains('لف') && text.contains('العجلة')) {
        return [
          '\uFEDF', // Lam initial
          '\uFED2', // Feh final
          ' ',
          '\uFE8D', // Alef isolated
          '\uFEDF', // Lam initial
          '\uFEEC', // Ain medial
          '\uFEA0', // Jeem medial
          '\uFEE0', // Lam medial
          '\uFE94', // Teh Marbuta final
        ];
      }
    }
    return text.characters.toList();
  }

  @override
  bool shouldRepaint(covariant _CurvedTextPainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.radius != radius ||
      oldDelegate.center != center ||
      oldDelegate.isRtl != isRtl;
}

/// The floating roulette button: rainbow ring, white disc, coloured pie,
/// orange shine marks on both sides, and curved text hugging the upper perimeter.
class SpinWheelButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool enabled;

  const SpinWheelButton({
    super.key,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final text = strings.spinNow;
    final isRtl = !strings.isEn;

    const double wheelSize = 68.0;
    const double radius = wheelSize / 2; // 34.0
    const double totalWidth = 114.0;
    const double totalHeight = 86.0;
    const Offset center = Offset(totalWidth / 2, 48.0);

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Left sparks
              Positioned(
                left: 2,
                top: center.dy - 8,
                child: const EmphasisMarks(size: 16, mirrored: true),
              ),
              // Right sparks
              Positioned(
                right: 2,
                top: center.dy - 8,
                child: const EmphasisMarks(size: 16),
              ),
              // Wheel circle
              Positioned(
                left: center.dx - radius,
                top: center.dy - radius,
                width: wheelSize,
                height: wheelSize,
                child: Container(
                  width: wheelSize,
                  height: wheelSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _RainbowRingPainter(
                      colors: AppPalette.wheelRainbow,
                      thickness: 9,
                    ),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: ClipOval(
                            child: CustomPaint(
                              size: const Size(34, 34),
                              painter: _PiePainter(AppPalette.wheelRainbow),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Curved text along the top arc
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CurvedTextPainter(
                      text: text,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimary(brightness),
                        letterSpacing: isRtl ? 0.0 : 0.4,
                      ),
                      radius: 43.5,
                      center: center,
                      isRtl: isRtl,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

