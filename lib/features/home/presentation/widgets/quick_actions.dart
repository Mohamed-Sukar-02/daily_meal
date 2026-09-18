import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import 'chef_hat_painter.dart';

/// Card action: a gradient "Cook This" pill
/// (green in dark mode, coral in light mode).
class QuickActions extends StatelessWidget {
  final VoidCallback onCookedToday;

  const QuickActions({
    super.key,
    required this.onCookedToday,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Material(
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
                      strings.cookThis,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
    );
  }
}
