import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../providers/vault_providers.dart';

class DeleteMealDialog extends ConsumerWidget {
  final Meal meal;

  const DeleteMealDialog({super.key, required this.meal});

  static Future<bool?> show(BuildContext context, Meal meal) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DeleteMealDialog(meal: meal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 40),
        title: const Text(
          'حذف الأكلة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من رغبتك في حذف "${meal.name}" نهائياً من خزانة الأكلات؟',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سجل الطبخ في أمان: سيتم الاحتفاظ بسجل المرات السابقة التي طبخت فيها هذه الأكلة ولن يُحذف من سجل الأكلات.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            key: const Key('meal_delete_cancel_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('meal_delete_confirm_button'),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () async {
              await ref.read(vaultControllerProvider.notifier).deleteMeal(meal.id);
              if (context.mounted) {
                Navigator.of(context).pop(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حذف "${meal.name}" مع الاحتفاظ بسجل طبخها السابق'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('حذف الأكلة'),
          ),
        ],
      ),
    );
  }
}
