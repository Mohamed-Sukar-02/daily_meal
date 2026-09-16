import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/tables/meals_table.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/meal_image.dart';
import '../providers/history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(mealHistoryWithMealProvider);
    final brightness = Theme.of(context).brightness;

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
                            'سجل الأكلات',
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
                            'رحلة وجباتك خلال هذا الشهر',
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
                    tooltip: 'مسح السجل بالكامل',
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Icon(Icons.delete_sweep_outlined, color: Colors.red.shade700, size: 20),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('مسح السجل'),
                          content: const Text('هل أنت متأكد من مسح جميع سجلات الطبخ؟'),
                          actionsOverflowDirection: VerticalDirection.up,
                          actionsOverflowButtonSpacing: 8,
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('إلغاء'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('مسح الكل'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await ref.read(historyControllerProvider.notifier).clearAllHistory();
                        if (context.mounted) {
                          AppToast.showSuccess(context, 'تم مسح السجل بالكامل');
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
                            AppIcon(
                              AppGlyph.history,
                              size: 64,
                              color: AppPalette.textSecondary(brightness),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'سجل الطبخ فارغ!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.textPrimary(brightness),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'عندما تسجل وجباتك من الصفحة الرئيسية ستظهر هنا مرتبة بالتواريخ.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppPalette.textSecondary(brightness),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Calculate stats with Arabic labels - use enum equality not string contains (optimal + type-safe)
                int chickenDays = entries.where((e) => e.history.proteinType == ProteinType.chicken).length;
                int meatlessDays = entries.where((e) => e.history.proteinType == ProteinType.legume || e.history.proteinType == ProteinType.none || e.history.proteinType == ProteinType.dairy).length;
                int beefDays = entries.where((e) => e.history.proteinType == ProteinType.beef).length;
                int fishDays = entries.where((e) => e.history.proteinType == ProteinType.fish).length;

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
                            _buildStatCard(context, brightness, '🐔', 'فراخ', chickenDays, const Color(0xFFFDF5E6)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, brightness, '🐟', 'سمك', fishDays, const Color(0xFFE3F0FD)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, brightness, '🥩', 'لحمة', beefDays, const Color(0xFFFFEBEE)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, brightness, '🌿', 'نباتي', meatlessDays, const Color(0xFFE8F5E9)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Timeline List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final entry = entries[index].history;
                            final meal = entries[index].meal;

                            final date = entry.cookedAt;
                            final now = DateTime.now();
                            String dateStr;
                            if (date.year == now.year && date.month == now.month && date.day == now.day) {
                              dateStr = 'اليوم';
                            } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
                              dateStr = 'أمس';
                            } else {
                              dateStr = '${date.day}/${date.month}/${date.year}';
                            }

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
                                        Container(
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
                                                    cacheWidth: 144,
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
                                                        entry.mealName,
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
                                                          entry.proteinType.labelArabic,
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
                    child: Text('حدث خطأ: $err', textAlign: TextAlign.center),
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
    final finalBg = isDark ? bgColor.withValues(alpha: 0.12) : bgColor;
    return Container(
      width: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: finalBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.hairline(brightness).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count يوم',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppPalette.textPrimary(brightness).withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'هذا الشهر',
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
