import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/meal_image.dart';
import '../../data/models/cloud_meal.dart';
import '../../providers/discovery_providers.dart';

/// Which screen a [MealDetailsSheet] was opened from. Controls the
/// context-specific action area (if any) rendered at the bottom.
enum MealDetailsContext {
  /// A timeline entry in the History page: base info + cooked date/day,
  /// no action buttons.
  history,

  /// A cloud meal in Vault → Explore: base info + Download/Save button.
  explore,

  /// A local meal in Vault → My Vault: base info + Edit and Delete buttons.
  vault,
}

/// Normalized display data for the three possible meal sources
/// ([Meal], [CloudMeal], [MealHistoryData]).
class _MealDetailsInfo {
  final String name;
  final String? photoPath;
  final ProteinType proteinType;
  final CarbsType carbsType;
  final int? prepTimeMinutes;
  final bool isBudgetFriendly;
  final DateTime? cookedAt;

  const _MealDetailsInfo({
    required this.name,
    this.photoPath,
    required this.proteinType,
    required this.carbsType,
    this.prepTimeMinutes,
    this.isBudgetFriendly = false,
    this.cookedAt,
  });
}

/// Unified, adaptive meal-details bottom sheet.
///
/// One sheet serves every meal surface in the app and adapts to the context
/// it was opened from:
///
///  * [MealDetailsContext.history] – photo, name, nutrition badges plus the
///    date & weekday the meal was cooked. Read-only, no buttons.
///  * [MealDetailsContext.explore] – photo, name, nutrition badges plus a
///    Download / Save-to-Vault button (disabled "saved" state when the meal
///    is already in the vault).
///  * [MealDetailsContext.vault] – photo, name, nutrition badges plus the
///    Edit and Delete action buttons (callbacks supplied by the caller).
class MealDetailsSheet extends ConsumerWidget {
  final MealDetailsContext detailsContext;

  /// Local meal (vault context; also powers the photo of a linked history
  /// entry).
  final Meal? meal;

  /// Cloud meal (explore context).
  final CloudMeal? cloudMeal;

  /// History snapshot (history context) — always preferred for the cooked
  /// date.
  final MealHistoryData? historyEntry;

  /// Explore context: `true` when [cloudMeal] already exists in the local
  /// vault, so the download button renders its saved state.
  final bool isSavedToVault;

  /// Vault context: opens the edit sheet (QuickAddSheet).
  final VoidCallback? onEdit;

  /// Vault context: opens the delete-confirmation dialog.
  final VoidCallback? onDelete;

  const MealDetailsSheet({
    super.key,
    required this.detailsContext,
    this.meal,
    this.cloudMeal,
    this.historyEntry,
    this.isSavedToVault = false,
    this.onEdit,
    this.onDelete,
  });

  /// Opens the sheet for the given [detailsContext].
  static Future<void> show(
    BuildContext context, {
    required MealDetailsContext detailsContext,
    Meal? meal,
    CloudMeal? cloudMeal,
    MealHistoryData? historyEntry,
    bool isSavedToVault = false,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MealDetailsSheet(
        detailsContext: detailsContext,
        meal: meal,
        cloudMeal: cloudMeal,
        historyEntry: historyEntry,
        isSavedToVault: isSavedToVault,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  _MealDetailsInfo _buildInfo() {
    final historyEntry = this.historyEntry;

    // Explore → cloud meal.
    if (detailsContext == MealDetailsContext.explore && cloudMeal != null) {
      final c = cloudMeal!;
      return _MealDetailsInfo(
        name: c.name,
        photoPath: c.imageUrl,
        proteinType: _mapProtein(c.proteinType),
        carbsType: _mapCarbs(c.carbsType),
        prepTimeMinutes: c.prepTimeMinutes,
        isBudgetFriendly: c.isBudgetFriendly,
      );
    }

    // Vault / History → local meal wins; the history snapshot supplies the
    // cooked date (and, when the meal was deleted, the full fallback).
    if (meal != null) {
      final m = meal!;
      return _MealDetailsInfo(
        name: m.name,
        photoPath: m.photoPath,
        proteinType: m.proteinType,
        carbsType: m.carbsType,
        prepTimeMinutes: m.prepTime,
        isBudgetFriendly: m.isBudgetFriendly,
        cookedAt: historyEntry?.cookedAt,
      );
    }

    if (historyEntry != null) {
      final h = historyEntry;
      return _MealDetailsInfo(
        name: h.mealName,
        proteinType: h.proteinType,
        carbsType: h.carbsType,
        cookedAt: h.cookedAt,
      );
    }

    // Defensive fallback — callers always provide at least one source.
    return _MealDetailsInfo(
      name: '',
      proteinType: ProteinType.none,
      carbsType: CarbsType.none,
    );
  }

  // String→enum mappings mirroring DiscoveryNotifier so the sheet displays
  // cloud meals exactly as the vault stores them.
  static ProteinType _mapProtein(String p) {
    switch (p) {
      case 'chicken':
        return ProteinType.chicken;
      case 'beef':
        return ProteinType.beef;
      case 'fish':
        return ProteinType.fish;
      case 'meatless':
        return ProteinType.legume;
      default:
        return ProteinType.none;
    }
  }

  static CarbsType _mapCarbs(String c) {
    switch (c) {
      case 'rice':
        return CarbsType.rice;
      case 'pasta':
        return CarbsType.pasta;
      case 'bread':
        return CarbsType.bread;
      default:
        return CarbsType.none;
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final info = _buildInfo();

    return Container(
      key: const Key('meal_details_sheet'),
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppPalette.hairline(brightness),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            // Wide meal photo
            SizedBox(
              height: 210,
              child: MealImage(
                photoPath: info.photoPath,
                cacheWidth: 720,
                fallback: Container(
                  color: AppPalette.tabContainer(brightness),
                  child: Center(
                    child: AppIcon(
                      AppGlyph.pot,
                      color: AppPalette.textSecondary(brightness),
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    info.name,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: AppPalette.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBadges(brightness, strings, info),
                  switch (detailsContext) {
                    MealDetailsContext.history =>
                      _buildHistorySection(context, brightness, strings, info),
                    MealDetailsContext.explore =>
                      _buildExploreSection(context, ref, brightness, strings),
                    MealDetailsContext.vault =>
                      _buildVaultSection(context, brightness, strings),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Row of nutrition badges: protein (emoji + label), carbs, prep time and
  /// the budget-friendly flag. Empty variants are skipped.
  Widget _buildBadges(
    Brightness brightness,
    AppStrings strings,
    _MealDetailsInfo info,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (info.proteinType != ProteinType.none)
          _pill(
            brightness,
            _proteinStyle(info.proteinType, brightness),
            [
              Text(info.proteinType.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                info.proteinType.label(strings),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _proteinStyle(info.proteinType, brightness).foreground,
                ),
              ),
            ],
          ),
        if (info.carbsType != CarbsType.none)
          _pill(
            brightness,
            _neutralStyle(brightness),
            [
              Text(
                info.carbsType.label(strings),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textSecondary(brightness),
                ),
              ),
            ],
            border: Border.all(color: AppPalette.hairline(brightness)),
          ),
        if (info.prepTimeMinutes != null)
          _pill(
            brightness,
            AppPalette.chipViolet(brightness),
            [
              AppIcon(
                AppGlyph.clock,
                color: AppPalette.chipViolet(brightness).foreground,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                strings.minutes(info.prepTimeMinutes!),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.chipViolet(brightness).foreground,
                ),
              ),
            ],
          ),
        if (info.isBudgetFriendly)
          _pill(
            brightness,
            AppPalette.chipGreen(brightness),
            [
              const Text('🌿', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                strings.budgetFriendly,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.chipGreen(brightness).foreground,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// History: cooked date + weekday, read-only.
  Widget _buildHistorySection(
    BuildContext context,
    Brightness brightness,
    AppStrings strings,
    _MealDetailsInfo info,
  ) {
    final cookedAt = info.cookedAt;
    if (cookedAt == null) return const SizedBox.shrink();

    final dateLabel =
        '${cookedAt.day}/${cookedAt.month}/${cookedAt.year} · ${strings.weekdayName(cookedAt.weekday)}';

    return Container(
      key: const Key('meal_details_cooked_date'),
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.tabContainer(brightness),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.hairline(brightness)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_rounded,
            size: 18,
            color: AppPalette.textSecondary(brightness),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.textPrimary(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Explore: download / save-to-vault (disabled when already saved).
  Widget _buildExploreSection(
    BuildContext context,
    WidgetRef ref,
    Brightness brightness,
    AppStrings strings,
  ) {
    final cloudMeal = this.cloudMeal;

    return SizedBox(
      key: const Key('meal_details_download_button'),
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: cloudMeal == null || isSavedToVault
            ? null
            : () => _download(context, ref),
        icon: AppIcon(
          isSavedToVault ? AppGlyph.bookmark : AppGlyph.cloudDown,
          color: Colors.white,
          size: 16,
        ),
        label: Text(
          isSavedToVault ? strings.savedInVault : strings.discoveryDownload,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isSavedToVault
              ? AppPalette.brandGreen.withValues(alpha: 0.35)
              : AppPalette.brandGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final cloudMeal = this.cloudMeal;
    if (cloudMeal == null) return;
    final strings = AppStrings.of(context);

    await ref.read(discoveryControllerProvider.notifier).downloadMeal(cloudMeal);
    if (context.mounted) {
      AppToast.showSuccess(context, strings.mealDownloaded(cloudMeal.name));
      Navigator.of(context).pop();
    }
  }

  /// Vault: Edit / Update + Delete action buttons.
  Widget _buildVaultSection(
    BuildContext context,
    Brightness brightness,
    AppStrings strings,
  ) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('meal_details_edit_button'),
              onPressed: () {
                final onEdit = this.onEdit;
                if (onEdit == null) return;
                Navigator.of(context).pop();
                onEdit();
              },
              icon: AppIcon(AppGlyph.pencil, color: Colors.white, size: 16),
              label: Text(
                strings.edit,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('meal_details_delete_button'),
              onPressed: () {
                final onDelete = this.onDelete;
                if (onDelete == null) return;
                Navigator.of(context).pop();
                onDelete();
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: Text(
                strings.delete,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _pill(
    Brightness brightness,
    ChipStyle style,
    List<Widget> children, {
    Border? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  ChipStyle _neutralStyle(Brightness b) {
    return ChipStyle(
      background: AppPalette.tabContainer(b),
      foreground: AppPalette.textSecondary(b),
    );
  }

  ChipStyle _proteinStyle(ProteinType p, Brightness b) {
    switch (p) {
      case ProteinType.chicken:
        return AppPalette.chipGold(b);
      case ProteinType.beef:
        return AppPalette.chipRose(b);
      case ProteinType.fish:
        return AppPalette.chipBlue(b);
      case ProteinType.legume:
        return AppPalette.chipGreen(b);
      case ProteinType.dairy:
        return AppPalette.chipViolet(b);
      case ProteinType.none:
        return AppPalette.chipGreen(b);
    }
  }
}
 
