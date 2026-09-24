import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_palette.dart';

/// A duotone accent used by the spin wheel: [light] carries the highlight,
/// [deep] carries the shadow. Both the candidate tiles and the wheel sectors
/// read from the same tint so a dish is one colour everywhere in the sheet.
class SpinWheelTint {
  final Color light;
  final Color deep;

  const SpinWheelTint(this.light, this.deep);
}

/// Cool-anchored accent ramp (teal → blue → violet) with saffron and coral
/// kept for the warm end of the wheel. Order matters: it is cycled by index.
const List<SpinWheelTint> kSpinWheelTints = [
  SpinWheelTint(Color(0xFF2DD4BF), Color(0xFF0D9488)), // Nile teal
  SpinWheelTint(Color(0xFFFBBF24), Color(0xFFB45309)), // Saffron
  SpinWheelTint(Color(0xFFFF8A70), Color(0xFFDC5A41)), // Brand coral
  SpinWheelTint(Color(0xFF34D399), Color(0xFF047857)), // Emerald mint
  SpinWheelTint(Color(0xFFA78BFA), Color(0xFF6D28D9)), // Orchid violet
  SpinWheelTint(Color(0xFF38BDF8), Color(0xFF1D4ED8)), // Lagoon blue
  SpinWheelTint(Color(0xFFF472B6), Color(0xFFBE185D)), // Rose
  SpinWheelTint(Color(0xFF22D3EE), Color(0xFF0E7490)), // Ice cyan
];

/// One candidate row of the spin wheel sheet.
class SpinWheelCandidateTile extends StatelessWidget {
  static const double height = 76;
  static const double radius = 22;
  static const double orbSize = 46;

  final int index;
  final Meal meal;
  final SpinWheelTint tint;
  final bool isRtl;

  const SpinWheelCandidateTile({
    super.key,
    required this.index,
    required this.meal,
    required this.tint,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            // Accent bloom. Test goldens render BoxShadow unblurred, so this
            // only looks like a slab in the PNGs — it is a glow on device.
            BoxShadow(
              color: tint.light.withValues(alpha: isDark ? 0.22 : 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CustomPaint(
            painter: _TileSurfacePainter(
              tint: tint,
              base: isDark
                  ? theme.colorScheme.surfaceContainer
                  : AppPalette.card(theme.brightness),
              isDark: isDark,
              isRtl: isRtl,
            ),
            child: SizedBox(
              height: height,
              child: Row(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  const SizedBox(width: 16),
                  _buildOrb(isDark),
                  const SizedBox(width: 14),
                  Expanded(child: _buildName(theme)),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Numbered glass orb: the light source sits top-left in both locales so the
  /// wheel reads as one lit object.
  Widget _buildOrb(bool isDark) {
    final deepEnd = isDark
        ? tint.deep
        : Color.lerp(tint.deep, Colors.black, 0.22)!;

    return Container(
      width: orbSize,
      height: orbSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.3,
          colors: [tint.light, deepEnd],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.3 : 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: tint.deep.withValues(alpha: isDark ? 0.6 : 0.32),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          height: 1,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildName(ThemeData theme) {
    return Text(
      meal.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 15.5,
        height: 1.35,
        fontWeight: FontWeight.w800,
        color: AppPalette.textPrimary(theme.brightness),
      ),
    );
  }
}

class _TileSurfacePainter extends CustomPainter {
  final SpinWheelTint tint;
  final Color base;
  final bool isDark;
  final bool isRtl;

  _TileSurfacePainter({
    required this.tint,
    required this.base,
    required this.isDark,
    required this.isRtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect, const Radius.circular(SpinWheelCandidateTile.radius));

    // +1 / -1 so gradients and the glow follow the orb to the correct edge.
    final orbSide = isRtl ? 1.0 : -1.0;

    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRect(rect, Paint()..color = base);

    // Diagonal tint wash, strongest under the orb.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(orbSide, -1),
          end: Alignment(-orbSide, 1),
          colors: [
            tint.light.withValues(alpha: isDark ? 0.34 : 0.32),
            tint.deep.withValues(alpha: isDark ? 0.18 : 0.13),
          ],
          stops: const [0, 0.88],
        ).createShader(rect),
    );

    // Ambient light spilling from the orb into the surface.
    final glowRadius = size.height * 0.9;
    final glowCenter = Offset(
      orbSide > 0 ? size.width - 39 : 39,
      size.height / 2,
    );
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.light.withValues(alpha: isDark ? 0.30 : 0.26),
            tint.light.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    // Top sheen: the lit upper edge of a glass slab.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.07 : 0.45),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.34],
        ).createShader(rect),
    );

    // Accent rail on the far edge, echoing the wheel sector this row maps to.
    const railInset = 9.0;
    const railWidth = 3.5;
    final rail = Rect.fromLTWH(
      isRtl ? railInset : size.width - railInset - railWidth,
      17,
      railWidth,
      size.height - 34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rail, const Radius.circular(railWidth / 2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.light, tint.deep],
        ).createShader(rail),
    );

    canvas.restore();

    // Hairline rim that fades downward, so the tile catches light at the top.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          colors: [
            tint.light.withValues(alpha: isDark ? 0.55 : 0.7),
            tint.deep.withValues(alpha: isDark ? 0.18 : 0.28),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _TileSurfacePainter oldDelegate) =>
      oldDelegate.tint != tint ||
      oldDelegate.base != base ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isRtl != isRtl;
}
