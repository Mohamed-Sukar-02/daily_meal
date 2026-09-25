import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/meal_image.dart';
import '../../vault/application/meal_proposal_service.dart';
import '../../vault/application/meal_sync_diff.dart';
import '../../vault/data/models/cloud_meal.dart';
import '../../vault/presentation/widgets/delete_meal_dialog.dart';
import '../../vault/presentation/widgets/meal_sync_window.dart';
import '../../vault/presentation/widgets/quick_add_sheet.dart';
import '../../vault/providers/discovery_providers.dart';
import '../../vault/providers/vault_providers.dart';
import 'widgets/meal_dish_tabs.dart';
import 'widgets/meal_info_banner.dart';
import 'widgets/meal_screen_palette.dart';
import 'widgets/more_favorites_grid.dart';

/// Full meal screen — ported from the approved `premium-flutter-meal-screen`
/// prototype, which itself follows `meal_screen - dark.png` for structure and
/// `meal_screen - light.png` for colour distribution.
///
/// Layout (top → bottom):
///   1. Solid app bar: back · centred short name · sync / favourite / actions.
///   2. Full-bleed hero photo whose bottom [_heroBleed] continues behind the
///      info card, fading into the page. The full name sits directly on it.
///   3. Green info card fused with the dish strip via the folder-tab curve.
///   4. Selected-dish panel shell · "More Favorites" grid.
///   5. Floating, deliberately empty bottom pill.
///
/// Reached at `/meal/:id` for a vault row, whose edit and delete sit behind the
/// app bar overflow. An Explore meal with no local copy opens the same screen at
/// `/meal/cloud/:cloudId`, where the cloud mark offers a download instead of a
/// sync state and the overflow is absent — there is no local row to change.
class MealScreen extends ConsumerStatefulWidget {
  /// Local vault row shown by this screen; null on the cloud-only route.
  final int? mealId;

  /// Cloud document id, set only when this meal has no local copy yet.
  final String? cloudId;

  const MealScreen({super.key, this.mealId, this.cloudId});

  @override
  ConsumerState<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends ConsumerState<MealScreen> {
  static const double _heroBleed = 110;

  MealDishTab _selectedDish = MealDishTab.main;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final cloudId = widget.cloudId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        // The app bar is solid and dark in both modes, so the status bar
        // inherits its colour and always shows light icons.
        statusBarColor: MealScreenPalette.appBar(brightness),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: MealScreenPalette.sheet(brightness),
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        key: const Key('meal_screen'),
        // The body paints this same surface, so nothing else on the screen can
        // read as a band of a different colour behind the bottom pill.
        backgroundColor: MealScreenPalette.sheet(brightness),
        body: cloudId == null
            ? _buildLocalBody(brightness, strings)
            : _buildCloudBody(cloudId, brightness, strings),
      ),
    );
  }

  Widget _buildLocalBody(Brightness brightness, AppStrings strings) {
    final mealsAsync = ref.watch(allMealsProvider);
    final isProposing =
        widget.mealId != null &&
        ref.watch(activeProposalMealIdProvider) == widget.mealId;

    return mealsAsync.when(
      data: (meals) {
        final meal = _findMeal(meals);
        if (meal == null) {
          return _NotFound(brightness: brightness, strings: strings);
        }
        return _MealBody(
          meal: meal,
          brightness: brightness,
          strings: strings,
          isProposing: isProposing,
          selectedDish: _selectedDish,
          onDishChanged: (t) => setState(() => _selectedDish = t),
          onCloudTap: isProposing || meal.cloudId != null
              ? null
              : () => runProposalFlow(context, ref, meal),
          onFavoriteTap: () => ref
              .read(vaultControllerProvider.notifier)
              .toggleFavorite(meal.id, meal.isFavorite),
          // A `/meal/:id` route always opens a real vault row, so both local
          // actions belong on it.
          onEditTap: () => _editLocalMeal(meal),
          onDeleteTap: () => _deleteLocalMeal(meal),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, _) =>
          _BodyError(brightness: brightness, strings: strings, error: error),
    );
  }

  /// Body for `/meal/cloud/:cloudId`.
  ///
  /// The route only says the caller had no local row to open with — the vault
  /// may still hold this meal, so the local list is consulted first: a match
  /// renders the local row and the mark reports its real sync state, while a
  /// miss keeps the download offer.
  Widget _buildCloudBody(
    String cloudId,
    Brightness brightness,
    AppStrings strings,
  ) {
    final localMeals =
        ref.watch(allMealsProvider).valueOrNull ?? const <Meal>[];

    return ref
        .watch(cloudMealByIdProvider(cloudId))
        .when(
          data: (cloud) {
            if (cloud == null) {
              return _NotFound(brightness: brightness, strings: strings);
            }
            final local = _findLocalCopy(localMeals, cloud);
            if (local == null) {
              return _MealBody(
                meal: _mealFromCloudMeal(cloud),
                brightness: brightness,
                strings: strings,
                isProposing: false,
                cloudOnly: true,
                selectedDish: _selectedDish,
                onDishChanged: (t) => setState(() => _selectedDish = t),
                onCloudTap: () => _downloadCloudMeal(cloud),
              );
            }
            // A row that matched on name alone still has no cloud id of its
            // own; borrowing the visited one is what lets the mark compare the
            // two copies instead of offering an upload that would duplicate it.
            final meal = local.cloudId == null
                ? local.copyWith(cloudId: drift.Value(cloud.id))
                : local;
            final isProposing =
                ref.watch(activeProposalMealIdProvider) == local.id;
            return _MealBody(
              meal: meal,
              brightness: brightness,
              strings: strings,
              isProposing: isProposing,
              cloudOnly: false,
              selectedDish: _selectedDish,
              onDishChanged: (t) => setState(() => _selectedDish = t),
              // The cloud copy exists, so the mark is the sync review, never an
              // upload proposal.
              onCloudTap: null,
              onFavoriteTap: () => ref
                  .read(vaultControllerProvider.notifier)
                  .toggleFavorite(local.id, local.isFavorite),
              // The actions edit the row the vault actually holds — never the
              // display copy above, whose borrowed `cloudId` must not be
              // written back by a save.
              onEditTap: () => _editLocalMeal(local),
              onDeleteTap: () => _deleteLocalMeal(local),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => _BodyError(
            brightness: brightness,
            strings: strings,
            error: error,
          ),
        );
  }

  /// The vault row that is this cloud meal, or null when it has no copy yet.
  ///
  /// The two passes keep [Meal.cloudId] authoritative: a detached row that only
  /// matches on name (the sync window's "download as new" leaves one behind)
  /// must never outrank the row that actually carries the cloud id.
  Meal? _findLocalCopy(List<Meal> meals, CloudMeal cloud) {
    for (final meal in meals) {
      if (meal.cloudId == cloud.id) return meal;
    }
    final name = cloud.name.trim();
    if (name.isEmpty) return null;
    for (final meal in meals) {
      if (meal.name.trim() == name) return meal;
    }
    return null;
  }

  /// Opens the shared edit sheet on [meal] — the very sheet the vault cards and
  /// the details sheet use, so prefill, validation, the unsaved-changes guard
  /// and the "updated" toast stay identical everywhere.
  ///
  /// No refresh is wired here on purpose: the sheet writes through
  /// [VaultController], [allMealsProvider] re-emits off the drift stream and
  /// this screen repaints the name, notes and photo by itself.
  void _editLocalMeal(Meal meal) {
    QuickAddSheet.show(context, mealToEdit: meal);
  }

  /// Confirms through the shared [DeleteMealDialog] — which does the write and
  /// the app-wide "deleted, log kept" toast — and only then leaves the screen:
  /// a route showing a meal that no longer exists has nothing left to show.
  Future<void> _deleteLocalMeal(Meal meal) async {
    final deleted = await DeleteMealDialog.show(context, meal);
    // `null` = cancelled, `false` = kept. The dialog only returns `true` once
    // the row is gone, so a failed write never pops the screen.
    if (deleted != true || !mounted) return;
    _leaveMealScreen(context);
  }

  /// Downloads the cloud row into the vault and swaps this screen onto the
  /// local row it just created, so the mark flips to its sync state and the
  /// back stack keeps a single entry.
  Future<void> _downloadCloudMeal(CloudMeal cloud) async {
    final strings = AppStrings.of(context);
    final localId = await ref
        .read(discoveryControllerProvider.notifier)
        .downloadMeal(cloud);
    if (!mounted) return;
    // A failed insert returns null — never claim the meal landed.
    if (localId == null) {
      AppToast.showError(context, strings.mealDownloadFailed);
      return;
    }
    AppToast.showSuccess(context, strings.mealDownloaded(cloud.name));
    context.pushReplacement('/meal/$localId');
  }

  Meal? _findMeal(List<Meal> meals) {
    for (final meal in meals) {
      if (meal.id == widget.mealId) return meal;
    }
    return null;
  }
}

/// A cloud row shaped like a local one so the screen renders it unchanged.
/// Display only — it is never written back to the database.
Meal _mealFromCloudMeal(CloudMeal cloud) {
  return Meal(
    id: -1,
    name: cloud.name,
    photoPath: cloud.imageUrl,
    proteinType: cloudProteinType(cloud.proteinType),
    carbsType: cloudCarbsType(cloud.carbsType),
    category: cloudCategory(cloud.category),
    prepTime: cloud.prepTimeMinutes,
    isFridaySpecial: cloud.isFridaySpecial,
    isBudgetFriendly: cloud.isBudgetFriendly,
    isFavorite: false,
    isStarterMeal: cloud.isStarterMeal,
    createdAt: cloud.createdAt,
    updatedAt: cloud.createdAt,
    cloudId: cloud.id,
    notes: cloud.notes,
    shortName: cloud.shortName,
  );
}

/// Menu values of the app bar's overflow button.
const String _mealActionEdit = 'edit';
const String _mealActionDelete = 'delete';

/// Leaves the meal screen: pops when something pushed it on top of another
/// route, otherwise falls back to the vault tab — a deep link opens this screen
/// as the whole stack, so there is nothing to pop.
///
/// Shared by the app bar back button and by the exit that follows a confirmed
/// delete, so both send the user back the way they came.
void _leaveMealScreen(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    context.pop();
  } else {
    context.go('/vault');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _MealBody extends StatelessWidget {
  static const double _heroBleed = _MealScreenState._heroBleed;

  final Meal meal;
  final Brightness brightness;
  final AppStrings strings;
  final bool isProposing;

  /// True when this meal exists only in the cloud, so there is no local row to
  /// love yet and the cloud mark offers a download.
  final bool cloudOnly;

  final MealDishTab selectedDish;
  final ValueChanged<MealDishTab> onDishChanged;
  final VoidCallback? onCloudTap;
  final VoidCallback? onFavoriteTap;

  /// The two local actions (shared edit sheet · shared delete confirmation).
  /// Left null for a cloud-only meal, which has no vault row to change.
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  const _MealBody({
    required this.meal,
    required this.brightness,
    required this.strings,
    required this.isProposing,
    this.cloudOnly = false,
    required this.selectedDish,
    required this.onDishChanged,
    required this.onCloudTap,
    this.onFavoriteTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = (meal.shortName?.trim().isNotEmpty == true)
        ? meal.shortName!.trim()
        : meal.name;
    final screenH = MediaQuery.sizeOf(context).height;
    final heroH = (screenH * 0.27).clamp(180.0, 225.0);
    final sheet = MealScreenPalette.sheet(brightness);

    return Column(
      children: [
        _MealAppBar(
          shortName: shortName,
          meal: meal,
          brightness: brightness,
          strings: strings,
          isProposing: isProposing,
          cloudOnly: cloudOnly,
          onCloudTap: onCloudTap,
          onFavoriteTap: onFavoriteTap,
          onEditTap: onEditTap,
          onDeleteTap: onDeleteTap,
        ),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                key: const Key('meal_screen_body'),
                physics: const ClampingScrollPhysics(),
                child: ColoredBox(
                  // The active folder tab is cut in this same colour, so the tab
                  // and the surface it stands on have to be one continuous fill.
                  color: sheet,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The photo keeps running behind the info card and dissolves
                      // into the page colour, exactly like the reference.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: heroH + _heroBleed,
                        child: ClipRect(
                          key: const Key('meal_screen_hero'),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MealImage(
                                photoPath: meal.photoPath,
                                cacheWidth: 1080,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                fallback: _HeroFallback(brightness: brightness),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: _heroBleed + 30,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        sheet.withValues(alpha: 0),
                                        sheet.withValues(alpha: 0.55),
                                        sheet,
                                      ],
                                      stops: const [0, 0.45, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: heroH,
                            child: _HeroName(
                              fullName: meal.name,
                              brightness: brightness,
                            ),
                          ),
                          _InterlockedInfoTabs(
                            meal: meal,
                            brightness: brightness,
                            selected: selectedDish,
                            onChanged: onDishChanged,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            child: _DishPanel(
                              key: const Key('meal_screen_dish_panel'),
                              tab: selectedDish,
                              meal: meal,
                              brightness: brightness,
                              strings: strings,
                            ),
                          ),
                          const SizedBox(height: 22),
                          MoreFavoritesGrid(currentMealId: meal.id),
                          SizedBox(height: _BottomBar.clearance(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // The oval floats over the list — nothing behind it.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomBar(brightness: brightness),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar: [back] · short name (true centred) · [sync] [favourite] [actions]
// ─────────────────────────────────────────────────────────────────────────────

class _MealAppBar extends StatelessWidget {
  /// Room the centred name keeps clear on both sides of the header.
  ///
  /// The trailing group is cloud · favourite · overflow. Material's icon button
  /// minimum forces the first two to 48dp each whatever [_BarButton] asks for,
  /// the overflow button is its own 40dp box and 4dp closes the group — so
  /// anything under this and a long short name would sit on top of the marks
  /// (which it already did, by 12dp, before the fourth button arrived).
  /// Symmetric so the name stays truly centred.
  static const double _trailingActionsInset = 48 + 48 + 40 + 4 + 4;

  final String shortName;
  final Meal meal;
  final Brightness brightness;
  final AppStrings strings;
  final bool isProposing;
  final bool cloudOnly;
  final VoidCallback? onCloudTap;
  final VoidCallback? onFavoriteTap;

  /// Edit / delete, offered only for a meal the vault actually holds.
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  const _MealAppBar({
    required this.shortName,
    required this.meal,
    required this.brightness,
    required this.strings,
    required this.isProposing,
    this.cloudOnly = false,
    required this.onCloudTap,
    required this.onFavoriteTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final foreground = MealScreenPalette.text(brightness);
    // A cloud-only meal has no local row: neither action, and so no button.
    final showActions =
        !cloudOnly && (onEditTap != null || onDeleteTap != null);

    return Container(
      color: MealScreenPalette.appBar(brightness),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _trailingActionsInset,
                      ),
                      child: Text(
                        shortName,
                        key: const Key('meal_screen_short_name'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _BarButton(
                      key: const Key('meal_screen_back_button'),
                      tooltip: strings.welcomeBack,
                      onTap: () => _leaveMealScreen(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    _CloudMark(
                      meal: meal,
                      brightness: brightness,
                      isProposing: isProposing,
                      cloudOnly: cloudOnly,
                      onActionTap: onCloudTap,
                    ),
                    if (onFavoriteTap != null)
                      _BarButton(
                        key: const Key('meal_screen_favorite_button'),
                        width: 40,
                        tooltip: strings.favorite,
                        onTap: onFavoriteTap,
                        child: AppIcon(
                          meal.isFavorite
                              ? AppGlyph.heartFill
                              : AppGlyph.heartOutline,
                          color: meal.isFavorite
                              ? MealScreenPalette.heart(brightness)
                              : Colors.white,
                          size: 22,
                        ),
                      ),
                    if (showActions)
                      // The local actions live behind one overflow button
                      // rather than two more glyphs: the app bar's cloud +
                      // favourite pair is the shape the mockups lock, and
                      // delete is not something to tap by accident.
                      //
                      // A `child` (not `icon`) is deliberate: PopupMenuButton
                      // then sizes the tap target from this box instead of
                      // wrapping an IconButton, and its own `constraints` knob
                      // stays free — that one constrains the menu surface, not
                      // the button.
                      PopupMenuButton<String>(
                        key: const Key('meal_screen_actions_button'),
                        tooltip: strings.mealScreenActionsMenu,
                        splashRadius: 22,
                        color: MealScreenPalette.card(brightness),
                        child: const SizedBox(
                          width: 40,
                          height: 44,
                          child: Center(
                            child: Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        onSelected: (action) {
                          if (action == _mealActionEdit) {
                            onEditTap?.call();
                          } else if (action == _mealActionDelete) {
                            onDeleteTap?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          if (onEditTap != null)
                            PopupMenuItem<String>(
                              key: const Key('meal_screen_edit_action'),
                              value: _mealActionEdit,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    AppGlyph.pencil,
                                    color: foreground,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.edit,
                                    style: TextStyle(color: foreground),
                                  ),
                                ],
                              ),
                            ),
                          if (onDeleteTap != null)
                            PopupMenuItem<String>(
                              key: const Key('meal_screen_delete_action'),
                              value: _mealActionDelete,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: errorColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.delete,
                                    style: TextStyle(color: errorColor),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  /// Tap target width; the action pair is tighter than the back button so the
  /// two glyphs read as one group.
  final double width;

  const _BarButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.width = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        iconSize: 24,
        constraints: BoxConstraints.tightFor(width: width, height: 44),
        padding: EdgeInsets.zero,
        splashColor: Colors.white.withValues(alpha: 0.12),
        icon: child,
      ),
    );
  }
}

/// The app bar cloud mark, in its four states:
///  * cloud only (Explore) → download (gold); tap copies it into the vault.
///  * local only           → upload (gold); tap starts the staging proposal.
///  * cloud copy matches   → sync (accent); nothing to do.
///  * cloud copy differs   → sync (orange); tap opens the sync window.
class _CloudMark extends StatelessWidget {
  final Meal meal;
  final Brightness brightness;
  final bool isProposing;
  final bool cloudOnly;
  final VoidCallback? onActionTap;

  const _CloudMark({
    required this.meal,
    required this.brightness,
    required this.isProposing,
    this.cloudOnly = false,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cloudOnly) {
      return _DownloadMark(brightness: brightness, onTap: onActionTap);
    }
    final cloudId = meal.cloudId;
    if (cloudId == null) {
      return _UploadMark(
        brightness: brightness,
        isProposing: isProposing,
        onTap: onActionTap,
      );
    }
    return _CloudSyncMark(meal: meal, cloudId: cloudId, brightness: brightness);
  }
}

class _DownloadMark extends ConsumerWidget {
  final Brightness brightness;
  final VoidCallback? onTap;

  const _DownloadMark({required this.brightness, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final busy = ref.watch(discoveryControllerProvider).isLoading;

    return _BarButton(
      key: const Key('meal_screen_cloud_button'),
      width: 40,
      tooltip: strings.discoveryDownload,
      onTap: busy ? null : onTap,
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : AppIcon(
              AppGlyph.cloudDown,
              color: MealScreenPalette.syncIdle(brightness),
              size: 22,
            ),
    );
  }
}

class _UploadMark extends StatelessWidget {
  final Brightness brightness;
  final bool isProposing;
  final VoidCallback? onTap;

  const _UploadMark({
    required this.brightness,
    required this.isProposing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _BarButton(
      key: const Key('meal_screen_cloud_button'),
      width: 40,
      tooltip: isProposing ? strings.proposalInProgress : strings.proposalCta,
      onTap: onTap,
      child: isProposing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : AppIcon(
              AppGlyph.cloudUp,
              color: MealScreenPalette.syncIdle(brightness),
              size: 22,
            ),
    );
  }
}

class _CloudSyncMark extends ConsumerWidget {
  final Meal meal;
  final String cloudId;
  final Brightness brightness;

  const _CloudSyncMark({
    required this.meal,
    required this.cloudId,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    // Offline, still loading or a meal the vault dropped all read as "nothing
    // to review", so the mark only turns orange on a confirmed difference.
    final cloud = ref.watch(cloudMealByIdProvider(cloudId)).valueOrNull;
    final diffs = cloud == null
        ? const <MealCloudDiff>[]
        : mealCloudDiffs(meal, cloud, strings);
    final differs = diffs.isNotEmpty;

    return _BarButton(
      key: const Key('meal_screen_cloud_button'),
      width: 40,
      tooltip: differs ? strings.syncWindowCloudHint : strings.syncStateSynced,
      onTap: differs
          ? () => showMealSyncWindow(
              context,
              ref,
              meal: meal,
              cloud: cloud!,
              diffs: diffs,
            )
          : null,
      child: AppIcon(
        AppGlyph.swap,
        color: differs
            ? MealScreenPalette.syncDiffers(brightness)
            : MealScreenPalette.syncDone(brightness),
        size: 22,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero name
// ─────────────────────────────────────────────────────────────────────────────

class _HeroName extends StatelessWidget {
  final String fullName;
  final Brightness brightness;

  const _HeroName({required this.fullName, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Align(
        alignment: rtl ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Text(
          fullName,
          key: const Key('meal_screen_full_name'),
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: MealScreenPalette.fullName(brightness),
          ),
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  final Brightness brightness;
  const _HeroFallback({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MealScreenPalette.cardBottom(brightness),
      alignment: Alignment.center,
      child: AppIcon(
        AppGlyph.pot,
        color: Colors.white.withValues(alpha: 0.55),
        size: 56,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info card + dish strip interlock: the strip tucks [MealDishTabs.overlap] up
// over the card's bottom edge, and the folder-tab curve carries the active
// segment into the page.
// ─────────────────────────────────────────────────────────────────────────────

class _InterlockedInfoTabs extends StatelessWidget {
  final Meal meal;
  final Brightness brightness;
  final MealDishTab selected;
  final ValueChanged<MealDishTab> onChanged;

  const _InterlockedInfoTabs({
    required this.meal,
    required this.brightness,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const bannerH = MealInfoBanner.height;
    const stickOut = MealDishTabs.height - MealDishTabs.overlap;

    return SizedBox(
      height: bannerH + stickOut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerH,
            child: MealInfoBanner(meal: meal, brightness: brightness),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: bannerH - MealDishTabs.overlap,
            height: MealDishTabs.height,
            child: MealDishTabs(selected: selected, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dish panel shell (per-dish content arrives with the backend)
// ─────────────────────────────────────────────────────────────────────────────

class _DishPanel extends StatelessWidget {
  final MealDishTab tab;
  final Meal meal;
  final Brightness brightness;
  final AppStrings strings;

  const _DishPanel({
    super.key,
    required this.tab,
    required this.meal,
    required this.brightness,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final notes = meal.notes?.trim() ?? '';
    final title = switch (tab) {
      MealDishTab.main => strings.mainDish,
      MealDishTab.side1 => strings.sideDish1,
      MealDishTab.side2 => strings.sideDish2,
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(tab),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MealScreenPalette.card(brightness),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MealScreenPalette.cardBorder(brightness)),
        ),
        child: tab == MealDishTab.main && notes.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(brightness: brightness, title: title),
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: MealScreenPalette.text(brightness),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(brightness: brightness, title: title),
                  const SizedBox(height: 10),
                  _Bone(brightness: brightness, widthFactor: 0.92),
                  const SizedBox(height: 8),
                  _Bone(brightness: brightness, widthFactor: 0.68),
                  const SizedBox(height: 8),
                  _Bone(brightness: brightness, widthFactor: 0.78),
                ],
              ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final Brightness brightness;
  final String title;
  const _Heading({required this.brightness, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: MealScreenPalette.muted(brightness),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final Brightness brightness;
  final double widthFactor;
  const _Bone({required this.brightness, required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: MealScreenPalette.cardBorder(brightness),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned bottom pill — deliberately empty until its content is decided (the
// Arabic sentence in the mockup is an instruction, not UI copy). It floats over
// the list with nothing behind it; the list scrolls underneath.
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  /// Pill height; its radius is half of this so the shape stays a true stadium.
  static const double _pillHeight = 53;
  static const double _topGap = 10;
  static const double _bottomGap = 14;

  /// Room the list keeps free at its end, so the last card can still scroll
  /// clear of the floating pill.
  static double clearance(BuildContext context) =>
      _topGap + _pillHeight + _bottomGap + MediaQuery.paddingOf(context).bottom;

  final Brightness brightness;
  const _BottomBar({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final isDark = MealScreenPalette.isDark(brightness);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        _topGap,
        16,
        _bottomGap + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        key: const Key('meal_screen_bottom_pill'),
        height: _pillHeight,
        padding: const EdgeInsetsDirectional.only(start: 18, end: 10),
        decoration: BoxDecoration(
          color: MealScreenPalette.bottomPill(brightness),
          borderRadius: BorderRadius.circular(_pillHeight / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Spacer(),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? MealScreenPalette.accent(
                        brightness,
                      ).withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.16),
              ),
              child: Center(
                child: AppIcon(
                  AppGlyph.externalLink,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body load failure (local stream or the single cloud read)
// ─────────────────────────────────────────────────────────────────────────────

class _BodyError extends StatelessWidget {
  final Brightness brightness;
  final AppStrings strings;
  final Object error;

  const _BodyError({
    required this.brightness,
    required this.strings,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          strings.errorGeneric(error),
          textAlign: TextAlign.center,
          style: TextStyle(color: MealScreenPalette.muted(brightness)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Not found
// ─────────────────────────────────────────────────────────────────────────────

class _NotFound extends StatelessWidget {
  final Brightness brightness;
  final AppStrings strings;

  const _NotFound({required this.brightness, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('meal_screen_not_found'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppGlyph.pot,
              color: MealScreenPalette.muted(brightness),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              strings.mealNotFound,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MealScreenPalette.muted(brightness),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => _leaveMealScreen(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(strings.close),
            ),
          ],
        ),
      ),
    );
  }
}
