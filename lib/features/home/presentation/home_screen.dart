import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../vault/presentation/discovery_screen.dart';
import '../domain/cooldown_engine.dart';
import '../providers/recommendation_provider.dart';
import 'widgets/home_action_bar.dart';
import 'widgets/home_header.dart';
import 'widgets/home_tabs.dart';
import 'widgets/meal_card.dart';
import 'widgets/spin_wheel_dialog.dart';

/// Home screen rebuilt 1:1 from the approved mockups:
/// header → segmented (My Kitchen / Discovery) → 3 recommendation cards →
/// floating action bar (بواقي الأكل / لف العجلة / توصيل).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final recsAsync = ref.watch(todayRecommendationsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeHeader(onProfileTap: () => context.go('/settings')),
            const SizedBox(height: 12),
            HomeTabs(
              index: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _tab == 0
                  ? recsAsync.when(
                      data: (result) => result.recommendations.isEmpty
                          ? _buildEmptyState(context)
                          : _buildRecommendationsView(context, result),
                      loading: () => const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                      error: (err, stack) =>
                          _buildErrorState(context, err),
                    )
                  : const DiscoveryScreen(isEmbedded: true),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _tab == 0
          ? recsAsync.maybeWhen(
              data: (result) => result.recommendations.isNotEmpty
                  ? HomeActionBar(
                      onLeftover: () =>
                          _handleLeftover(context, result.recommendations.first),
                      onDelivery: () => _showDeliverySoon(context),
                      onSpin: result.recommendations.length >= 2
                          ? () => _openSpinWheel(context, result.recommendations)
                          : null,
                      canSpin: result.recommendations.length >= 2,
                    )
                  : null,
              orElse: () => null,
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Kitchen tab
  // ---------------------------------------------------------------------------

  Widget _buildRecommendationsView(
    BuildContext context,
    RecommendationResult<Meal> result,
  ) {
    final brightness = Theme.of(context).brightness;
    final meals = result.recommendations;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(todayRecommendationsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (result.relaxationLevel > 0) ...[
            _buildRelaxationBanner(context, result, brightness),
            const SizedBox(height: 12),
          ],
          for (int i = 0; i < meals.length; i++) ...[
            MealCard(
              meal: meals[i],
              cardIndex: i,
              onCookedToday: () => _handleCookedToday(context, meals[i]),
              onLeftover: () => _handleLeftover(context, meals[i]),
            ),
            if (i < meals.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildErrorState(BuildContext context, Object error) {
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

  void _openSpinWheel(BuildContext context, List<Meal> meals) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SpinWheelDialog(
        candidates: meals,
        onWinnerCooked: (winner) => _handleCookedToday(context, winner),
      ),
    );
  }

  void _showDeliverySoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزة التوصيل قادمة قريباً!')),
    );
  }

  Future<void> _handleCookedToday(BuildContext context, Meal meal) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final historyEntryId = await controller.markCookedToday(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بالهنا والشفا! تم تسجيل "${meal.name}" في السجل.'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              controller.undoLastCookingLog(historyEntryId);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLeftover(BuildContext context, Meal meal) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final historyEntryId = await controller.markLeftover(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل بواقي أكل "${meal.name}".'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              controller.undoLastCookingLog(historyEntryId);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
