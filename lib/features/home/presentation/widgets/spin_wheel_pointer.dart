import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// The wheel's pawl: a glossy teardrop on a dark mount tab, pivoting on its
/// rivet so it flicks over each peg instead of swinging from the top edge.
class SpinWheelPointer extends StatelessWidget {
  static const double width = 40;
  static const double height = 44;

  /// Radians the pin is pushed back by the peg it is riding over.
  final double angle;

  const SpinWheelPointer({super.key, this.angle = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: const Size(width, height),
      painter: _PointerPainter(isDark: isDark, angle: angle),
    );
  }
}

class _PointerPainter extends CustomPainter {
  static const double _cx = 20;
  static const double _bulbY = 17;
  static const double _bulbR = 10.5;
  static const double _tipY = 43;

  final bool isDark;
  final double angle;

  _PointerPainter({required this.isDark, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    _paintMount(canvas);

    canvas
      ..save()
      ..translate(_cx, _bulbY)
      ..rotate(angle)
      ..translate(-_cx, -_bulbY);

    final body = _teardrop();
    canvas.drawShadow(
      body,
      Colors.black.withValues(alpha: isDark ? 0.55 : 0.3),
      8,
      false,
    );

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppPalette.brandCoral, Colors.white, 0.42)!,
            AppPalette.brandCoral,
            Color.lerp(AppPalette.brandCoral, Colors.black, 0.3)!,
          ],
          stops: const [0, 0.52, 1],
        ).createShader(Rect.fromLTWH(_cx - _bulbR, 4, _bulbR * 2, _tipY - 4)),
    );

    // Lit upper-left edge, so the body reads as moulded rather than printed.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.4],
        ).createShader(Rect.fromLTWH(_cx - _bulbR, 4, _bulbR * 2, _tipY - 4)),
    );

    _paintRivet(canvas);
    canvas.restore();
  }

  /// The bracket the pawl is bolted to. It stays still while the pin swings.
  void _paintMount(Canvas canvas) {
    final tab = RRect.fromRectAndRadius(
      const Rect.fromLTWH(_cx - 14, 0, 28, 29),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      tab.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      tab,
      Paint()
        ..color = isDark ? AppPalette.darkCard : AppPalette.lightTextPrimary,
    );
    canvas.drawRRect(
      tab,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: isDark ? 0.92 : 0.85),
    );
  }

  /// Tip → tangent line onto the bulb → the exposed arc → tangent line back.
  /// Straight flanks (not curved) are what make it read as a moulded pawl.
  Path _teardrop() {
    final center = const Offset(_cx, _bulbY);
    final halfAngle = math.acos(_bulbR / (_tipY - _bulbY));
    final sinA = math.sin(halfAngle);
    final cosA = math.cos(halfAngle);
    final left = center + Offset(-_bulbR * sinA, _bulbR * cosA);
    final right = center + Offset(_bulbR * sinA, _bulbR * cosA);
    final bulb = Rect.fromCircle(center: center, radius: _bulbR);

    final start = math.atan2(left.dy - center.dy, left.dx - center.dx);
    var sweep =
        math.atan2(right.dy - center.dy, right.dx - center.dx) - start;
    if (sweep < 0) sweep += 2 * math.pi;

    return Path()
      ..moveTo(_cx, _tipY)
      ..lineTo(left.dx, left.dy)
      ..arcTo(bulb, start, sweep, false)
      ..close();
  }

  void _paintRivet(Canvas canvas) {
    final center = const Offset(_cx, _bulbY);
    canvas
      ..drawCircle(
        center,
        6,
        Paint()
          ..color = isDark
              ? AppPalette.darkCard
              : AppPalette.lightTextPrimary,
      )
      ..drawCircle(
        center,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.25),
      )
      ..drawCircle(center, 3.2, Paint()..color = Colors.white)
      ..drawCircle(
        center + const Offset(-1.2, -1.2),
        1.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.angle != angle;
}
