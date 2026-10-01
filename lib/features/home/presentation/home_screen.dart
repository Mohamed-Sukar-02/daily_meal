import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/meal_log_keys.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/nav_lifecycle.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../meals/presentation/quick_meal_view.dart';
import '../../vault/presentation/widgets/delete_meal_dialog.dart';
import '../../vault/presentation/widgets/meal_details_sheet.dart';
import '../../vault/presentation/widgets/quick_add_sheet.dart';
import '../../vault/providers/vault_providers.dart';
import '../domain/cooldown_engine.dart';
import '../providers/planned_meal_provider.dart';
import '../providers/recommendation_provider.dart';
import 'widgets/home_header.dart';
import 'widgets/quick_actions.dart';
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
    final strings = AppStrings.of(context);

    // Today's plan, resolved against the vault rather than trusted: a meal
    // deleted after being planned must not leave a banner naming a row that no
    // longer exists (and must not silence the reminder — see
    // `isTodayAlreadyAnswered`, which checks the same thing).
    final plannedId = ref.watch(plannedMealIdProvider).valueOrNull;
    Meal? plannedMeal;
    if (plannedId != null) {
      final matches = (ref.watch(allMealsProvider).valueOrNull ?? const <Meal>[])
          .where((m) => m.id == plannedId);
      if (matches.isNotEmpty) plannedMeal = matches.first;
    }
    final capacity = ref.watch(vaultCapacityProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        RefreshIndicator(
          onRefresh: () async {
            final confirmed = await _confirmRefresh(context);
            if (confirmed == true) {
              ref.read(refreshSeedProvider.notifier).state++;
              // Incrementing the seed automatically triggers a recompute of todayRecommendationsProvider.
            }
          },
          child: ListView(
            key: const Key('home_recommendations_list'),
            controller: _listController,
            padding: EdgeInsets.fromLTRB(16, 2, 16, canSpin ? 110 : 28),
            children: [
              const SizedBox(height: 12),
              if (plannedId != null) ...[
                _buildTodayPlanBanner(
                  context,
                  ref,
                  mealId: plannedId,
                  meal: plannedMeal,
                  brightness: brightness,
                ),
                const SizedBox(height: 12),
              ],
              if (capacity != null && capacity.isTooSmall) ...[
                _buildVaultCapacityBanner(context, capacity, brightness),
                const SizedBox(height: 12),
              ],
              if (result.relaxationLevel > 0) ...[
                _buildRelaxationBanner(context, result, brightness),
                const SizedBox(height: 12),
              ],
              if (result.repeatedIds.isNotEmpty) ...[
                _buildRefreshNoteBanner(context, result, brightness),
                const SizedBox(height: 12),
              ],
              for (int i = 0; i < meals.length; i++) ...[
                // The recommendation card is the *quick entry point* of a meal:
                // the shared [QuickMealView] drawn in its card shape, so the
                // home list, the details sheet and any future list show one
                // meal vocabulary instead of two overlapping widgets.
                QuickMealView.fromMeal(
                  meals[i],
                  shape: MealViewShape.quick,
                  // The card's own inset — the quick hero is a wide band, so
                  // it needs the padding inside the surface, not around it.
                  padding: const EdgeInsets.all(10),
                  // Downscale big cloud photos while decoding: 3 cards at once.
                  photoCacheWidth: 1080,
                  footer: QuickActions(
                    onCookedToday: () =>
                        _handleCookedToday(context, ref, meals[i]),
                    onReroll: canSpin
                        ? () => _handleReroll(context, ref, i)
                        : null,
                    rerollKey: ValueKey('btn_reroll_${meals[i].id}'),
                  ),
                  onToggleFavorite: () {
                    ref
                        .read(recommendationControllerProvider.notifier)
                        .toggleFavorite(meals[i].id, meals[i].isFavorite);
                  },
                  // A tap does two things on purpose: it opens the sheet, as it
                  // always did, and it marks the dish as today's plan. Reading a
                  // card was previously indistinguishable from ignoring one, and
                  // the only way to make a choice visible was to log it as
                  // cooked — a claim the user has not made yet.
                  onTap: () {
                    _handlePlanTap(context, ref, meals[i]);
                    MealDetailsSheet.show(
                      context,
                      detailsContext: MealDetailsContext.vault,
                      meal: meals[i],
                      onEdit: () =>
                          QuickAddSheet.show(context, mealToEdit: meals[i]),
                      onDelete: () =>
                          DeleteMealDialog.show(context, meals[i]),
                    );
                  },
                ),
                if (i < meals.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: Row(
            children: [
              Expanded(
                child: _buildFloatingActionBtn(
                  context: context,
                  text: strings.eatYesterdayLeftovers,
                  onPressed: () => _handleEatYesterdayLeftover(context, ref),
                  keyString: 'btn_eat_yesterday_food',
                  textColor: brightness == Brightness.dark
                      ? const Color(0xFF17C97B)
                      : const Color(0xFF0D8A50),
                  backgroundColor: brightness == Brightness.dark
                      ? const Color(0xFF131D18)
                      : const Color(0xFFE8F5E9),
                  borderColor: const Color(0xFF17C97B)
                      .withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.45),
                ),
              ),
              SizedBox(width: canSpin ? 90 : 16),
              Expanded(
                child: _buildFloatingActionBtn(
                  context: context,
                  text: strings.orderTakeout,
                  onPressed: () => _handleTakeout(context, ref),
                  keyString: 'btn_order_takeout',
                  textColor: brightness == Brightness.dark
                      ? const Color(0xFF9D84FF)
                      : const Color(0xFF6D28D9),
                  backgroundColor: brightness == Brightness.dark
                      ? const Color(0xFF1A1829)
                      : const Color(0xFFF3E8FF),
                  borderColor: const Color(0xFF9D84FF)
                      .withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.45),
                ),
              ),
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

  /// "Today is decided" line: the plan the user made, in the one place they
  /// look for it, with the control that takes it back.
  ///
  /// Deliberately not a card and not a CTA: it says nothing may be cooked yet,
  /// and it is the only Home element that is *output* of a decision rather than
  /// an action on the recommendation list.
  Widget _buildTodayPlanBanner(
    BuildContext context,
    WidgetRef ref, {
    required int mealId,
    required Meal? meal,
    required Brightness brightness,
  }) {
    final style = AppPalette.chipGreen(brightness);
    final strings = AppStrings.of(context);

    return Container(
      key: const ValueKey('home_today_plan_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AppIcon(AppGlyph.bookmarkFill, color: style.foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal == null
                      ? strings.todayPlanMealMissing
                      : strings.todayPlanTitle(meal.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    color: style.foreground,
                  ),
                ),
                if (meal != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    strings.todayPlanNote,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: style.foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // A plain TextButton, not a pill: this dismisses a status line, it is
          // not a second action on the meal.
          TextButton(
            key: const ValueKey('home_today_plan_clear'),
            onPressed: () => _handlePlanClear(context, ref, mealId, meal?.name),
            child: Text(strings.undo),
          ),
        ],
      ),
    );
  }

  /// Choose today's meal — or un-choose it, when the planned card is tapped
  /// again. Writes prefs only: no history row, no cooldown, no stat.
  Future<void> _handlePlanTap(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
    final strings = AppStrings.of(context);
    final planned = ref.read(plannedMealIdProvider).valueOrNull;

    if (planned == meal.id) {
      await PlannedMeal.clearIfMatches(meal.id);
      ref.invalidate(plannedMealIdProvider);
      if (!context.mounted) return;
      AppToast.show(
        context,
        message: strings.todayPlanCleared(meal.name),
      );
      return;
    }

    await PlannedMeal.plan(meal.id);
    ref.invalidate(plannedMealIdProvider);
    if (!context.mounted) return;
    AppToast.showUndo(
      context,
      message: strings.todayPlanSet(meal.name),
      actionLabel: strings.undo,
      onUndo: () async {
        // `clearIfMatches`, not `clear`: this toast can outlive the choice it
        // undoes, and by then the user may have planned a different dish.
        await PlannedMeal.clearIfMatches(meal.id);
        if (mounted) ref.invalidate(plannedMealIdProvider);
      },
    );
  }

  Future<void> _handlePlanClear(
    BuildContext context,
    WidgetRef ref,
    int mealId,
    String? mealName,
  ) async {
    final strings = AppStrings.of(context);
    await PlannedMeal.clear();
    ref.invalidate(plannedMealIdProvider);
    // No toast when the plan pointed at a deleted dish: the banner vanishing is
    // the whole message.
    if (mealName == null || !context.mounted) return;
    AppToast.show(
      context,
      message: strings.todayPlanCleared(mealName),
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

  /// Honest-refresh note. Appears only after an explicit "change my
  /// suggestions" pull when the engine could not swap everything out: the
  /// cards it was forced to re-serve are reported in
  /// [RecommendationResult.repeatedIds]. All-slots-repeated means the pool
  /// has nothing new today; fewer means some slots kept their best pick.
  Widget _buildRefreshNoteBanner(
    BuildContext context,
    RecommendationResult<Meal> result,
    Brightness brightness,
  ) {
    final style = AppPalette.chipGold(brightness);
    final strings = AppStrings.of(context);
    final keptCount = result.repeatedIds.length;
    final message = keptCount >= result.recommendations.length
        ? strings.refreshNoNewSuggestions
        : strings.refreshKeptSuggestions(keptCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AppIcon(AppGlyph.swap, color: style.foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
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

  /// Vault health indicator: the vault cannot cover its own cooldown, so
  /// repeats are a math problem rather than an engine bug. Points at the fix
  /// (more meals) instead of apologising every time a card is re-served.
  Widget _buildVaultCapacityBanner(
    BuildContext context,
    VaultCapacity capacity,
    Brightness brightness,
  ) {
    final style = AppPalette.chipRose(brightness);
    final strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppGlyph.alert, color: style.foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.vaultTooSmallForCooldown,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: style.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.vaultCapacityDetail(
                    capacity.mealCount,
                    capacity.cooldownDays,
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textSecondary(brightness),
                  ),
                ),
                // The way out sits under the copy instead of beside it: a
                // tappable line of text next to an Expanded paragraph is a
                // greedy non-flex child, and at a large text scale it took the
                // whole row and left the warning itself 0px wide.
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => context.go('/vault'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      child: Text(
                        strings.addMoreMeals,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: style.foreground,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Empty states
  // ---------------------------------------------------------------------------

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpinWheelBottomSheet(
        candidates: meals,
        onWinnerCooked: (winner) => _handleCookedToday(context, ref, winner),
      ),
    );
  }

  /// Swap one card for the next eligible meal, leaving the other two alone.
  ///
  /// The engine's own guard answers `null` when nothing else fits the slot —
  /// then the toast says so, because the alternative is a button that was tapped
  /// and a card that quietly refused to move.
  Future<void> _handleReroll(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final notifier = ref.read(todayRecommendationsProvider.notifier);
    final strings = AppStrings.of(context);
    final replacement = await notifier.rerollSingle(index);
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: replacement == null
          ? strings.rerollNoAlternative
          : strings.rerollReplaced(replacement.name),
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



  Widget _buildFloatingActionBtn({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    required String keyString,
    required Color textColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return ElevatedButton(
      key: ValueKey(keyString),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: borderColor,
            width: 1.2,
          ),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmRefresh(BuildContext context) {
    final strings = AppStrings.of(context);
    final brightness = Theme.of(context).brightness;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card(brightness),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          strings.confirmRefreshTitle,
          style: TextStyle(
            color: AppPalette.textPrimary(brightness),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          strings.confirmRefreshMessage,
          style: TextStyle(
            color: AppPalette.textSecondary(brightness),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              strings.cancel,
              style: TextStyle(
                color: AppPalette.textSecondary(brightness),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.brandGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              strings.confirmRefreshConfirm,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Log tonight's reheat of a meal the log already holds.
  ///
  /// The window is two days, and today is excluded: this button claims
  /// "بواقي امبارح", and the lookup it replaced asked for the latest cooked row
  /// with no bound at all — so a dish cooked three weeks ago was reheated as if
  /// it were yesterday's, and the fresh row blocked it again for a whole new
  /// cooldown window. A meal logged this morning was also offered back tonight.
  ///
  /// The row stores the *plain* meal name and `entryType: leftover`. The "leftovers"
  /// wording is applied when the row is drawn
  /// (`AppStrings.historyEntryDisplayName`), the same way `takeout` persists a key
  /// rather than a sentence: display copy in a snapshot column cannot follow the
  /// user's language.
  Future<void> _handleEatYesterdayLeftover(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final historyDao = ref.read(mealHistoryDaoProvider);
    final strings = AppStrings.of(context);
    final source = await historyDao.getRecentLeftoverSource(withinDays: 2);
    if (!context.mounted) return;

    final int historyEntryId;
    final String message;

    if (source != null) {
      historyEntryId = await controller.markLeftoverEntry(
        mealId: source.mealId,
        mealName: source.mealName,
        proteinType: source.proteinType,
        carbsType: source.carbsType,
      );
      message = strings.leftoverSuccess(source.mealName);
    } else {
      historyEntryId = await controller.markLeftoverEntry(
        mealName: MealLogKeys.leftover,
      );
      message = strings.leftoverSuccessGeneral;
    }

    if (context.mounted) {
      AppToast.showUndo(
        context,
        message: message,
        actionLabel: strings.undo,
        onUndo: () {
          controller.undoLastCookingLog(historyEntryId);
        },
      );
    }
  }

  Future<void> _handleTakeout(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final strings = AppStrings.of(context);
    final message = strings.takeoutSuccess;
    final undoLabel = strings.undo;
    final historyEntryId = await controller.markTakeout();

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
