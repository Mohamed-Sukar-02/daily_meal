import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// Unified "unsaved changes" confirmation dialog.
///
/// Reused by every edit surface (QuickAddSheet, ProfileEditDialog, …) so the
/// user always sees the same wording and design before discarding unsaved
/// edits. Resolves to:
///  * `true`  — the user confirmed discarding and leaving.
///  * `false` — the user chose to keep editing (dialog cancelled).
Future<bool> showDiscardChangesDialog(BuildContext context) {
  final strings = AppStrings.of(context);
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('discard_changes_dialog'),
      icon: Icon(
        Icons.warning_amber_rounded,
        color: colorScheme.error,
        size: 40,
      ),
      title: Text(
        strings.discardChangesTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Text(
        strings.discardChangesMessage,
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          key: const Key('discard_changes_discard_button'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(strings.discardChanges),
        ),
        FilledButton(
          key: const Key('discard_changes_keep_editing_button'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(strings.keepEditing),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}
