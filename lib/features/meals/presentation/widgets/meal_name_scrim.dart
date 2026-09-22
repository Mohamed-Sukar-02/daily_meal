import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Theme-aware name scrim painted over the meal hero photo.
///
/// Spec (user mockup):
///  * Light mode → soft white veil under the full name.
///  * Dark mode  → soft black/charcoal veil under the full name.
///  * Alpha stays light so the photo still reads through.
///  * Top edge fades into the photo (vertical gradient).
///  * Trailing edge (where the text *ends* — left in RTL / right in LTR)
///    dissolves into the photo so the two layers blend instead of hard-cut.
///
/// Pure presentation: no providers, no strings.
class MealNameScrim extends StatelessWidget {
  final String fullName;
  final Brightness brightness;
  final TextDirection textDirection;

  /// Optional key forwarded to the name [Text] for tests.
  final Key? nameKey;

  const MealNameScrim({
    super.key,
    required this.fullName,
    required this.brightness,
    required this.textDirection,
    this.nameKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    // Soft veil — enough contrast for the name, photo still visible.
    final veil = isDark
        ? const Color(0xFF0B0E14).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.82);
    final nameColor = AppPalette.textPrimary(brightness);

    // Horizontal fade direction: dissolve on the side the text *ends*.
    // RTL (Arabic) ends on the left → fade left edge.
    // LTR (English) ends on the right → fade right edge.
    final fadeOnLeft = textDirection == TextDirection.rtl;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: Stack(
          children: [
            // Dual-axis scrim: vertical top-fade + horizontal end-fade.
            Positioned.fill(
              child: CustomPaint(
                painter: _ScrimPainter(
                  veil: veil,
                  fadeOnLeft: fadeOnLeft,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 40, 18, 14),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  fullName,
                  key: nameKey,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: nameColor,
                    shadows: [
                      // Hairline readability boost without hard outline.
                      Shadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a soft rectangular veil whose top and trailing edges dissolve.
class _ScrimPainter extends CustomPainter {
  final Color veil;
  final bool fadeOnLeft;

  _ScrimPainter({required this.veil, required this.fadeOnLeft});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Base vertical gradient: transparent at top → full veil at bottom.
    final vertical = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          veil.withValues(alpha: 0.0),
          veil.withValues(alpha: veil.a * 0.55),
          veil,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, vertical);

    // Horizontal dissolve on the text-end side. We *erase* the veil there
    // with dstOut so the photo bleeds back in.
    final erase = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = LinearGradient(
        begin: fadeOnLeft ? Alignment.centerLeft : Alignment.centerRight,
        end: fadeOnLeft ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          Colors.black.withValues(alpha: 0.85),
          Colors.black.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.18, 0.42],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, erase);
  }

  @override
  bool shouldRepaint(covariant _ScrimPainter old) =>
      old.veil != veil || old.fadeOnLeft != fadeOnLeft;
}
