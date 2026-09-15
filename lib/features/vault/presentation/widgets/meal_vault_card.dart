import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/meal_image.dart';
import '../../../home/presentation/widgets/meal_card.dart' show formatPrepTime;
import '../../providers/vault_providers.dart';

/// Vault grid card, styled after the mockups: full-bleed photo on top,
/// bold name, emoji badges + time pill and a bookmark (favourite) toggle.
///
/// Gestures: tap = edit, long-press = delete (keys kept for the test-suite).
class MealVaultCard extends ConsumerWidget {
  final Meal meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MealVaultCard({
    super.key,
    required this.meal,
    required this.onEdit,
    required this.onDelete,
  });

  /// Photo aspect ratio measured from the vault mockup (≈443×240).
  static const double photoAspectRatio = 1.84;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      key: ValueKey('meal_delete_button_${meal.id}'),
      onLongPress: onDelete,
      child: InkWell(
        key: ValueKey('meal_edit_button_${meal.id}'),
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          key: ValueKey('meal_card_${meal.id}'),
          decoration: BoxDecoration(
            color: AppPalette.card(brightness),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.35)
                    : AppPalette.lightTextPrimary.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: photoAspectRatio,
                child: MealImage(
                  photoPath: meal.photoPath,
                  cacheWidth: 480,
                  fallback: _placeholder(brightness),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (meal.proteinType != ProteinType.none)
                          _emojiBadge(
                            brightness,
                            meal.proteinType.emoji,
                            _proteinStyle(meal.proteinType, brightness),
                          ),
                        if (meal.isBudgetFriendly)
                          _emojiBadge(
                            brightness,
                            '🌿',
                            AppPalette.chipGreen(brightness),
                          ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: _timePill(brightness),
                          ),
                        ),
                        _bookmarkButton(context, ref, brightness),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(Brightness brightness) {
    return Container(
      color: AppPalette.tabContainer(brightness),
      child: Center(
        child: AppIcon(
          AppGlyph.pot,
          color: AppPalette.textSecondary(brightness),
          size: 28,
        ),
      ),
    );
  }

  Widget _emojiBadge(Brightness brightness, String emoji, ChipStyle style) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 6),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: style.background,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _timePill(Brightness brightness) {
    final style = AppPalette.chipViolet(brightness);
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppGlyph.clock, color: style.foreground, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              formatPrepTime(meal.prepTime),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: style.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookmarkButton(BuildContext context, WidgetRef ref, Brightness brightness) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () =>
          ref.read(vaultControllerProvider.notifier).toggleFavorite(meal.id, meal.isFavorite),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: AppIcon(
            AppGlyph.bookmark,
            color: meal.isFavorite
                ? AppPalette.brandGreen
                : AppPalette.textSecondary(brightness),
            size: 18,
          ),
        ),
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
