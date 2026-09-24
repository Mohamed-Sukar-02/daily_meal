import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/meal_sync_diff.dart';
import '../../data/models/cloud_meal.dart';
import '../../providers/discovery_providers.dart';

/// The "sync window" — every field where the cloud copy of a meal disagrees
/// with the local row, plus the one decision that matters: take the cloud
/// version or keep the local one.
///
/// Opened from the meal screen's sync mark while it is orange.
Future<void> showMealSyncWindow(
  BuildContext context,
  WidgetRef ref, {
  required Meal meal,
  required CloudMeal cloud,
  required List<MealCloudDiff> diffs,
}) {
  final strings = AppStrings.of(context);
  final theme = Theme.of(context);
  final rtl = Directionality.of(context) == TextDirection.rtl;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('meal_sync_window'),
      icon: Icon(
        Icons.sync_rounded,
        size: 34,
        color: Theme.of(dialogContext).colorScheme.primary,
      ),
      title: Text(
        strings.syncWindowTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.syncWindowMessage,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.syncWindowLocalColumn,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Icon(
                    rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                    size: 14,
                  ),
                  Expanded(
                    child: Text(
                      strings.syncWindowCloudColumn,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final diff in diffs) _DiffRow(diff: diff, rtl: rtl),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('meal_sync_window_keep_button'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(strings.syncWindowKeep),
        ),
        FilledButton.icon(
          key: const Key('meal_sync_window_update_button'),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await ref
                .read(discoveryControllerProvider.notifier)
                .updateMeal(meal.id, cloud);
            if (context.mounted) {
              AppToast.showSuccess(context, strings.mealUpdatedToast(cloud.name));
            }
          },
          icon: const AppIcon(AppGlyph.cloudDown, color: Colors.white, size: 16),
          label: Text(
            strings.syncWindowUpdate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppPalette.brandGreen,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _DiffRow extends StatelessWidget {
  final MealCloudDiff diff;
  final bool rtl;

  const _DiffRow({required this.diff, required this.rtl});

  static const String _dash = '—';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.lineThrough,
      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diff.field,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  diff.localValue.isEmpty ? _dash : diff.localValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
              Icon(
                rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 15,
              ),
              Expanded(
                child: Text(
                  diff.cloudValue.isEmpty ? _dash : diff.cloudValue,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppPalette.brandGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
