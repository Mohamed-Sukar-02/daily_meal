import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import 'chef_hat_painter.dart';

/// Card actions: a gradient "Cook This" pill (green in dark mode, coral in
/// light mode) and, where a card may be swapped, a small secondary "change"
/// chip beside it.
class QuickActions extends StatelessWidget {
  final VoidCallback onCookedToday;

  /// Replaces just this card with the next eligible meal, leaving the others
  /// alone.
  ///
  /// Without it the day's three cards are a closed list. `rerollSingle` and the
  /// engine's per-slot refill already exist — no screen could reach them — so
  /// the only way to get rid of one card was a full refresh, which throws the
  /// other two away with it. Callers pass this only where a swap is meaningful
  /// (more than one card on screen); the pill on its own then renders exactly
  /// as before.
  final VoidCallback? onReroll;

  /// Test/debug handle for the chip, usually keyed by the meal it sits under.
  final Key? rerollKey;

  const QuickActions({
    super.key,
    required this.onCookedToday,
    this.onReroll,
    this.rerollKey,
  });

  @override
  Widget build(BuildContext context) {
    final pill = _buildCookPill(context);
    final onReroll = this.onReroll;
    if (onReroll == null) return pill;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        pill,
        _RerollChip(onTap: onReroll, key: rerollKey),
      ],
    );
  }

  Widget _buildCookPill(BuildContext context) {
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

/// The secondary control: same shape and height as the CTA so the row stays
/// aligned, deliberately flat so the eye reads it as "not the cook button".
class _RerollChip extends StatelessWidget {
  const _RerollChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    // The app's existing secondary surface (the same pair the segmented tabs
    // use), never the chip palette: a rose/gold/violet chip here would read as
    // another badge on the meal, not as a control.
    final background = AppPalette.tabContainer(brightness);
    final foreground = AppPalette.textSecondary(brightness);

    return Tooltip(
      message: strings.rerollMeal,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: onTap,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: AppPalette.outline(brightness)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppGlyph.swap, color: foreground, size: 18),
                const SizedBox(width: 6),
                Text(
                  strings.rerollShort,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
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
