import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
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

Widget _buildCustomChip(String emoji, String label, Color lightBg, Color fgColor, bool isDark) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isDark ? fgColor.withOpacity(0.2) : lightBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isDark ? fgColor.withOpacity(0.5) : fgColor.withOpacity(0.3),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? fgColor.withOpacity(0.9) : fgColor.withOpacity(0.9),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class MealCard extends StatelessWidget {
  final Meal meal;
  final int cardIndex;
  final VoidCallback onCookedToday;
  final VoidCallback onLeftover;
  final VoidCallback? onTap;

  const MealCard({
    super.key,
    required this.meal,
    required this.cardIndex,
    required this.onCookedToday,
    required this.onLeftover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = cardIndex == 0;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isPrimary ? (isDark ? 0 : 2) : 0,
      color: isPrimary
          ? (isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surface)
          : (isDark ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surface),
      shadowColor: isDark ? Colors.transparent : theme.colorScheme.shadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isPrimary
            ? BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.6 : 0.4),
                width: 1.5,
              )
            : BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
                width: 1,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Priority Banner
            _buildPriorityBanner(context, isPrimary),

            // 2. Photo / Egyptian Graphic Placeholder with Heart Button
            Stack(
              children: [
                _buildHeroImage(context),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        meal.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: meal.isFavorite ? Colors.red : (isDark ? Colors.white : Colors.grey[700]),
                      ),
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        // TODO: Implement toggle favorite if needed
                      },
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. Badges Row (Friday, Budget, Favorite)
                  _buildBadgesRow(context),

                  const SizedBox(height: 8),

                  // 4. Meal Title (Wraps up to 3 lines without overflow)
                  Text(
                    meal.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isPrimary ? 20 : 18,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Metadata Chips (Prep time, Category, Protein, Carbs)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildCustomChip('⏳', formatPrepTime(meal.prepTime), const Color(0xFFFFF9C4), const Color(0xFFFBC02D), isDark),
                      _buildCustomChip('🍽️', meal.category.labelArabic, const Color(0xFFE1BEE7), const Color(0xFF8E24AA), isDark),
                      _buildCustomChip('🥩', meal.proteinType.labelArabic, const Color(0xFFFFCDD2), const Color(0xFFE53935), isDark),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                  ),
                  const SizedBox(height: 12),

                  // 6. Quick Action Buttons
                  QuickActions(
                    onCookedToday: onCookedToday,
                    onLeftover: onLeftover,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBanner(BuildContext context, bool isPrimary) {
    final theme = Theme.of(context);
    String title;
    Color bgColor;
    Color fgColor;

    switch (cardIndex) {
      case 0:
        title = '⭐ الترشيح الأول (أفضل اختيار)';
        bgColor = theme.colorScheme.primaryContainer;
        fgColor = theme.colorScheme.onPrimaryContainer;
        break;
      case 1:
        title = '✨ اقتراح بديل أول (تنويع البروتين)';
        bgColor = theme.colorScheme.secondaryContainer;
        fgColor = theme.colorScheme.onSecondaryContainer;
        break;
      case 2:
      default:
        title = '💡 اقتراح بديل ثانٍ (تنويع النشويات)';
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool hasPhoto = false;
    if (meal.photoPath != null && meal.photoPath!.isNotEmpty) {
      try {
        final file = File(meal.photoPath!);
        hasPhoto = file.existsSync() && file.lengthSync() > 0;
      } catch (_) {
        hasPhoto = false;
      }
    }

    if (hasPhoto) {
      return SizedBox(
        height: cardIndex == 0 ? 220 : 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
          File(meal.photoPath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context, isDark),
        ),
            if (meal.isFavorite)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black54 : Colors.white70,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.red, size: 20),
                ),
              ),
          ],
        )
      );
    }

    return _buildPlaceholder(context, isDark);
  }

  Widget _buildPlaceholder(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    // Egyptian Kitchen Aesthetic Placeholder
    return Container(
      height: cardIndex == 0 ? 220 : 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  theme.colorScheme.surfaceContainerHigh,
                ]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                  theme.colorScheme.tertiary.withValues(alpha: 0.16),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(cardIndex == 0 ? 14 : 10),
          decoration: BoxDecoration(
            color: (isDark ? theme.colorScheme.surface : Colors.white).withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: (isDark ? theme.colorScheme.outlineVariant : Colors.white).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.restaurant_rounded,
            size: cardIndex == 0 ? 40 : 28,
            color: theme.colorScheme.primary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesRow(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badges = <Widget>[];

    if (meal.isFridaySpecial) {
      final bgColor = isDark ? const Color(0xFF332300) : const Color(0xFFFFF4DE);
      final borderColor = isDark ? const Color(0xFF6B4B00) : const Color(0xFFFFD54F);
      final fgColor = isDark ? const Color(0xFFFFD54F) : const Color(0xFF8C5B00);

      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, size: 14, color: fgColor),
              const SizedBox(width: 4),
              Text(
                'أكلة جمعة',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (meal.isBudgetFriendly) {
      final bgColor = isDark ? const Color(0xFF0D2E14) : const Color(0xFFE8F5E9);
      final borderColor = isDark ? const Color(0xFF1B5E20) : const Color(0xFFA5D6A7);
      final fgColor = isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);

      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.savings_outlined, size: 14, color: fgColor),
              const SizedBox(width: 4),
              Text(
                'اقتصادي',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (meal.isFavorite) {
      final bgColor = isDark ? const Color(0xFF3B1214) : const Color(0xFFFFEBEE);
      final borderColor = isDark ? const Color(0xFF7F2327) : const Color(0xFFFFCDD2);
      final fgColor = isDark ? const Color(0xFFEF9A9A) : const Color(0xFFB71C1C);

      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: 14, color: fgColor),
              const SizedBox(width: 4),
              Text(
                'مفضلة',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: badges,
    );
  }
}
