import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../vault/application/meal_proposal_service.dart';
import '../../vault/presentation/widgets/delete_meal_dialog.dart';
import '../../vault/presentation/widgets/quick_add_sheet.dart';
import '../../vault/providers/vault_providers.dart';
import '../../../core/widgets/meal_image.dart';
import 'quick_meal_view.dart';

/// Full meal screen — the complete view of one vault meal.
///
/// Reached from [MealDetailsSheet]'s "full details" link at `/meal/:id`
/// (root navigator, on top of the shell). The meal is resolved reactively
/// from `allMealsProvider` by id, so the screen survives a deep link and
/// reflects edits/deletes made elsewhere without extra wiring.
///
/// Layout: [QuickMealView] hero (photo, name, badges) → notes card →
/// Cloud Staging Export button → Edit / Delete row. Favourite toggle lives
/// in the app bar and writes through `vaultControllerProvider` (the same
/// notifier the vault cards use), which never re-ranks home recommendations
/// (the eligibility key is blind to the favourite flag).
class MealScreen extends ConsumerWidget {
  final int mealId;

  const MealScreen({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final mealsAsync = ref.watch(allMealsProvider);
    final isProposing = ref.watch(activeProposalMealIdProvider) == mealId;

    return Scaffold(
      key: const Key('meal_screen'),
      backgroundColor: AppPalette.background(brightness),
      appBar: AppBar(
        backgroundColor: AppPalette.background(brightness),
        surfaceTintColor: Colors.transparent,
        title: Text(
          strings.mealDetailsTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary(brightness),
          ),
        ),
        leading: IconButton(
          key: const Key('meal_screen_back_button'),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/vault');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppPalette.textPrimary(brightness),
        ),
        actions: [
          // Favourite toggle mirrors the vault-card heart.
          mealsAsync.maybeWhen(
            data: (meals) {
              final meal = _findMeal(meals);
              if (meal == null) return const SizedBox.shrink();
              
              final isSynced = meal.cloudId != null;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cloud Sync Icon
                  IconButton(
                    tooltip: isProposing ? strings.proposalInProgress : strings.proposalCta,
                    onPressed: isProposing || isSynced ? null : () => runProposalFlow(context, ref, meal),
                    icon: isProposing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AppIcon(
                            isSynced ? AppGlyph.cloudDown : AppGlyph.cloudUp,
                            color: isSynced ? AppPalette.brandGreen : AppPalette.textSecondary(brightness),
                            size: 22,
                          ),
                  ),
                  // Favorite toggle
                  IconButton(
                    key: const Key('meal_screen_favorite_button'),
                    tooltip: strings.favorite,
                    onPressed: () => ref
                        .read(vaultControllerProvider.notifier)
                        .toggleFavorite(meal.id, meal.isFavorite),
                    icon: AppIcon(
                      meal.isFavorite ? AppGlyph.heartFill : AppGlyph.heartOutline,
                      color: meal.isFavorite
                          ? Colors.red.shade400
                          : AppPalette.textSecondary(brightness),
                      size: 22,
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: mealsAsync.when(
        data: (meals) {
          final meal = _findMeal(meals);
          if (meal == null) return _buildNotFound(brightness, strings);
          return _buildBody(context, ref, brightness, strings, meal, isProposing);
        },
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              strings.errorGeneric(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textSecondary(brightness)),
            ),
          ),
        ),
      ),
    );
  }

  Meal? _findMeal(List<Meal> meals) {
    for (final meal in meals) {
      if (meal.id == mealId) return meal;
    }
    return null;
  }

  Widget _buildNotFound(Brightness brightness, AppStrings strings) {
    return Center(
      key: const Key('meal_screen_not_found'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppGlyph.pot,
              color: AppPalette.textSecondary(brightness),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              strings.mealNotFound,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Brightness brightness,
    AppStrings strings,
    Meal meal,
    bool isProposing,
  ) {
    final notes = meal.notes?.trim() ?? '';
    final shortName = meal.shortName?.trim().isNotEmpty == true ? meal.shortName! : meal.name;
    final fullName = meal.name;

    return ListView(
      key: const Key('meal_screen_body'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Top: Short name
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Center(
            child: Text(
              shortName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
          ),
        ),
        // Image with gradient and full name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MealImage(
                    photoPath: meal.photoPath,
                    cacheWidth: 900,
                    fallback: Container(
                      color: AppPalette.tabContainer(brightness),
                      child: Center(
                        child: AppIcon(
                          AppGlyph.pot,
                          color: AppPalette.textSecondary(brightness),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            brightness == Brightness.dark
                                ? Colors.black.withOpacity(0.85)
                                : Colors.white.withOpacity(0.9),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          fullName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.textPrimary(brightness),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Rectangular box for meal info
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppPalette.card(brightness),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.hairline(brightness)),
              boxShadow: [
                BoxShadow(
                  color: brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF1E293B).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (meal.proteinType != ProteinType.none)
                  _infoItem(brightness, meal.proteinType.emoji, meal.proteinType.label(strings)),
                if (meal.carbsType != CarbsType.none)
                  _infoItem(brightness, \'🌾\', meal.carbsType.label(strings)),
                if (meal.prepTime > 0)
                  _infoItem(brightness, \'⏱️\', strings.minutes(meal.prepTime)),
                if (meal.isBudgetFriendly)
                  _infoItem(brightness, \'🌿\', strings.budgetFriendly),
              ],
            ),
          ),
        ),
        // Tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTab(strings.mainDish, true, brightness),
                const SizedBox(width: 8),
                _buildTab(strings.sideDish1, false, brightness),
                const SizedBox(width: 8),
                _buildTab(strings.sideDish2, false, brightness),
              ],
            ),
          ),
        ),
        // Circular placeholder
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 24),
          child: Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppPalette.tabContainer(brightness),
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.hairline(brightness), width: 2),
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant_menu,
                  color: AppPalette.textSecondary(brightness),
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              key: const Key('meal_screen_notes'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppPalette.tabContainer(brightness),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppPalette.hairline(brightness)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.notesLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textSecondary(brightness),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('meal_screen_edit_button'),
                    onPressed: () =>
                        QuickAddSheet.show(context, mealToEdit: meal),
                    icon: AppIcon(
                      AppGlyph.pencil,
                      color: AppPalette.textPrimary(brightness),
                      size: 16,
                    ),
                    label: Text(
                      strings.edit,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.textPrimary(brightness),
                      side: BorderSide(color: AppPalette.hairline(brightness)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('meal_screen_delete_button'),
                    onPressed: () async {
                      final deleted =
                          await DeleteMealDialog.show(context, meal);
                      if (deleted == true && context.mounted) {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/vault');
                        }
                      }
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    label: Text(
                      strings.delete,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoItem(Brightness brightness, String emoji, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppPalette.textSecondary(brightness),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, bool isSelected, Brightness brightness) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppPalette.brandGreen : AppPalette.tabContainer(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppPalette.brandGreen : AppPalette.hairline(brightness),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : AppPalette.textSecondary(brightness),
        ),
      ),
    );
  }
}
