import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import 'chef_hat_painter.dart';

/// Card actions exactly as in the mockups: a gradient "Cook This" pill
/// (green in dark mode, coral in light mode) plus a circular outlined
/// button for logging leftovers.
class QuickActions extends StatelessWidget {
  final VoidCallback onCookedToday;
  final VoidCallback onLeftover;

  const QuickActions({
    super.key,
    required this.onCookedToday,
    required this.onLeftover,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Wrap ensures that on 320px with 2.0x text scaling the two actions
    // flow to the next line instead of throwing RenderFlex overflow.
    // Cook button uses Flexible + FittedBox so long scaled text shrinks.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Material(
          key: const ValueKey('btn_cooked_today'),
          borderRadius: BorderRadius.circular(23),
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppPalette.ctaGradient(brightness),
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: (brightness == Brightness.dark
                          ? AppPalette.brandGreen
                          : AppPalette.brandCoral)
                      .withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(23),
              onTap: onCookedToday,
              child: Container(
                height: 46,
                constraints: const BoxConstraints(minWidth: 96, maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CustomPaint(
                      size: Size(20, 20),
                      painter: ChefHatPainter(
                        stroke: Colors.white,
                        heart: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Cook This',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Material(
          key: const ValueKey('btn_leftover'),
          color: Colors.transparent,
          type: MaterialType.circle,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onLeftover,
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppPalette.outline(brightness),
                  width: 1.6,
                ),
              ),
              child: Center(
                child: AppIcon(
                  AppGlyph.swap,
                  size: 20,
                  color: AppPalette.textSecondary(brightness),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
