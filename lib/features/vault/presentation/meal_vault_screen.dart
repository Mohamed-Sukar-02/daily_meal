import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/navigation/nav_lifecycle.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/providers/network_provider.dart';
import '../../../core/services/app_config_sync_service.dart';
import '../data/models/cloud_meal.dart';
import '../providers/discovery_providers.dart';
import '../providers/vault_providers.dart';
import 'discovery_screen.dart';
import 'widgets/delete_meal_dialog.dart';
import 'widgets/meal_vault_card.dart';
import 'widgets/quick_add_sheet.dart';
import 'widgets/vault_empty_state.dart';
import 'widgets/vault_filter_bar.dart';

/// Meal Vault, rebuilt from the approved mockup: big title + subtitle,
/// rounded search field, scrollable filter chips, 2-column photo grid and
/// a round green add-FAB.
///
/// Lifecycle contract (deliberately different from Home/History/Settings):
///  * The Vault **keeps** everything — the selected internal tab, the grid
///    scroll offset and the Explore browsing state — when the user navigates
///    to another bottom-nav tab and comes back. It therefore intentionally
///    does **not** use `NavBranchReentry`.
///  * The exception is internal: switching *into* "My Vault" resets that tab's
///    UI (search text + filter chips) back to its initial state, while
///    "Explore" keeps its own state untouched.
class MealVaultScreen extends ConsumerStatefulWidget {
  const MealVaultScreen({super.key});

  @override
  ConsumerState<MealVaultScreen> createState() => _MealVaultScreenState();
}

class _MealVaultScreenState extends ConsumerState<MealVaultScreen> {
  static const int _tabMyVault = 0;
  static const int _tabExplore = 1;

  final _searchController = TextEditingController();
  final _gridController = ScrollController();

  bool _quickOnly = false;
  int _tabIndex = _tabMyVault;
  bool _showTooltip = true;
  bool _isFilterBarVisible = false;
  final _viewToggleLink = LayerLink();
  final _viewTogglePortal = OverlayPortalController();

  /// "Explore" is only mounted once the user actually opens it, so opening the
  /// Vault never fires cloud requests nobody asked for. After that first visit
  /// it stays alive inside the [IndexedStack] and keeps its own state.
  bool _exploreMounted = false;

  @override
  void dispose() {
    _searchController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  /// Entering "My Vault" resets its UI-only state. `vaultFilterProvider` holds
  /// nothing but transient filter/search state — never database data — so
  /// resetting it cannot lose meals, favourites or history.
  void _resetMyVaultUi() {
    _searchController.clear();
    ref.read(vaultFilterProvider.notifier).resetFilters();
    if (_quickOnly) setState(() => _quickOnly = false);
    if (!_showTooltip) setState(() => _showTooltip = true);
    if (_isFilterBarVisible) setState(() => _isFilterBarVisible = false);
    if (_viewTogglePortal.isShowing) _viewTogglePortal.hide();
    if (_gridController.hasClients && _gridController.offset != 0) {
      _gridController.jumpTo(0);
    }
  }

  void _onTabChanged(int index) {
    if (index == _tabIndex) return;
    setState(() {
      _tabIndex = index;
      if (index == _tabExplore) _exploreMounted = true;
    });
    // Only the "My Vault" tab is reset on entry; Explore is left alone.
    if (index == _tabMyVault) _resetMyVaultUi();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final allMealsAsync = ref.watch(allMealsProvider);
    final totalCount = allMealsAsync.valueOrNull?.length ?? 0;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // When the user leaves to another bottom-nav tab and returns, restore the tooltip
    ref.listen<int>(activeNavBranchProvider, (prev, next) {
      if (next == NavBranch.vault && prev != NavBranch.vault) {
        if (!_showTooltip) {
          setState(() => _showTooltip = true);
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Both tabs live in an IndexedStack so that leaving "Explore" for
            // "My Vault" and back does not rebuild (and reset) the discovery
            // list, its search box or its scroll position.
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildMyVaultTab(
                    context,
                    strings,
                    brightness,
                    totalCount,
                    allMealsAsync.valueOrNull,
                  ),
                  if (_exploreMounted)
                    DiscoveryScreen(
                      isEmbedded: true,
                      embeddedHeader: _buildVaultHeaderWidget(
                        context,
                        strings,
                        brightness,
                        totalCount,
                        allMealsAsync.valueOrNull,
                      ),
                      embeddedTabs: _buildVaultTabsWidget(brightness),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabIndex == _tabMyVault
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        alignment: isRtl
                            ? const Alignment(-0.25, 1.0)
                            : const Alignment(0.25, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: _showTooltip
                      ? _AddIn10SecondsTooltip(
                          key: const ValueKey('vault_add_tooltip'),
                          strings: strings,
                          brightness: brightness,
                          onTap: () {
                            setState(() => _showTooltip = false);
                          },
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('vault_add_tooltip_empty'),
                        ),
                ),
                Transform.translate(
                  offset: const Offset(0, -1),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: FittedBox(
                      child: FloatingActionButton(
                        key: const Key('vault_add_fab'),
                        backgroundColor: AppPalette.brandGreen,
                        elevation: 4,
                        shape: const CircleBorder(),
                        onPressed: () {
                          if (_showTooltip) {
                            setState(() => _showTooltip = false);
                          }
                          QuickAddSheet.show(context);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            Positioned(
                              top: -5,
                              right: -7,
                              child: Transform.rotate(
                                angle: -0.18,
                                child: Image.asset(
                                  'assets/icons/add_icons_around.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildVaultHeaderWidget(
    BuildContext context,
    AppStrings strings,
    Brightness brightness,
    int totalCount,
    List<Meal>? localMeals,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  strings.vaultTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary(brightness),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                // scaleDown, not clip: on narrow screens the counter badges
                // shrink instead of throwing a RenderFlex overflow.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: _buildVaultCounter(
                    context,
                    totalCount,
                    localMeals,
                    brightness,
                    strings,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _tabIndex == _tabMyVault
                ? strings.vaultSubtitle
                : strings.vaultSubtitleExplore,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppPalette.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultTabsWidget(Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 5),
      child: _VaultTabs(
        index: _tabIndex,
        onChanged: _onTabChanged,
        brightness: brightness,
      ),
    );
  }

  Widget _buildVaultCounter(BuildContext context, int localCount, List<Meal>? localMeals, Brightness brightness, AppStrings strings) {
    final isExplore = _tabIndex == _tabExplore;
    final publicMealsAsync = ref.watch(publicMealsProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: AlignmentDirectional.centerEnd,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: !isExplore
            ? Row(
                key: const ValueKey('vault_local_count_row'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    key: const ValueKey('vault_local_count'),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.chipGreen(brightness).background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      strings.mealsCount(localCount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.chipGreen(brightness).foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildSyncDefaultsIcon(
                    context,
                    brightness,
                    strings,
                    localMeals,
                    publicMealsAsync,
                  ),
                ],
              )
              : publicMealsAsync.when(
                  data: (cloudMeals) {
                    final cloudCount = cloudMeals.length;
                    int sharedCount = 0;
                    if (localMeals != null) {
                      final localCloudIds = localMeals.map((m) => m.cloudId).where((id) => id != null).toSet();
                      sharedCount = cloudMeals.where((cm) => localCloudIds.contains(cm.id)).length;
                    }
                    final newCount = cloudMeals.length - sharedCount;

                    return Row(
                      key: const ValueKey('vault_explore_count_row'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // الجديد (beside الأصلي)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppPalette.card(brightness),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppPalette.hairline(brightness),
                            ),
                          ),
                          child: Text(
                            strings.vaultNewCount(newCount),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.brandGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // الأصلي
                        Container(
                          key: const ValueKey('vault_explore_count'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppPalette.chipGreen(brightness).background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            strings.vaultCloudCount(cloudCount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.chipGreen(brightness).foreground,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.chipGreen(brightness).background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 16,
                      child: Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.chipGreen(brightness).foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
      ),
    );
  }

  /// The "sync default meals" icon under the local counter (My Vault only).
  ///
  /// Label-free by design (the old "Sync Defaults" text crowded the header
  /// and broke the subtitle line) — the icon alone is the button, and its
  /// color reflects the live sync state:
  ///
  ///  * offline / status unknown → neutral ([AppPalette.textPrimary])
  ///  * online with starter meals still missing from the vault → sparkle
  ///    orange + a micro-badge with the number of starter meals already
  ///    synced locally (hidden while that number is 0)
  ///  * online with every cloud starter present locally → [AppPalette.brandGreen]
  Widget _buildSyncDefaultsIcon(
    BuildContext context,
    Brightness brightness,
    AppStrings strings,
    List<Meal>? localMeals,
    AsyncValue<List<CloudMeal>> publicMealsAsync,
  ) {
    final accessStatus = ref.watch(cloudAccessStatusProvider);
    // Blacklisted (user-deleted) starters never come back via sync, so they
    // don't count as "missing".
    final deletedIds = ref.watch(deletedStarterMealIdsProvider).valueOrNull;

    final cloudMeals = publicMealsAsync.valueOrNull ?? const <CloudMeal>[];
    final localList = localMeals ?? const <Meal>[];
    final localCloudIds = localList
        .map((m) => m.cloudId)
        .whereType<String>()
        .toSet();
    final localStarterCount =
        localList.where((m) => m.isStarterMeal).length;
    final missingStarterCount = cloudMeals
        .where((cm) => cm.isStarterMeal)
        .where((cm) => !localCloudIds.contains(cm.id))
        .where((cm) => deletedIds == null || !deletedIds.contains(cm.id))
        .length;

    final cloudReady =
        accessStatus == CloudAccessStatus.allowed && publicMealsAsync.hasValue;

    Color iconColor;
    int? badgeCount;
    if (!cloudReady) {
      iconColor = AppPalette.textPrimary(brightness);
    } else if (missingStarterCount > 0) {
      iconColor = const Color(0xFFFFA726); // sparkle orange
      badgeCount = localStarterCount > 0 ? localStarterCount : null;
    } else {
      iconColor = AppPalette.brandGreen;
    }

    return Tooltip(
      message: strings.syncDefaultsTooltip,
      child: InkWell(
        key: const ValueKey('vault_sync_defaults_button'),
        onTap: () async {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (!cloudReady) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.syncOffline)),
            );
            return;
          }
          
          if (missingStarterCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.syncUpToDate)),
            );
            return;
          }

          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.syncingDefaults)),
            );
            final db = ref.read(databaseProvider);
            await AppConfigSyncService.instance.manualSyncStarterMeals(db);
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.defaultsSynced)),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.defaultsSyncFailed)),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<Color?>(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              tween: ColorTween(end: iconColor),
              builder: (context, color, child) {
                return Image.asset(
                  'assets/icons/sync_icon.png',
                  width: 22,
                  height: 22,
                  color: color,
                );
              },
            ),
            if (badgeCount != null)
              Positioned(
                top: -6,
                right: -8,
                child: Container(
                  key: const ValueKey('vault_sync_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                  decoration: BoxDecoration(
                    color: AppPalette.textPrimary(brightness),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppPalette.card(brightness), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.card(brightness),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }

  // ---------------------------------------------------------------------------
  // "My Vault" tab
  // ---------------------------------------------------------------------------

  Widget _buildMyVaultTab(
    BuildContext context,
    AppStrings strings,
    Brightness brightness,
    int totalCount,
    List<Meal>? localMeals,
  ) {
    final filteredMealsAsync = ref.watch(filteredMealsProvider);
    final filter = ref.watch(vaultFilterProvider);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if ((notification is ScrollStartNotification ||
                notification is UserScrollNotification) &&
            notification.metrics.axis == Axis.vertical) {
          if (_isFilterBarVisible) {
            setState(() => _isFilterBarVisible = false);
          }
          if (_viewTogglePortal.isShowing) {
            _viewTogglePortal.hide();
          }
        }
        return false;
      },
      child: filteredMealsAsync.when(
        data: (meals) {
          final visible = _quickOnly
              ? meals.where((m) => m.prepTime <= 30).toList()
              : meals;

          return CustomScrollView(
            key: const Key('vault_grid_view'),
            controller: _gridController,
            slivers: [
              // 1. Header — Quick Return
              SliverAppBar(
                floating: true,
                pinned: false,
                snap: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppPalette.background(brightness),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 85,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildVaultHeaderWidget(
                    context,
                    strings,
                    brightness,
                    totalCount,
                    localMeals,
                  ),
                ),
              ),

              // 2. Tabs + Search + Filter — Pinned & Floating (Quick Return)
              SliverAppBar(
                pinned: true,
                floating: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppPalette.background(brightness),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 0,
                expandedHeight:
                    57.0 + 52.0 + (_isFilterBarVisible ? 58.0 : 0.0),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(
                      57.0 + 52.0 + (_isFilterBarVisible ? 58.0 : 0.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildVaultTabsWidget(brightness),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppPalette.tabContainer(brightness),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 14),
                                    AppIcon(
                                      AppGlyph.search,
                                      color:
                                          AppPalette.textSecondary(brightness),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        key: const Key('vault_search_field'),
                                        controller: _searchController,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppPalette.textPrimary(
                                              brightness),
                                        ),
                                        decoration: InputDecoration(
                                          isCollapsed: true,
                                          border: InputBorder.none,
                                          hintText: strings.vaultSearchHint,
                                          hintStyle: TextStyle(
                                            fontSize: 14,
                                            color: AppPalette.textSecondary(
                                                brightness),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          ref
                                              .read(
                                                  vaultFilterProvider.notifier)
                                              .setSearchQuery(val);
                                        },
                                      ),
                                    ),
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _searchController,
                                      builder: (context, value, child) {
                                        if (value.text.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return IconButton(
                                          key: const Key(
                                              'vault_search_clear_button'),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          icon: AppIcon(
                                            AppGlyph.close,
                                            color: AppPalette.textSecondary(
                                                brightness),
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            ref
                                                .read(vaultFilterProvider
                                                    .notifier)
                                                .setSearchQuery('');
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildViewModeButton(brightness),
                            const SizedBox(width: 8),
                            _buildTuneButton(brightness, filter),
                          ],
                        ),
                      ),
                      if (_isFilterBarVisible)
                        TapRegion(
                          groupId: 'vault_filter_bar',
                          onTapOutside: (_) {
                            if (_isFilterBarVisible) {
                              setState(() => _isFilterBarVisible = false);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VaultFilterBar(
                              quickOnly: _quickOnly,
                              onQuickChanged: (v) {
                                setState(() {
                                  _quickOnly = v;
                                  _isFilterBarVisible = false;
                                });
                              },
                              onFilterApplied: () {
                                setState(() {
                                  _isFilterBarVisible = false;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 3. Grid Content
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: VaultEmptyState(
                    isSearchResult: filter.hasActiveFilters || _quickOnly,
                    onAction: () {
                      if (filter.hasActiveFilters || _quickOnly) {
                        _searchController.clear();
                        ref.read(vaultFilterProvider.notifier).resetFilters();
                        setState(() => _quickOnly = false);
                      } else {
                        QuickAddSheet.show(context);
                      }
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: ref.watch(vaultViewModeProvider)
                      ? SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.98,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final meal = visible[index];
                            // Repaint isolation: ink splashes / heart
                            // animations repaint only their own card, never
                            // the neighbouring grid cells.
                            return RepaintBoundary(
                              child: MealVaultCard(
                                meal: meal,
                                onEdit: () => QuickAddSheet.show(
                                    context, mealToEdit: meal),
                                onDelete: () =>
                                    DeleteMealDialog.show(context, meal),
                              ),
                            );
                          },
                        )
                      : SliverList.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final meal = visible[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              // Repaint isolation (see grid branch above).
                              child: RepaintBoundary(
                                child: MealVaultListTile(
                                  meal: meal,
                                  onEdit: () => QuickAddSheet.show(
                                      context, mealToEdit: meal),
                                  onDelete: () =>
                                      DeleteMealDialog.show(context, meal),
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              strings.vaultLoadError(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textSecondary(brightness)),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTuneButton(
    Brightness brightness,
    VaultFilterState filter,
  ) {
    final hasActiveFilter = filter.hasActiveFilters || _quickOnly;
    final isExpanded = _isFilterBarVisible;

    return TapRegion(
      groupId: 'vault_filter_bar',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            key: const Key('vault_filter_toggle_button'),
            onTap: () {
              setState(() {
                _isFilterBarVisible = !_isFilterBarVisible;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isExpanded || hasActiveFilter
                    ? AppPalette.brandGreen.withValues(alpha: 0.12)
                    : AppPalette.tabContainer(brightness),
                borderRadius: BorderRadius.circular(14),
                border: isExpanded || hasActiveFilter
                    ? Border.all(
                        color: AppPalette.brandGreen.withValues(alpha: 0.45),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 24,
                color: isExpanded || hasActiveFilter
                    ? AppPalette.brandGreen
                    : AppPalette.textSecondary(brightness),
              ),
            ),
          ),
          if (hasActiveFilter && isExpanded)
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                key: const Key('vault_filter_clear_button'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(vaultFilterProvider.notifier).resetFilters();
                  setState(() {
                    _quickOnly = false;
                    _isFilterBarVisible = false;
                  });
                },
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppPalette.card(brightness),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.hairline(brightness),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 11,
                    color: AppPalette.textSecondary(brightness),
                  ),
                ),
              ),
            )
          else if (hasActiveFilter && !isExpanded)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppPalette.brandGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(Brightness brightness) {
    return TapRegion(
      groupId: 'vault_view_toggle',
      child: CompositedTransformTarget(
        link: _viewToggleLink,
        child: OverlayPortal(
          controller: _viewTogglePortal,
          overlayChildBuilder: (context) =>
              _buildViewToggleOverlay(context, brightness),
          child: GestureDetector(
            key: const Key('vault_view_toggle_button'),
            onTap: () {
              if (_viewTogglePortal.isShowing) {
                _viewTogglePortal.hide();
              } else {
                _viewTogglePortal.show();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppPalette.tabContainer(brightness),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                ref.watch(vaultViewModeProvider)
                    ? Icons.grid_view_rounded
                    : Icons.view_list_rounded,
                size: 24,
                color: AppPalette.textSecondary(brightness),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleOverlay(BuildContext context, Brightness brightness) {
    final isGridView = ref.watch(vaultViewModeProvider);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: CompositedTransformFollower(
        link: _viewToggleLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomCenter,
        followerAnchor: Alignment.topCenter,
        offset: const Offset(0, 6),
        child: TapRegion(
        groupId: 'vault_view_toggle',
        onTapOutside: (_) {
          if (_viewTogglePortal.isShowing) {
            _viewTogglePortal.hide();
          }
        },
        child: Material(
            color: Colors.transparent,
            child: Container(
              width: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppPalette.card(brightness),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppPalette.hairline(brightness),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _viewToggleOption(
                    key: const Key('vault_view_option_grid'),
                    icon: Icons.grid_view_rounded,
                    selected: isGridView,
                    brightness: brightness,
                    onTap: () {
                      ref
                          .read(vaultViewModeProvider.notifier)
                          .setGridView(true);
                      _viewTogglePortal.hide();
                    },
                  ),
                  const SizedBox(height: 4),
                  _viewToggleOption(
                    key: const Key('vault_view_option_list'),
                    icon: Icons.view_list_rounded,
                    selected: !isGridView,
                    brightness: brightness,
                    onTap: () {
                      ref
                          .read(vaultViewModeProvider.notifier)
                          .setGridView(false);
                      _viewTogglePortal.hide();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _viewToggleOption({
    required Key key,
    required IconData icon,
    required bool selected,
    required Brightness brightness,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? AppPalette.brandGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? Colors.white
              : AppPalette.textSecondary(brightness),
        ),
      ),
    );
  }
}

class _VaultTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Brightness brightness;

  const _VaultTabs({
    required this.index,
    required this.onChanged,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.hairline(brightness), width: 1),
        boxShadow: [
          BoxShadow(
            color: brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.2)
                : AppPalette.lightTextPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: _segment(
                key: const Key('vault_tab_my_vault'),
                selected: index == 0,
                assetPath: 'assets/icons/nav_vault.png',
                label: strings.vaultTabMine,
                onTap: () => onChanged(0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _segment(
                key: const Key('vault_tab_explore'),
                selected: index == 1,
                iconData: Icons.explore_rounded,
                label: strings.vaultTabExplore,
                onTap: () => onChanged(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment({
    required Key key,
    required bool selected,
    AppGlyph? glyph,
    String? assetPath,
    IconData? iconData,
    required String label,
    required VoidCallback onTap,
  }) {
    final iconColor = selected
        ? Colors.white
        : AppPalette.textSecondary(brightness);

    final Widget iconWidget;
    if (assetPath != null) {
      iconWidget = ImageIcon(
        AssetImage(assetPath),
        size: 22,
        color: iconColor,
      );
    } else if (iconData != null) {
      iconWidget = Icon(
        iconData,
        size: 22,
        color: iconColor,
      );
    } else {
      iconWidget = AppIcon(
        glyph ?? AppGlyph.vault,
        size: 22,
        color: iconColor,
      );
    }

    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 7.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.brandGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.brandGreen.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : AppPalette.textSecondary(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddIn10SecondsTooltip extends StatefulWidget {
  final AppStrings strings;
  final Brightness brightness;
  final VoidCallback onTap;

  const _AddIn10SecondsTooltip({
    super.key,
    required this.strings,
    required this.brightness,
    required this.onTap,
  });

  @override
  State<_AddIn10SecondsTooltip> createState() => _AddIn10SecondsTooltipState();
}

class _AddIn10SecondsTooltipState extends State<_AddIn10SecondsTooltip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swayController;
  late final Animation<double> _angleAnimation;

  @override
  void initState() {
    super.initState();
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Subtle, gentle sway back and forth: -0.055 rad (~ -3.1 deg) to +0.055 rad (~ +3.1 deg)
    _angleAnimation = Tween<double>(begin: -0.055, end: 0.055).animate(
      CurvedAnimation(
        parent: _swayController,
        curve: Curves.easeInOutSine,
      ),
    );

    // In widget tests, avoid repeating infinite animation loops so tester.pumpAndSettle() can complete
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _swayController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _swayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    const double tooltipWidth = 86.0;
    const double tooltipHeight = 47.0;
    const double tailHeight = 7.0;
    const double tailWidth = 14.0;
    // FAB is 64 wide. Center of FAB is 32px from the trailing edge.
    final double tailTipX = isRtl ? 32.0 : (tooltipWidth - 32.0);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _angleAnimation,
        builder: (context, child) {
          // Pivot around the tail tip (tailTipX, tooltipHeight) where it rests on the icon
          return Transform(
            transform: Matrix4.identity()
              ..translate(tailTipX, tooltipHeight)
              ..rotateZ(_angleAnimation.value)
              ..translate(-tailTipX, -tooltipHeight),
            child: child,
          );
        },
        child: SizedBox(
          width: tooltipWidth,
          height: tooltipHeight,
          child: CustomPaint(
            painter: _SpeechBubblePainter(
              tailTipX: tailTipX,
              tailWidth: tailWidth,
              tailHeight: tailHeight,
              borderRadius: 16.0,
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 6,
                right: 6,
                top: 4,
                bottom: 4 + tailHeight,
              ),
              child: Center(
                child: Text(
                  widget.strings.vaultAddIn10Seconds,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.brandGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.15,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final double tailTipX;
  final double tailWidth;
  final double tailHeight;
  final double borderRadius;
  final Color color;

  const _SpeechBubblePainter({
    required this.tailTipX,
    required this.tailWidth,
    required this.tailHeight,
    required this.borderRadius,
    required this.color,
  });

  Path _createPath(Size size) {
    final bodyHeight = size.height - tailHeight;
    final w = size.width;
    final r = borderRadius;

    final tHalf = tailWidth / 2;
    final tLeft = (tailTipX - tHalf).clamp(r, w - r - tailWidth);
    final tRight = tLeft + tailWidth;
    final tipX = tailTipX.clamp(tLeft + 2, tRight - 2);

    final path = Path();
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, bodyHeight - r);
    path.arcToPoint(Offset(w - r, bodyHeight), radius: Radius.circular(r));
    path.lineTo(tRight, bodyHeight);
    path.quadraticBezierTo(
      tRight - 1.5,
      bodyHeight + tailHeight * 0.45,
      tipX,
      size.height,
    );
    path.quadraticBezierTo(
      tLeft + 1.5,
      bodyHeight + tailHeight * 0.45,
      tLeft,
      bodyHeight,
    );
    path.lineTo(r, bodyHeight);
    path.arcToPoint(Offset(0, bodyHeight - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createPath(size);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path.shift(const Offset(0, 2.5)), shadowPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.tailTipX != tailTipX ||
        oldDelegate.tailWidth != tailWidth ||
        oldDelegate.tailHeight != tailHeight ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.color != color;
  }
}
