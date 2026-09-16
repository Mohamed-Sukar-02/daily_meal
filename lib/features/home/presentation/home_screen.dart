import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
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
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(todayRecommendationsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeHeader(onProfileTap: () => context.go('/settings')),
            const SizedBox(height: 16),
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
      children: [
        RefreshIndicator(
          onRefresh: () async => ref.invalidate(todayRecommendationsProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, canSpin ? 100 : 24),
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
            bottom: 0,
            child: Container(
              color: AppPalette.background(brightness).withValues(alpha: 0.9),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: Center(
                child: SpinWheelButton(
                  onTap: () => _openSpinWheel(context, ref, meals),
                  enabled: true,
                ),
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
              'تنبيه التنوع الغذائي (مستوى ${result.relaxationLevel}): ${result.relaxationReason}',
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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppGlyph.pot,
              size: 64,
              color: AppPalette.textSecondary(brightness),
            ),
            const SizedBox(height: 16),
            Text(
              'خزنة الأكلات فارغة!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.',
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
              label: const Text('أضف أكلتك الأولى'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final brightness = Theme.of(context).brightness;

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
              'حدث خطأ في تجهيز الاقتراحات',
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
              label: const Text('إعادة المحاولة'),
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
    final historyEntryId = await controller.markCookedToday(meal);

    if (context.mounted) {
      AppToast.showUndo(
        context,
        message: 'بالهنا والشفا! تم تسجيل "${meal.name}"',
        actionLabel: 'تراجع',
        onUndo: () {
          controller.undoLastCookingLog(historyEntryId);
        },
      );
    }
  }

  Future<void> _handleLeftover(BuildContext context, WidgetRef ref, Meal meal) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final historyEntryId = await controller.markLeftover(meal);

    if (context.mounted) {
      AppToast.showUndo(
        context,
        message: 'تم تسجيل بواقي أكل "${meal.name}"',
        actionLabel: 'تراجع',
        onUndo: () {
          controller.undoLastCookingLog(historyEntryId);
        },
      );
    }
  }
}
