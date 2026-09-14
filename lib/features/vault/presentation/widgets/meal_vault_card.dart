import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/meal_image.dart';
import '../../../home/presentation/widgets/meal_card.dart' show formatPrepTime;
import '../../providers/vault_providers.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: Key('meal_card_${meal.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Thumbnail Image or Icon Placeholder
            _buildThumbnail(context),

            const SizedBox(width: 12),

            // 2. Meal Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges (Friday, Budget)
                  if (meal.isFridaySpecial || meal.isBudgetFriendly) ...[
                    Row(
                      children: [
                        if (meal.isFridaySpecial)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'أكلة جمعة',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (meal.isBudgetFriendly)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'اقتصادي',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Meal Name
                  Text(
                    meal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Tags & Prep time
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildMiniChip(
                        context,
                        icon: Icons.timer_outlined,
                        label: formatPrepTime(meal.prepTime),
                      ),
                      _buildMiniChip(
                        context,
                        icon: Icons.category_outlined,
                        label: meal.category.labelArabic,
                      ),
                      _buildMiniChip(
                        context,
                        icon: Icons.egg_alt_outlined,
                        label: meal.proteinType.labelArabic,
                      ),
                      _buildMiniChip(
                        context,
                        icon: Icons.bakery_dining_outlined,
                        label: meal.carbsType.labelArabic,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 3. Action Buttons Column (Favorite, Edit, Delete)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('meal_favorite_button_${meal.id}'),
                  icon: Icon(
                    meal.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: meal.isFavorite ? Colors.redAccent : colorScheme.outline,
                    size: 20,
                  ),
                  tooltip: meal.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  onPressed: () {
                    ref
                        .read(vaultControllerProvider.notifier)
                        .toggleFavorite(meal.id, meal.isFavorite);
                  },
                ),
                IconButton(
                  key: Key('meal_edit_button_${meal.id}'),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  tooltip: 'تعديل الأكلة',
                  onPressed: onEdit,
                ),
                IconButton(
                  key: Key('meal_delete_button_${meal.id}'),
                  icon: Icon(
                    Icons.delete_outline,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  tooltip: 'حذف الأكلة',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);
    const double size = 72;
    final BorderRadius radius = BorderRadius.circular(12);

    // Handles Firebase URLs, local files and bundled assets in one place.
    return MealImage(
      photoPath: meal.photoPath,
      width: size,
      height: size,
      cacheWidth: 240,
      borderRadius: radius,
      fallback: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: radius,
        ),
        child: Center(
          child: Icon(
            _getCategoryIcon(meal.category),
            size: 32,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(MealCategory category) {
    switch (category) {
      case MealCategory.egyptianTraditional:
        return Icons.soup_kitchen;
      case MealCategory.ovenBaked:
        return Icons.microwave;
      case MealCategory.fastFood:
        return Icons.lunch_dining;
      case MealCategory.seafood:
        return Icons.set_meal;
      case MealCategory.soupStew:
        return Icons.ramen_dining;
      case MealCategory.vegetarian:
        return Icons.eco;
    }
  }

  Widget _buildMiniChip(BuildContext context, {required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
