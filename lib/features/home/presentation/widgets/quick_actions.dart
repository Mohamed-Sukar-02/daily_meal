import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';

/// The card's action: the gradient "Cook This" pill (green in dark mode, coral
/// in light mode), labelled and closed by the arrow the approved card draws at
/// its reading end.
///
/// A per-card "change this meal" control used to live beside it. Replacing one
/// of the day's three cards turned out not to be a thing worth a button: the
/// same result is one pull-to-refresh away, and the pull is the gesture the
/// list already teaches. What is left here can therefore take the full width
/// of the card's panel.
class QuickActions extends StatelessWidget {
  final VoidCallback onCookedToday;

  /// Fill the width offered rather than hugging the label. The card's panel is
  /// the pill's only constraint now, so a stretched pill cannot overflow it.
  final bool stretch;

  const QuickActions({
    super.key,
    required this.onCookedToday,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) => _buildCookPill(context);

  Widget _buildCookPill(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    // The pill is a capsule, so every corner radius in here is half the height.
    const height = 38.0;
    const radius = BorderRadius.all(Radius.circular(height / 2));

    return Material(
      key: const ValueKey('btn_cooked_today'),
      borderRadius: radius,
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppPalette.ctaGradient(brightness),
          borderRadius: radius,
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
          borderRadius: radius,
          onTap: onCookedToday,
          child: Container(
            height: height,
            constraints: stretch
                ? const BoxConstraints(minWidth: 96)
                : const BoxConstraints(minWidth: 96, maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                // The approved card prints the arrow at the reading end of the
                // pill, so it sits after the label and mirrors with it.
                const SizedBox(width: 8),
                const AppIcon(
                  AppGlyph.arrowUpRight,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

