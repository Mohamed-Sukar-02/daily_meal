import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header — Flexible to handle 1.4x on 320px (30sp scaled to 42sp = 252px)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            strings.vaultTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(brightness),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            strings.vaultSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppPalette.textSecondary(brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.chipGreen(brightness).background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      strings.mealsCount(totalCount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.chipGreen(brightness).foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 1b. Segmented tabs (My Vault / Discovery) — embedded per mock 2.2
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _VaultTabs(
                index: _tabIndex,
                onChanged: _onTabChanged,
                brightness: brightness,
              ),
            ),
            const SizedBox(height: 12),

            // Both tabs live in an IndexedStack so that leaving "Explore" for
            // "My Vault" and back does not rebuild (and reset) the discovery
            // list, its search box or its scroll position.
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildMyVaultTab(context, strings, brightness),
                  if (_exploreMounted)
                    const DiscoveryScreen(isEmbedded: true)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabIndex == _tabMyVault
          ? FloatingActionButton(
              key: const Key('vault_add_fab'),
              backgroundColor: AppPalette.brandGreen,
              elevation: 4,
              onPressed: () => QuickAddSheet.show(context),
              child: const AppIcon(AppGlyph.plus, color: Colors.white, size: 26),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // "My Vault" tab
  // ---------------------------------------------------------------------------

  Widget _buildMyVaultTab(
    BuildContext context,
    AppStrings strings,
    Brightness brightness,
  ) {
    final filteredMealsAsync = ref.watch(filteredMealsProvider);
    final filter = ref.watch(vaultFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppPalette.tabContainer(brightness),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                AppIcon(
                  AppGlyph.search,
                  color: AppPalette.textSecondary(brightness),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('vault_search_field'),
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppPalette.textPrimary(brightness),
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: strings.vaultSearchHint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppPalette.textSecondary(brightness),
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(vaultFilterProvider.notifier).setSearchQuery(val);
                      // No setState needed - provider already triggers rebuild, optimal
                    },
                  ),
                ),
                // Use ValueListenableBuilder to avoid setState on every keystroke
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      key: const Key('vault_search_clear_button'),
                      icon: AppIcon(
                        AppGlyph.close,
                        color: AppPalette.textSecondary(brightness),
                        size: 16,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(vaultFilterProvider.notifier).setSearchQuery('');
                      },
                    );
                  },
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
        VaultFilterBar(
          quickOnly: _quickOnly,
          onQuickChanged: (v) => setState(() => _quickOnly = v),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filteredMealsAsync.when(
            data: (meals) {
              final visible = _quickOnly
                  ? meals.where((m) => m.prepTime <= 30).toList()
                  : meals;

              if (visible.isEmpty) {
                final isFiltered = filter.hasActiveFilters || _quickOnly;
                return VaultEmptyState(
                  isSearchResult: isFiltered,
                  onAction: () {
                    if (isFiltered) {
                      _searchController.clear();
                      ref.read(vaultFilterProvider.notifier).resetFilters();
                      setState(() => _quickOnly = false);
                    } else {
                      QuickAddSheet.show(context);
                    }
                  },
                );
              }

              return CustomScrollView(
                key: const Key('vault_grid_view'),
                controller: _gridController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverGrid.builder(
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
                        return MealVaultCard(
                          meal: meal,
                          onEdit: () =>
                              QuickAddSheet.show(context, mealToEdit: meal),
                          onDelete: () => DeleteMealDialog.show(context, meal),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  strings.vaultLoadError(err),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.textSecondary(brightness),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VaultTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Brightness brightness;

  const _VaultTabs({required this.index, required this.onChanged, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(24),
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
                glyph: AppGlyph.vault,
                label: strings.vaultTabMine,
                onTap: () => onChanged(0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _segment(
                key: const Key('vault_tab_explore'),
                selected: index == 1,
                glyph: AppGlyph.compass,
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
    required AppGlyph glyph,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.brandGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: AppPalette.brandGreen.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(glyph, size: 20, color: selected ? Colors.white : AppPalette.textSecondary(brightness)),
              const SizedBox(width: 8),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppPalette.textSecondary(brightness))),
            ],
          ),
        ),
      ),
    );
  }
}
