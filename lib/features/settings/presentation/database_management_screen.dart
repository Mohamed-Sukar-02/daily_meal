import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/seed/initial_meals.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../vault/providers/vault_providers.dart';
import '../../history/providers/history_providers.dart';

class DatabaseManagementScreen extends ConsumerWidget {
  const DatabaseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMealsAsync = ref.watch(allMealsProvider);
    final historyAsync = ref.watch(mealHistoryProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      appBar: AppBar(
        backgroundColor: AppPalette.background(brightness),
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppGlyph.chevron, color: AppPalette.textPrimary(brightness), size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'إدارة قاعدة البيانات',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary(brightness),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    brightness: brightness,
                    icon: AppGlyph.vault,
                    iconColor: AppPalette.chipGreen(brightness),
                    title: 'الوجبات',
                    valueAsync: allMealsAsync.when(
                      data: (meals) => '${meals.length}',
                      loading: () => '...',
                      error: (_, __) => 'خطأ',
                    ),
                    subtitle: 'أكلة محفوظة',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    brightness: brightness,
                    icon: AppGlyph.history,
                    iconColor: AppPalette.chipBlue(brightness),
                    title: 'السجل',
                    valueAsync: historyAsync.when(
                      data: (history) => '${history.length}',
                      loading: () => '...',
                      error: (_, __) => 'خطأ',
                    ),
                    subtitle: 'سجل طبخ',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions Section
            Text(
              'إجراءات الصيانة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              brightness: brightness,
              child: Column(
                children: [
                  _ActionRow(
                    brightness: brightness,
                    glyph: AppGlyph.history,
                    style: AppPalette.chipBlue(brightness),
                    title: 'مسح سجل الطبخ',
                    subtitle: 'حذف جميع سجلات الطبخ مع الاحتفاظ بالوجبات',
                    onTap: () => _confirmClearHistory(context, ref),
                  ),
                  _divider(brightness),
                  _ActionRow(
                    brightness: brightness,
                    glyph: AppGlyph.vault,
                    style: AppPalette.chipGold(brightness),
                    title: 'إعادة تعيين الوجبات',
                    subtitle: 'حذف الوجبات الحالية وإعادة تحميل 20 وجبة مصرية',
                    onTap: () => _confirmResetMeals(context, ref),
                  ),
                  _divider(brightness),
                  _ActionRow(
                    brightness: brightness,
                    glyph: AppGlyph.alert,
                    style: ChipStyle(
                      background: Colors.red.shade50,
                      foreground: Colors.red.shade700,
                    ),
                    title: 'مسح قاعدة البيانات بالكامل',
                    subtitle: 'حذف كل الوجبات والسجل (لا يمكن التراجع)',
                    isDestructive: true,
                    onTap: () => _confirmClearAll(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info Section
            Text(
              'معلومات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              brightness: brightness,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      brightness: brightness,
                      label: 'نوع قاعدة البيانات',
                      value: 'Drift SQLite (Offline)',
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      brightness: brightness,
                      label: 'إصدار المخطط',
                      value: 'v8',
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      brightness: brightness,
                      label: 'الموقع',
                      value: 'محلي على الجهاز',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.chipGreen(brightness).background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          AppIcon(AppGlyph.shield, color: AppPalette.chipGreen(brightness).foreground, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'جميع البيانات محفوظة محلياً فقط، لا يتم إرسال أي بيانات لخوادم خارجية.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppPalette.chipGreen(brightness).foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(Brightness brightness) {
    return Divider(height: 1, thickness: 1, color: AppPalette.hairline(brightness));
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح سجل الطبخ؟'),
        content: const Text('هل أنت متأكد من حذف جميع سجلات الطبخ؟ سيتم الاحتفاظ بالوجبات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح السجل'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(mealHistoryDaoProvider).clearAllHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح سجل الطبخ بنجاح')),
        );
      }
    }
  }

  Future<void> _confirmResetMeals(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تعيين الوجبات؟'),
        content: const Text('سيتم حذف جميع وجباتك الحالية وإعادة تحميل 20 وجبة مصرية أصيلة. السجل سيبقى محفوظاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إعادة تعيين')),
        ],
      ),
    );
    if (confirmed == true) {
      final dao = ref.read(mealsDaoProvider);
      await dao.deleteAllMeals();
      await dao.insertMealsBatch(initialEgyptianMealsSeed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إعادة تعيين الوجبات إلى 20 وجبة مصرية')),
        );
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 40),
        title: const Text('مسح شامل؟'),
        content: const Text('سيتم حذف جميع الوجبات وجميع السجلات نهائياً. لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح الكل نهائياً'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(mealHistoryDaoProvider).clearAllHistory();
      await ref.read(mealsDaoProvider).deleteAllMeals();
      await ref.read(mealsDaoProvider).insertMealsBatch(initialEgyptianMealsSeed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح قاعدة البيانات وإعادة تعيينها')),
        );
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final Brightness brightness;
  final AppGlyph icon;
  final ChipStyle iconColor;
  final String title;
  final String valueAsync;
  final String subtitle;

  const _StatCard({
    required this.brightness,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.valueAsync,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconColor.background, shape: BoxShape.circle),
            child: Center(child: AppIcon(icon, color: iconColor.foreground, size: 20)),
          ),
          const SizedBox(height: 12),
          Text(
            valueAsync,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppPalette.textPrimary(brightness),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary(brightness),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppPalette.textSecondary(brightness)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Brightness brightness;
  final Widget child;
  const _Card({required this.brightness, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Brightness brightness;
  final AppGlyph glyph;
  final ChipStyle style;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionRow({
    required this.brightness,
    required this.glyph,
    required this.style,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
              child: Center(child: AppIcon(glyph, color: style.foreground, size: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDestructive ? Colors.red.shade700 : AppPalette.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppPalette.textSecondary(brightness), height: 1.3),
                  ),
                ],
              ),
            ),
            AppIcon(AppGlyph.chevron, color: AppPalette.textSecondary(brightness), size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final Brightness brightness;
  final String label;
  final String value;
  const _InfoRow({required this.brightness, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppPalette.textSecondary(brightness))),
        Flexible(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppPalette.textPrimary(brightness)),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
