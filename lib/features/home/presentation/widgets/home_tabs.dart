import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';

/// The two-state segmented control under the header
/// ("My Kitchen" ⇄ "Discovery") drawn exactly as in the mockups:
/// stadium container, green gradient pill for the active segment.
class HomeTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const HomeTabs({
    super.key,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Directionality(
        // Mockups show "My Kitchen" on the left in both locales.
        textDirection: TextDirection.ltr,
        child: Container(
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppPalette.tabContainer(brightness),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: _segment(
                  context,
                  selected: index == 0,
                  glyph: AppGlyph.pot,
                  label: 'My Kitchen',
                  onTap: () => onChanged(0),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _segment(
                  context,
                  selected: index == 1,
                  glyph: AppGlyph.compass,
                  label: 'Discovery',
                  onTap: () => onChanged(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required bool selected,
    required AppGlyph glyph,
    required String label,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: selected ? AppPalette.ctaGradient(Brightness.dark) : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.brandGreen.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              glyph,
              size: 20,
              color: selected
                  ? Colors.white
                  : AppPalette.textSecondary(brightness),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : AppPalette.textSecondary(brightness),
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
