import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/meal_image.dart';
import '../../../vault/providers/vault_providers.dart';
import 'meal_screen_palette.dart';

/// "More Favorites" block under the dish tabs.
///
/// Outer chrome locked to the mockup (title + 2-col rounded cards with
/// circular thumb). Inner card content is intentionally light — the user
/// still has design tweaks pending for this block; we map price→nothing and
/// leaf-tag→protein/budget label so it stays useful without inventing UI.
class MoreFavoritesGrid extends ConsumerWidget {
  final int currentMealId;

  const MoreFavoritesGrid({super.key, required this.currentMealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final favAsync = ref.watch(favoriteMealsProvider);

    return favAsync.when(
      data: (allFavs) {
        final items =
            allFavs.where((m) => m.id != currentMealId).take(6).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            key: const Key('meal_screen_more_favorites'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.moreFavorites,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: MealScreenPalette.text(brightness),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final cardW = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final meal in items)
                        SizedBox(
                          width: cardW,
                          child: _FavoriteTile(
                            meal: meal,
                            brightness: brightness,
                            strings: strings,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final Meal meal;
  final Brightness brightness;
  final AppStrings strings;

  const _FavoriteTile({
    required this.meal,
    required this.brightness,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final tag = meal.isBudgetFriendly
        ? strings.budgetFriendly
        : meal.proteinType != ProteinType.none
            ? meal.proteinType.label(strings)
            : strings.healthyTag;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/meal/${meal.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: MealScreenPalette.card(brightness),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MealScreenPalette.cardBorder(brightness)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.35 : 0.06,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular thumb — mockup signature.
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MealScreenPalette.cardBorder(brightness),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: MealImage(
                  photoPath: meal.photoPath,
                  width: 54,
                  height: 54,
                  cacheWidth: 160,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: MealScreenPalette.cardBorder(brightness),
                    child: Center(
                      child: AppIcon(
                        AppGlyph.pot,
                        color: MealScreenPalette.muted(brightness),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.shortName?.trim().isNotEmpty == true
                          ? meal.shortName!.trim()
                          : meal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: MealScreenPalette.text(brightness),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (meal.prepTime > 0)
                      Text(
                        strings.prepMinutesShort(meal.prepTime),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: MealScreenPalette.text(brightness),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppIcon(
                          AppGlyph.wallet,
                          color: MealScreenPalette.tag(brightness),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: MealScreenPalette.tag(brightness),
                            ),
                          ),
                        ),
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
}
