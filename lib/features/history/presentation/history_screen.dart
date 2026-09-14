import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/meal_image.dart';
import '../providers/history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(mealHistoryWithMealProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'History',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your meals journey this month',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.green[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.green[500],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'مسح السجل بالكامل',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.error),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('مسح السجل'),
                          content: const Text('هل أنت متأكد من مسح جميع سجلات الطبخ؟'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('إلغاء'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('مسح الكل'),
                            ),
                          ],
                        ),
                      );
        
                      if (confirmed == true) {
                        await ref.read(historyControllerProvider.notifier).clearAllHistory();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم مسح السجل بالكامل')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 64,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'سجل الطبخ فارغ!',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'عندما تسجل وجباتك من الصفحة الرئيسية ستظهر هنا مرتبة بالتواريخ.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
        
                // Calculate stats
                int chickenDays = entries.where((e) => e.history.proteinType.name.contains('chicken') || e.history.proteinType.name.contains('دجاج')).length;
                int meatlessDays = entries.where((e) => e.history.proteinType.name.contains('plant') || e.history.proteinType.name.contains('نباتي')).length;
                int beefDays = entries.where((e) => e.history.proteinType.name.contains('meat') || e.history.proteinType.name.contains('لحم') || e.history.proteinType.name.contains('beef')).length;
        
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _buildStatCard(context, '🐔', 'Chicken', chickenDays, const Color(0xFFFDF5E6)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, '🌿', 'Meatless', meatlessDays, const Color(0xFFE8F5E9)),
                            const SizedBox(width: 12),
                            _buildStatCard(context, '🥩', 'Beef', beefDays, const Color(0xFFFFEBEE)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Timeline List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index].history;
                            final meal = entries[index].meal;
                            
                            // Grouping dates simply by using Yesterday / May 12 etc.
                            final date = entry.cookedAt;
                            final now = DateTime.now();
                            String dateStr;
                            if (date.year == now.year && date.month == now.month && date.day == now.day) {
                              dateStr = 'Today';
                            } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
                              dateStr = 'Yesterday';
                            } else {
                              dateStr = '${date.day}/${date.month}/${date.year}';
                            }
        
                            // Determine dot color
                            Color dotColor = Colors.green;
                            if (entry.proteinType.name.contains('meat') || entry.proteinType.name.contains('لحم') || entry.proteinType.name.contains('beef')) {
                              dotColor = Colors.pink;
                            } else if (entry.proteinType.name.contains('fish') || entry.proteinType.name.contains('سمك')) {
                              dotColor = Colors.blue;
                            }
        
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timeline Dot & Line
                                  Column(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 4, right: 12),
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
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
                                          margin: const EdgeInsets.only(right: 12),
                                          width: 2,
                                          height: 80,
                                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                        ),
                                    ],
                                  ),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.all(12),
                                            leading: ClipOval(
                                              child: MealImage(
                                                photoPath: meal?.photoPath,
                                                width: 48,
                                                height: 48,
                                                cacheWidth: 144,
                                                fallback: Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: theme.colorScheme.surfaceContainerHighest,
                                                  alignment: Alignment.center,
                                                  child: const Text('🍲', style: TextStyle(fontSize: 24)),
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              entry.mealName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: dotColor.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      entry.proteinType.name,
                                                      style: TextStyle(color: dotColor, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.chevron_right),
                                              onPressed: () {},
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
              loading: () => const Expanded(child: Center(child: CircularProgressIndicator.adaptive())),
              error: (err, _) => Expanded(child: Center(child: Text('حدث خطأ: $err'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String emoji, String title, int count, Color bgColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalBg = isDark ? bgColor.withValues(alpha: 0.1) : bgColor;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: finalBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 16),
          Text(
            '$count Days',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          Text(
            'cooked this month',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
