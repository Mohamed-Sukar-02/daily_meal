import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/meal_image.dart';
import 'quick_actions.dart';

/// Formats preparation time in Arabic according to Egyptian linguistic conventions:
/// <= 10 minutes: '$minutes دقائق'
/// > 10 minutes: '$minutes دقيقة'
String formatPrepTime(int minutes) {
  if (minutes <= 10) {
    return '$minutes دقائق';
  } else {
    return '$minutes دقيقة';
  }
}

/// The home recommendation card, rebuilt 1:1 from the approved mockups:
/// inset hero photo with a floating heart, bold title, meta chips
/// (protein / time / category) and the Cook-This + leftover actions.
class MealCard extends StatelessWidget {
  final Meal meal;
  final int cardIndex;
  final VoidCallback onCookedToday;
  final VoidCallback onLeftover;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  const MealCard({
    super.key,
    required this.meal,
    required this.cardIndex,
    required this.onCookedToday,
    required this.onLeftover,
    this.onTap,
    this.onToggleFavorite,
  });

  /// Hero photo aspect ratio measured from the mockups (≈852×215).
  static const double heroAspectRatio = 3.96;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.35)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context, brightness),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.textPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip(
                              context,
                              AppPalette.chipRose(brightness),
                              AppGlyph.steak,
                              meal.proteinType.labelArabic,
                            ),
                            _chip(
                              context,
                              AppPalette.chipGold(brightness),
                              AppGlyph.clock,
                              formatPrepTime(meal.prepTime),
                            ),
                            _chip(
                              context,
                              AppPalette.chipViolet(brightness),
                              AppGlyph.oven,
                              meal.category.labelArabic,
                            ),
                            ..._badges(brightness),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  QuickActions(
                    onCookedToday: onCookedToday,
                    onLeftover: onLeftover,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, Brightness brightness) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: heroAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: MealImage(
              photoPath: meal.photoPath,
              // Downscale big cloud photos while decoding: 3 cards at once.
              cacheWidth: 1080,
              fallback: _placeholder(brightness),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onToggleFavorite,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: AppIcon(
                    meal.isFavorite ? AppGlyph.heartFill : AppGlyph.heartOutline,
                    color: AppPalette.heartCoral,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(Brightness brightness) {
    return Container(
      key: const Key('meal_photo_placeholder'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppPalette.tabContainer(brightness),
            AppPalette.card(brightness),
          ],
        ),
      ),
      child: Center(
        child: AppIcon(
          AppGlyph.pot,
          color: AppPalette.textSecondary(brightness),
          size: 34,
        ),
      ),
    );
  }

  List<Widget> _badges(Brightness brightness) {
    final badges = <Widget>[];

    if (meal.isFridaySpecial) {
      badges.add(
        _chip(
          context,
          AppPalette.chipGold(brightness),
          AppGlyph.star,
          'أكلة جمعة',
          fontSize: 11,
        ),
      );
    }
    if (meal.isBudgetFriendly) {
      badges.add(
        _chip(
          context,
          AppPalette.chipGreen(brightness),
          AppGlyph.wallet,
          'اقتصادي',
          fontSize: 11,
        ),
      );
    }
    if (meal.isFavorite) {
      badges.add(
        _chip(
          context,
          AppPalette.chipRose(brightness),
          AppGlyph.heartFill,
          'مفضلة',
          fontSize: 11,
        ),
      );
    }
    return badges;
  }

  Widget _chip(
    BuildContext context,
    ChipStyle style,
    AppGlyph glyph,
    String label, {
    double fontSize = 12,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(glyph, color: style.foreground, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: style.foreground,
                ),
          ),
        ],
      ),
    );
  }
}
