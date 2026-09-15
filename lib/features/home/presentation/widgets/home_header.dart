import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import 'chef_hat_painter.dart';

/// Orange emphasis dashes (the little "shine" marks around the logo,
/// title and spin wheel in the mockups).
class EmphasisMarks extends StatelessWidget {
  final Color color;
  final double size;

  /// Mirrors the dashes so they point the other way.
  final bool mirrored;

  const EmphasisMarks({
    super.key,
    this.color = AppPalette.sparkOrange,
    this.size = 22,
    this.mirrored = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AppIcon(AppGlyph.spark, color: color, size: size);
    if (!mirrored) return icon;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
      child: icon,
    );
  }
}

/// Home header: chef-hat logo (left), centred brand title with emphasis
/// dashes + tagline, and the profile avatar (right) – as per mockups.
class HomeHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;

  const HomeHeader({super.key, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      // The mockups lay this row out logo-left / avatar-right in both
      // locales, so the row direction is pinned to LTR.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            // Logo: hat + shine marks
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(40, 40),
                  painter: ChefHatPainter(
                    stroke: AppPalette.textPrimary(brightness),
                    heart: AppPalette.heartCoral,
                  ),
                ),
                const SizedBox(width: 2),
                const EmphasisMarks(size: 18),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const EmphasisMarks(size: 18, mirrored: true),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'أكلة النهاردة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const EmphasisMarks(size: 18),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'كل يوم فكرة جديدة .. على قدك',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            // Profile avatar
            GestureDetector(
              onTap: onProfileTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.avatarBackground(brightness),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    AppGlyph.person,
                    color: AppPalette.avatarForeground(brightness),
                    size: 22,
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
