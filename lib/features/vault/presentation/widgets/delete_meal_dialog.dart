import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/widgets/app_toast.dart';
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
    final strings = AppStrings.of(context);

    // No forced `Directionality` here: the dialog follows the app locale set by
    // MaterialApp instead of being hard-wired to RTL.
    return AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 40),
        title: Text(
          strings.deleteMealTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.deleteMealConfirm(meal.name),
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
                      strings.deleteMealHistorySafe,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            key: const Key('meal_delete_cancel_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            key: const Key('meal_delete_confirm_button'),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () async {
              await ref.read(vaultControllerProvider.notifier).deleteMeal(meal.id);
              if (context.mounted) {
                Navigator.of(context).pop(true);
                AppToast.show(context, message: strings.mealDeletedWithHistory(meal.name), type: AppToastType.info);
              }
            },
            child: Text(strings.deleteMealTitle),
          ),
        ],
      );
  }
}
