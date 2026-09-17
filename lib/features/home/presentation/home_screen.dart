import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/nav_lifecycle.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../domain/cooldown_engine.dart';
import '../providers/recommendation_provider.dart';
import 'widgets/home_header.dart';
import 'widgets/meal_card.dart';
import 'widgets/spin_wheel_button.dart';
import 'widgets/spin_wheel_dialog.dart';

/// Home screen - simplified as requested:
/// - No top tabs (My Kitchen / Discovery) - removed
/// - No delivery / leftover pills in bottom bar - removed
/// - Only recommendations + spin wheel centered at bottom when >=2 meals
///
/// Lifecycle: the shell keeps this branch alive, so the recommendation list
/// would otherwise stay scrolled down forever. [NavBranchReentry] snaps it back
/// to the top whenever the user leaves the tab and comes back, without touching
/// the recommendation data itself.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with NavBranchReentry {
  final ScrollController _listController = ScrollController();

  @override
  int get navBranchIndex => NavBranch.home;

  @override
  void resetTransientUi() {
    // UI-only reset: scroll offset. No provider is invalidated here, so the
    // cached recommendations (and the whole database cache) stay intact.
    resetScroll(_listController);
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    watchNavReentry();
    final recsAsync = ref.watch(todayRecommendationsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeHeader(onProfileTap: () => context.go('/settings')),
            const SizedBox(height: 6),
            Expanded(
              child: recsAsync.when(
                data: (result) => result.recommendations.isEmpty
                    ? _buildEmptyState(context)
                    : _buildRecommendationsView(context, ref, result),
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (err, stack) => _buildErrorState(context, ref, err),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recommendations
  // ---------------------------------------------------------------------------

  Widget _buildRecommendationsView(
    BuildContext context,
    WidgetRef ref,
    RecommendationResult<Meal> result,
  ) {
    final brightness = Theme.of(context).brightness;
    final meals = result.recommendations;
    final canSpin = meals.length >= 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        RefreshIndicator(
          onRefresh: () async => ref.invalidate(todayRecommendationsProvider),
          child: ListView(
            key: const Key('home_recommendations_list'),
            controller: _listController,
            padding: EdgeInsets.fromLTRB(16, 2, 16, canSpin ? 100 : 24),
            children: [
              if (result.relaxationLevel > 0) ...[
                _buildRelaxationBanner(context, result, brightness),
                const SizedBox(height: 12),
              ],
              for (int i = 0; i < meals.length; i++) ...[
                MealCard(
                  meal: meals[i],
                  cardIndex: i,
                  onCookedToday: () => _handleCookedToday(context, ref, meals[i]),
                  onLeftover: () => _handleLeftover(context, ref, meals[i]),
                  onToggleFavorite: () {
                    ref
                        .read(recommendationControllerProvider.notifier)
                        .toggleFavorite(meals[i].id, meals[i].isFavorite);
                  },
                ),
                if (i < meals.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        if (canSpin)
          Positioned(
            left: 0,
            right: 0,
            bottom: -18,
            child: Center(
              child: SpinWheelButton(
                onTap: () => _openSpinWheel(context, ref, meals),
                enabled: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRelaxationBanner(
    BuildContext context,
    RecommendationResult<Meal> result,
    Brightness brightness,
  ) {
    final style = AppPalette.chipGold(brightness);
    final strings = AppStrings.of(context);
    final reason = strings.relaxationReason(
      result.relaxationLevel,
      isEmptyVault: result.isEmptyVault,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AppIcon(AppGlyph.star, color: style.foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.varietyAlertDetailed(result.relaxationLevel, reason),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: style.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              brightness == Brightness.dark
                  ? 'assets/icons/vault_empty_dark.png'
                  : 'assets/icons/vault_empty_light.png',
              width: 220,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => AppIcon(
                AppGlyph.pot,
                size: 64,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.vaultEmpty,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.vaultEmptyDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/vault'),
              icon: const AppIcon(AppGlyph.plus, color: Colors.white, size: 18),
              label: Text(strings.addFirstMeal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppGlyph.alert, size: 56, color: AppPalette.heartCoral),
            const SizedBox(height: 16),
            Text(
              strings.errorPreparing,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(todayRecommendationsProvider),
              icon: const AppIcon(AppGlyph.swap, size: 18, color: AppPalette.brandGreen),
              label: Text(strings.retry),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openSpinWheel(BuildContext context, WidgetRef ref, List<Meal> meals) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SpinWheelDialog(
        candidates: meals,
        onWinnerCooked: (winner) => _handleCookedToday(context, ref, winner),
      ),
    );
  }

  Future<void> _handleCookedToday(BuildContext context, WidgetRef ref, Meal meal) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final strings = AppStrings.of(context);
    final message = strings.cookedShort(meal.name);
    final undoLabel = strings.undo;
    final historyEntryId = await controller.markCookedToday(meal);

    if (context.mounted) {
      AppToast.showUndo(
        context,
        message: message,
        actionLabel: undoLabel,
        onUndo: () {
          controller.undoLastCookingLog(historyEntryId);
        },
      );
    }
  }

  Future<void> _handleLeftover(BuildContext context, WidgetRef ref, Meal meal) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final strings = AppStrings.of(context);
    final message = strings.leftoverSuccess(meal.name);
    final undoLabel = strings.undo;
    final historyEntryId = await controller.markLeftover(meal);

    if (context.mounted) {
      AppToast.showUndo(
        context,
        message: message,
        actionLabel: undoLabel,
        onUndo: () {
          controller.undoLastCookingLog(historyEntryId);
        },
      );
    }
  }
}
