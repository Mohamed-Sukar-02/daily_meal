import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/meal_image.dart';
import '../../vault/application/meal_proposal_service.dart';
import '../../vault/presentation/widgets/delete_meal_dialog.dart';
import '../../vault/presentation/widgets/quick_add_sheet.dart';
import '../../vault/providers/vault_providers.dart';
import 'widgets/meal_dish_section.dart';
import 'widgets/meal_name_scrim.dart';

/// Full meal screen — the complete view of one vault meal.
///
/// Reached from [MealDetailsSheet]'s "full details" link at `/meal/:id`
/// (root navigator, on top of the shell). The meal is resolved reactively
/// from `allMealsProvider` by id, so the screen survives a deep link and
/// reflects edits/deletes made elsewhere without extra wiring.
///
/// Layout (mockup-aligned):
///   AppBar (back · title · cloud · favourite)
///   → short name
///   → hero photo with theme-aware fading full-name scrim
///   → info rectangle (protein / carbs / prep / budget)
///   → hairline
///   → Main / Side 1 / Side 2 tabs + selected pane (frontend shell)
///   → circular decorative placeholder
///   → notes card · Edit / Delete
class MealScreen extends ConsumerStatefulWidget {
  final int mealId;

  const MealScreen({super.key, required this.mealId});

  @override
  ConsumerState<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends ConsumerState<MealScreen> {
  MealDishTab _selectedDish = MealDishTab.main;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final mealsAsync = ref.watch(allMealsProvider);
    final isProposing =
        ref.watch(activeProposalMealIdProvider) == widget.mealId;

    return Scaffold(
      key: const Key('meal_screen'),
      backgroundColor: AppPalette.background(brightness),
      appBar: AppBar(
        backgroundColor: AppPalette.background(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
          // Three app-native marks live here: cloud sync · favourite · (status).
          // They already exist in the app icon language (AppGlyph) — no new assets.
          mealsAsync.maybeWhen(
            data: (meals) {
              final meal = _findMeal(meals);
              if (meal == null) return const SizedBox.shrink();

              final isSynced = meal.cloudId != null;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isProposing
                        ? strings.proposalInProgress
                        : strings.proposalCta,
                    onPressed: isProposing || isSynced
                        ? null
                        : () => runProposalFlow(context, ref, meal),
                    icon: isProposing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AppIcon(
                            isSynced ? AppGlyph.cloudDown : AppGlyph.cloudUp,
                            color: isSynced
                                ? AppPalette.brandGreen
                                : AppPalette.textSecondary(brightness),
                            size: 22,
                          ),
                  ),
                  IconButton(
                    key: const Key('meal_screen_favorite_button'),
                    tooltip: strings.favorite,
                    onPressed: () => ref
                        .read(vaultControllerProvider.notifier)
                        .toggleFavorite(meal.id, meal.isFavorite),
                    icon: AppIcon(
                      meal.isFavorite
                          ? AppGlyph.heartFill
                          : AppGlyph.heartOutline,
                      color: meal.isFavorite
                          ? Colors.red.shade400
                          : AppPalette.textSecondary(brightness),
                      size: 22,
                    ),
                  ),
                  // Third mark — Friday / budget status glyph when flagged.
                  if (meal.isFridaySpecial || meal.isBudgetFriendly)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: AppIcon(
                        meal.isFridaySpecial ? AppGlyph.flame : AppGlyph.wallet,
                        color: meal.isFridaySpecial
                            ? AppPalette.sparkOrange
                            : AppPalette.brandGreen,
                        size: 20,
                      ),
                    )
                  else
                    const SizedBox(width: 4),
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
          return _buildBody(
            context,
            brightness,
            strings,
            meal,
            isProposing,
          );
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
      if (meal.id == widget.mealId) return meal;
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
    Brightness brightness,
    AppStrings strings,
    Meal meal,
    bool isProposing,
  ) {
    final notes = meal.notes?.trim() ?? '';
    final shortName = (meal.shortName?.trim().isNotEmpty == true)
        ? meal.shortName!.trim()
        : meal.name;
    final fullName = meal.name;
    final textDirection = Directionality.of(context);

    // Main-dish pane reuses notes when present; sides stay as UI shells until
    // the backend composition payload lands.
    Widget? panelBody;
    if (_selectedDish == MealDishTab.main && notes.isNotEmpty) {
      panelBody = _DishNotesBody(notes: notes, brightness: brightness);
    }

    return ListView(
      key: const Key('meal_screen_body'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Short name ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 14),
          child: Center(
            child: Text(
              shortName,
              key: const Key('meal_screen_short_name'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
          ),
        ),

        // ── Hero photo + full-name scrim ──────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              key: const Key('meal_screen_hero'),
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MealImage(
                    photoPath: meal.photoPath,
                    cacheWidth: 900,
                    fit: BoxFit.cover,
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
                  MealNameScrim(
                    fullName: fullName,
                    brightness: brightness,
                    textDirection: textDirection,
                    nameKey: const Key('meal_screen_full_name'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Info rectangle ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            key: const Key('meal_screen_info_card'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppPalette.card(brightness),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.hairline(brightness)),
              boxShadow: [
                BoxShadow(
                  color: brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0xFF1E293B).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (meal.proteinType != ProteinType.none)
                  _InfoChip(
                    brightness: brightness,
                    leading: Text(
                      meal.proteinType.emoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                    label: meal.proteinType.label(strings),
                  ),
                if (meal.carbsType != CarbsType.none)
                  _InfoChip(
                    brightness: brightness,
                    leading: AppIcon(
                      AppGlyph.pot,
                      color: AppPalette.textSecondary(brightness),
                      size: 14,
                    ),
                    label: meal.carbsType.label(strings),
                  ),
                if (meal.prepTime > 0)
                  _InfoChip(
                    brightness: brightness,
                    leading: AppIcon(
                      AppGlyph.clock,
                      color: AppPalette.textSecondary(brightness),
                      size: 14,
                    ),
                    label: strings.minutes(meal.prepTime),
                  ),
                if (meal.isBudgetFriendly)
                  _InfoChip(
                    brightness: brightness,
                    leading: AppIcon(
                      AppGlyph.wallet,
                      color: AppPalette.brandGreen,
                      size: 14,
                    ),
                    label: strings.budgetFriendly,
                  ),
                if (meal.isFridaySpecial)
                  _InfoChip(
                    brightness: brightness,
                    leading: AppIcon(
                      AppGlyph.flame,
                      color: AppPalette.sparkOrange,
                      size: 14,
                    ),
                    label: strings.fridaySpecial,
                  ),
              ],
            ),
          ),
        ),

        // ── Hairline separator ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 4),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppPalette.hairline(brightness),
          ),
        ),

        // ── Dish tabs + selected pane ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: MealDishSection(
            selected: _selectedDish,
            onChanged: (tab) => setState(() => _selectedDish = tab),
            // Frontend shell: always expose the three mockup tabs. Backend
            // will later gate side visibility on real composition data.
            showSide1: true,
            showSide2: true,
            panelBody: panelBody,
          ),
        ),

        // ── Circular decorative placeholder (UI only) ─────────────────
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 20),
          child: Center(
            child: Container(
              key: const Key('meal_screen_circle_placeholder'),
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: AppPalette.tabContainer(brightness),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppPalette.hairline(brightness),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.25)
                        : const Color(0xFF1E293B).withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // Intentionally empty — more marks land here later.
            ),
          ),
        ),

        // ── Notes (only when the main pane is not already showing them) ─
        if (notes.isNotEmpty && _selectedDish != MealDishTab.main)
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

        // ── Edit / Delete ─────────────────────────────────────────────
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
}

class _InfoChip extends StatelessWidget {
  final Brightness brightness;
  final Widget leading;
  final String label;

  const _InfoChip({
    required this.brightness,
    required this.leading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 5),
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
}

class _DishNotesBody extends StatelessWidget {
  final String notes;
  final Brightness brightness;

  const _DishNotesBody({required this.notes, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
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
    );
  }
}
