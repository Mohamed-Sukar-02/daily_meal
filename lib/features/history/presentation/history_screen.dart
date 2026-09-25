import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/tables/meals_table.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/nav_lifecycle.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_date_utils.dart' as app_date_utils;
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/meal_image.dart';
import '../../vault/presentation/widgets/meal_details_sheet.dart';
import '../providers/history_providers.dart';

/// Cooking log.
///
/// Lifecycle: this branch stays alive inside the shell, so the timeline would
/// otherwise stay scrolled down after every tab switch. [NavBranchReentry]
/// resets the scroll offset (UI-only) on re-entry; the history data itself is
/// never invalidated, so nothing flickers or reloads.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with NavBranchReentry {
  final ScrollController _timelineController = ScrollController();

  @override
  int get navBranchIndex => NavBranch.history;

  @override
  void resetTransientUi() => resetScroll(_timelineController);

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    watchNavReentry();
    final historyAsync = ref.watch(mealHistoryWithMealProvider);
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            strings.historyTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppPalette.textPrimary(brightness),
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            strings.historySubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.brandGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppPalette.brandGreen,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: strings.clearAllHistory,
                    icon: Icon(CupertinoIcons.delete, color: Colors.red.shade700, size: 28),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(strings.clearHistoryTitle),
                          content: Text(strings.clearHistoryConfirm),
                          actionsOverflowDirection: VerticalDirection.up,
                          actionsOverflowButtonSpacing: 8,
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(strings.cancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(strings.clearAll),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await ref.read(historyControllerProvider.notifier).clearAllHistory();
                        if (context.mounted) {
                          AppToast.showSuccess(context, strings.historyCleared);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 64,
                              color: AppPalette.textSecondary(brightness),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              strings.historyEmptyTitle,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.textPrimary(brightness),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.historyEmptyDesc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppPalette.textSecondary(brightness),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => context.go('/'),
                              icon: const Icon(Icons.home_rounded),
                              label: Text(strings.goToHome),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.brandGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Stats are "this month" (see _buildStatCard footer): filter to
                // the current month/year BEFORE counting, not all-time.
                final statsNow = DateTime.now();
                final monthEntries = entries.where((e) =>
                    e.history.cookedAt.year == statsNow.year &&
                    e.history.cookedAt.month == statsNow.month).toList();
                // Calculate stats with Arabic labels - use enum equality not string contains (optimal + type-safe)
                int chickenDays = monthEntries.where((e) => e.history.proteinType == ProteinType.chicken).length;
                int meatlessDays = monthEntries.where((e) => e.history.proteinType == ProteinType.legume || e.history.proteinType == ProteinType.none || e.history.proteinType == ProteinType.dairy).length;
                int beefDays = monthEntries.where((e) => e.history.proteinType == ProteinType.beef).length;
                int fishDays = monthEntries.where((e) => e.history.proteinType == ProteinType.fish).length;

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row - Arabic - now includes fish, optimal enum checks
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _buildStatCard(context, brightness, '🐔', strings.chicken, chickenDays, const Color(0xFFFFF3C4)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, brightness, '🐟', strings.fish, fishDays, const Color(0xFFBBDEFB)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, brightness, '🥩', strings.beef, beefDays, const Color(0xFFFFCDD2)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, brightness, '🌿', strings.veggieShort, meatlessDays, const Color(0xFFC8E6C9)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Timeline List
                      Expanded(
                        child: ListView.separated(
                          key: const Key('history_timeline_list'),
                          controller: _timelineController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final entry = entries[index].history;
                            final meal = entries[index].meal;

                            final dateStr = app_date_utils.formatHistoryDate(
                              entry.cookedAt,
                              strings: strings,
                            );

                            Color dotColor = AppPalette.brandGreen;
                            if (entry.proteinType == ProteinType.beef) {
                              dotColor = Colors.pink.shade400;
                            } else if (entry.proteinType == ProteinType.fish) {
                              dotColor = Colors.blue.shade400;
                            } else if (entry.proteinType == ProteinType.chicken) {
                              dotColor = Colors.amber.shade700;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timeline Dot & Line
                                  Column(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppPalette.card(brightness), width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: dotColor.withValues(alpha: 0.4),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (index != entries.length - 1)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          width: 2,
                                          height: 72,
                                          color: AppPalette.hairline(brightness),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppPalette.textSecondary(brightness),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          key: ValueKey('history_meal_card_${entry.id}'),
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () => MealDetailsSheet.show(
                                            context,
                                            detailsContext: MealDetailsContext.history,
                                            historyEntry: entry,
                                            meal: meal,
                                          ),
                                          child: Container(
                                          decoration: BoxDecoration(
                                            color: AppPalette.card(brightness),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: brightness == Brightness.dark
                                                    ? Colors.black.withValues(alpha: 0.3)
                                                    : AppPalette.lightTextPrimary.withValues(alpha: 0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                ClipOval(
                                                  child: MealImage(
                                                    photoPath: meal?.photoPath,
                                                    width: 48,
                                                    height: 48,
                                                    cacheWidth: 320,
                                                    fallback: Container(
                                                      width: 48,
                                                      height: 48,
                                                      color: AppPalette.tabContainer(brightness),
                                                      alignment: Alignment.center,
                                                      child: const Text('🍲', style: TextStyle(fontSize: 24)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        strings.historyEntryDisplayName(
                                                          mealName: entry.mealName,
                                                          entryType: entry.entryType.name,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 15,
                                                          color: AppPalette.textPrimary(brightness),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: dotColor.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          entry.proteinType.label(strings),
                                                          style: TextStyle(
                                                            color: dotColor,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                AppIcon(AppGlyph.chevron, color: AppPalette.textSecondary(brightness), size: 16),
                                              ],
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
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Expanded(
                child: Center(child: CircularProgressIndicator(color: AppPalette.brandGreen)),
              ),
              error: (err, _) => Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Text(strings.errorGeneric(err), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, Brightness brightness, String emoji, String title, int count, Color bgColor) {
    final isDark = brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final Color lightVibrant = bgColor;
    final Color darkAdapted = bgColor.withValues(alpha: 0.28);
    final finalBg = isDark ? darkAdapted : lightVibrant;

    return Container(
      width: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: finalBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? bgColor.withValues(alpha: 0.4)
              : AppPalette.hairline(brightness).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary(brightness).withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              strings.daysText(count),
              maxLines: 1,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            strings.thisMonth,
            style: TextStyle(
              color: AppPalette.textSecondary(brightness),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
