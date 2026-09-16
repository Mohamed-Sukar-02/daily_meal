import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../providers/vault_providers.dart';

/// Horizontal filter chips for the vault grid, styled after the mockups:
/// green "All" pill, pastel protein chips with emoji badges, Quick-30m and
/// the tag filters (favorite / friday / budget) + carbs.
class VaultFilterBar extends ConsumerWidget {
  final bool quickOnly;
  final ValueChanged<bool> onQuickChanged;

  const VaultFilterBar({
    super.key,
    required this.quickOnly,
    required this.onQuickChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(vaultFilterProvider);
    final notifier = ref.read(vaultFilterProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _Chip(
            brightness: brightness,
            selected: !filter.hasActiveFilters && !quickOnly,
            style: AppPalette.chipGreen(brightness),
            emoji: null,
            glyph: AppGlyph.grid,
            label: strings.filterAll,
            onTap: () {
              notifier.resetFilters();
              onQuickChanged(false);
            },
          ),
          for (final p in ProteinType.values) ...[
            const SizedBox(width: 8),
            _Chip(
              brightness: brightness,
              selected: filter.proteinType == p,
              style: _proteinStyle(p, brightness),
              emoji: p.emoji,
              glyph: null,
              label: p.label(strings),
              onTap: () => notifier.toggleProtein(p),
            ),
          ],
          const SizedBox(width: 8),
          _Chip(
            brightness: brightness,
            selected: quickOnly,
            style: AppPalette.chipViolet(brightness),
            emoji: null,
            glyph: AppGlyph.clock,
            label: strings.filterQuick,
            onTap: () => onQuickChanged(!quickOnly),
          ),
          const SizedBox(width: 8),
          _Chip(
            brightness: brightness,
            selected: filter.isFavoriteOnly,
            style: AppPalette.chipRose(brightness),
            emoji: null,
            glyph: AppGlyph.heartFill,
            label: strings.filterFavorites,
            onTap: () => notifier.toggleFavoriteFilter(),
          ),
          const SizedBox(width: 8),
          _Chip(
            brightness: brightness,
            selected: filter.isFridaySpecialOnly,
            style: AppPalette.chipGold(brightness),
            emoji: null,
            glyph: AppGlyph.star,
            label: strings.fridaySpecial,
            onTap: () => notifier.toggleFridayFilter(),
          ),
          const SizedBox(width: 8),
          _Chip(
            brightness: brightness,
            selected: filter.isBudgetFriendlyOnly,
            style: AppPalette.chipGreen(brightness),
            emoji: null,
            glyph: AppGlyph.wallet,
            label: strings.budgetFriendly,
            onTap: () => notifier.toggleBudgetFilter(),
          ),
          for (final c in CarbsType.values) ...[
            const SizedBox(width: 8),
            _Chip(
              brightness: brightness,
              selected: filter.carbsType == c,
              style: AppPalette.chipBlue(brightness),
              emoji: null,
              glyph: null,
              label: c.label(strings),
              onTap: () => notifier.toggleCarbs(c),
            ),
          ],
        ],
      ),
    );
  }

  ChipStyle _proteinStyle(ProteinType p, Brightness b) {
    switch (p) {
      case ProteinType.chicken:
        return AppPalette.chipGold(b);
      case ProteinType.beef:
        return AppPalette.chipRose(b);
      case ProteinType.fish:
        return AppPalette.chipBlue(b);
      case ProteinType.legume:
        return AppPalette.chipGreen(b);
      case ProteinType.dairy:
        return AppPalette.chipViolet(b);
      case ProteinType.none:
        return AppPalette.chipGreen(b);
    }
  }
}

class _Chip extends StatelessWidget {
  final Brightness brightness;
  final bool selected;
  final ChipStyle style;
  final String? emoji;
  final AppGlyph? glyph;
  final String label;
  final VoidCallback onTap;

  const _Chip({
    required this.brightness,
    required this.selected,
    required this.style,
    required this.emoji,
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppPalette.brandGreen : style.background;
    final foreground = selected ? Colors.white : style.foreground;
    final labelColor = selected
        ? Colors.white
        : AppPalette.textPrimary(brightness).withValues(alpha: 0.75);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 15))
              else if (glyph != null)
                AppIcon(glyph!, color: foreground, size: 16),
              if (emoji != null || glyph != null) const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
