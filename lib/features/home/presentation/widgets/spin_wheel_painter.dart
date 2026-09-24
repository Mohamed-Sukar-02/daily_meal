import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_palette.dart';
import 'spin_wheel_candidate_tile.dart';

/// Paints the roulette disc: one sector per candidate repeat, tinted with the
/// same [SpinWheelTint] its list row uses, plus the rim pegs the pointer
/// clicks past.
class SpinWheelPainter extends CustomPainter {
  final List<Meal> candidates;
  final List<SpinWheelTint> tints;
  final bool isDark;

  SpinWheelPainter({
    required this.candidates,
    required this.tints,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final wheel = Rect.fromCircle(center: center, radius: radius);
    final count = candidates.length;

    // Distribute into many segments evenly.
    int multiplier = 12 ~/ count;
    if (multiplier < 2) multiplier = 2;
    final totalSegments = count * multiplier;
    final sweepAngle = (2 * math.pi) / totalSegments;

    final sector = Paint();
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: isDark ? 0.22 : 0.08);

    // Labels run outward along the sector, so they are bounded by the hub ring
    // on the inside and the peg orbit at the rim.
    final labelStart = radius * 0.44;
    final labelSpan = radius * 0.85 - labelStart;

    for (var i = 0; i < totalSegments; i++) {
      final mealIndex = i % count;
      final startAngle = i * sweepAngle;
      final tint = tints[mealIndex % tints.length];

      // Deep toward the hub, bright at the rim, so the disc reads as a lit
      // object instead of a flat pie chart.
      sector.shader = RadialGradient(
        colors: [
          tint.deep.withValues(alpha: isDark ? 0.16 : 0.10),
          tint.light.withValues(alpha: isDark ? 0.42 : 0.30),
        ],
        stops: const [0.25, 1],
      ).createShader(wheel);

      canvas.drawArc(wheel, startAngle, sweepAngle, true, sector);
      canvas.drawArc(wheel, startAngle, sweepAngle, true, divider);

      final shortName = candidates[mealIndex].shortName?.isNotEmpty == true
          ? candidates[mealIndex].shortName!
          : candidates[mealIndex].name;
      final label = _layoutLabel(shortName, labelSpan);

      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(startAngle + sweepAngle / 2);
      label.paint(canvas, Offset(labelStart, -label.height / 2));
      canvas.restore();
    }

    _paintPegs(canvas, center, radius, totalSegments, sweepAngle);
    _paintRings(canvas, center, radius, wheel);
  }

  /// Fits the dish name inside its sector, dropping the type size once before
  /// the ellipsis takes over.
  TextPainter _layoutLabel(String text, double maxWidth) {
    TextPainter build(double fontSize) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: isDark
                  ? Colors.white
                  : AppPalette.textPrimary(Brightness.light),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              overflow: TextOverflow.ellipsis,
              shadows: isDark
                  ? const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : const [
                      Shadow(
                        color: Colors.white70,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
          ),
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout(maxWidth: maxWidth);

    final label = build(14);
    if (!label.didExceedMaxLines) return label;
    label.dispose();
    return build(12.5);
  }

  /// Metal studs on every segment divider: they give the spring-loaded
  /// pointer something visible to tick against.
  void _paintPegs(
    Canvas canvas,
    Offset center,
    double radius,
    int totalSegments,
    double sweepAngle,
  ) {
    const orbit = 12.0;
    const stud = 3.4;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.25);
    final metal = Paint();

    for (var i = 0; i < totalSegments; i++) {
      final angle = i * sweepAngle;
      final peg =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - orbit);
      final disc = Rect.fromCircle(center: peg, radius: stud);
      metal.shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: [
          Colors.white,
          isDark
              ? AppPalette.textSecondary(Brightness.dark)
              : AppPalette.textSecondary(Brightness.light),
        ],
      ).createShader(disc);

      canvas
        ..drawCircle(peg, stud + 1, shadow)
        ..drawCircle(peg, stud, metal);
    }
  }

  void _paintRings(Canvas canvas, Offset center, double radius, Rect wheel) {
    // A white rim reads as light on the dark sheet; on the white sheet it is
    // invisible, so the light theme gets a neutral metal edge instead.
    final ring = isDark
        ? Colors.white
        : AppPalette.textSecondary(Brightness.light);
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ring.withValues(alpha: isDark ? 0.34 : 0.40),
            ring.withValues(alpha: isDark ? 0.08 : 0.14),
          ],
        ).createShader(wheel),
    );

    // Hub ring keeps the disc from reading as one flat circle.
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ring.withValues(alpha: isDark ? 0.14 : 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) {
    return oldDelegate.candidates != candidates ||
        oldDelegate.tints != tints ||
        oldDelegate.isDark != isDark;
  }
}
