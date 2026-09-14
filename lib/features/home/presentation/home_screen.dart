import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../domain/cooldown_engine.dart';
import '../providers/recommendation_provider.dart';
import 'widgets/meal_card.dart';
import 'widgets/spin_wheel_dialog.dart';
import 'widgets/chef_hat_painter.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recsAsync = ref.watch(todayRecommendationsProvider);

    return Scaffold(
      body: SafeArea(
        child: recsAsync.when(
        data: (result) {
          if (result.recommendations.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildRecommendationsView(context, ref, result);
        },
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        error: (err, stack) => _buildErrorState(context, ref, err),
      ),
      ),
      bottomNavigationBar: recsAsync.maybeWhen(
        data: (result) => result.recommendations.isNotEmpty
            ? _buildBottomActionBar(context, ref, result.recommendations)
            : null,
        orElse: () => null,
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, WidgetRef ref, List<Meal> meals) {
    final theme = Theme.of(context);
    final canSpin = meals.length >= 2;
    final isDark = theme.brightness == Brightness.dark;
    
    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Background bar
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Expanded(child: SizedBox()), // Right side empty
                const SizedBox(width: 80), // Center space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (meals.isNotEmpty) {
                          _handleLeftover(context, ref, meals.first);
                        }
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('بواقي أكل', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Center Protruding Wheel
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: canSpin
                  ? () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => SpinWheelDialog(
                          candidates: meals,
                          onWinnerCooked: (winner) =>
                              _handleCookedToday(context, ref, winner),
                        ),
                      );
                    }
                  : null,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFFF3B30),
                      Color(0xFFFF9500),
                      Color(0xFFFFCC00),
                      Color(0xFF4CD964),
                      Color(0xFF5AC8FA),
                      Color(0xFF007AFF),
                      Color(0xFF5856D6),
                      Color(0xFFFF3B30),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 4,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'لف\nالعجلة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.soup_kitchen_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'خزنة الأكلات فارغة!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/vault'),
              icon: const Icon(Icons.add),
              label: const Text('أضف أكلتك الأولى'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تجهيز الاقتراحات',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(todayRecommendationsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsView(
    BuildContext context,
    WidgetRef ref,
    RecommendationResult<Meal> result,
  ) {
    final theme = Theme.of(context);
    final meals = result.recommendations;
    final canSpin = meals.length >= 2;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(todayRecommendationsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // 1. Header with greeting and Spin the Wheel CTA
          _buildGreetingHeader(context, ref, meals, canSpin),

          const SizedBox(height: 16),

          // 2. Status / Relaxation Banner (when fallback cascade is active)
          if (result.relaxationLevel > 0) ...[
            _buildRelaxationBanner(context, result),
            const SizedBox(height: 16),
          ],

          // 3. Section Title
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'اقتراحات النهاردة المختارة لك:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. 3-Card Suggestion Stack
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
    );
  }

  Widget _buildGreetingHeader(
    BuildContext context,
    WidgetRef ref,
    List<Meal> meals,
    bool canSpin,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(28, 28),
                painter: ChefHatPainter(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'أكلة النهاردة',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.auto_awesome, color: Colors.orange, size: 24),
                  ],
                ),
                Text(
                  'كل يوم فكرة جديدة .. على قدك',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            radius: 24,
            child: const Icon(Icons.person, color: Colors.grey, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationBanner(
    BuildContext context,
    RecommendationResult<Meal> result,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onTertiaryContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه التنوع الغذائي (مستوى ${result.relaxationLevel})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.relaxationReason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCookedToday(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
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

  Future<void> _handleLeftover(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
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
