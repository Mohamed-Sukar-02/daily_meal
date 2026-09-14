import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import 'home_header.dart';

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

/// The floating "لف العجلة" roulette button: rainbow ring, white disc,
/// coloured pie and orange shine marks on both sides.
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmphasisMarks(size: 16, mirrored: true),
            const SizedBox(width: 4),
            Opacity(
              opacity: enabled ? 1 : 0.45,
              child: GestureDetector(
                onTap: enabled ? onTap : null,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
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
            ),
            const SizedBox(width: 4),
            const EmphasisMarks(size: 16),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'لف العجلة',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppPalette.textPrimary(brightness),
          ),
        ),
      ],
    );
  }
}
