import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/meal_image.dart';
import '../data/discovery_repository.dart';
import '../data/models/cloud_meal.dart';
import '../providers/discovery_providers.dart';
import '../providers/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/network_provider.dart';
import 'widgets/meal_details_sheet.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final Widget? embeddedHeader;
  final Widget? embeddedTabs;

  const DiscoveryScreen({
    super.key,
    this.isEmbedded = false,
    this.embeddedHeader,
    this.embeddedTabs,
  });

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0=Trending, 1=Admin, 2=Quick, 3=Global, 4=Saved
  bool _isFilterBarVisible = false;
  final _viewToggleLink = LayerLink();
  final _viewTogglePortal = OverlayPortalController();

  // --- Explore grid metrics (kept in sync with the tile's own layout) ---
  static const int _gridColumns = 2;
  static const double _gridGutter = 16.0;
  static const double _gridSpacing = 14.0;

  /// Tile height for a viewport of [crossAxisExtent].
  ///
  /// A cloud tile is a photo band that scales with its width plus a footer band
  /// whose height comes from its content, so no single `childAspectRatio` can
  /// describe both. The constant 0.92 this replaced was tuned for wide
  /// surfaces: it left the footer 1.7px short even at 800x600 and 86px short on
  /// a 360px phone, which is what overflowed every card in the grid.
  double _cloudTileExtent(double crossAxisExtent) {
    final tileWidth = (crossAxisExtent -
            _gridGutter * 2 -
            _gridSpacing * (_gridColumns - 1)) /
        _gridColumns;
    return tileWidth / _CloudMealCard.photoAspectRatio +
        _CloudMealCard.footerHeight;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CloudMeal> _filterCloudMeals(
      List<CloudMeal> meals, Set<String> savedCloudIds) {
    var filtered = meals;
    // Search filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((m) => m.name.toLowerCase().contains(q)).toList();
    }
    // Category filter mapping
    switch (_selectedFilterIndex) {
      case 0: // Trending — no extra filter, just show all
        break;
      case 1: // Admin — show only meals with proposedBy == null? For now show favorites
        // Keep all but could filter by isStarterMeal
        filtered = filtered.where((m) => m.isStarterMeal).toList();
        if (filtered.isEmpty) filtered = meals.take(4).toList();
        break;
      case 2: // Quick — prepTime <= 30
        filtered = filtered.where((m) => m.prepTimeMinutes <= 30).toList();
        break;
      case 3: // Global — no filter
        break;
      case 4: // Saved — already downloaded into the local vault
        filtered =
            filtered.where((m) => savedCloudIds.contains(m.id)).toList();
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final publicMealsAsync = ref.watch(publicMealsProvider);
    final allMealsAsync = ref.watch(allMealsProvider);
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);

    final Widget content = NotificationListener<ScrollNotification>(
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
      child: Consumer(
        builder: (context, ref, child) {
          final status = ref.watch(cloudAccessStatusProvider);

          return CustomScrollView(
            slivers: [
              // 1. Header — Quick Return
              if (widget.isEmbedded && widget.embeddedHeader != null)
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
                    background: widget.embeddedHeader!,
                  ),
                ),
              if (!widget.isEmbedded)
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  snap: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppPalette.background(brightness),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 75,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildStandaloneHeader(brightness),
                  ),
                ),

              // 2. Tabs + Search + Filter — sticky
              SliverAppBar(
                pinned: true,
                floating: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppPalette.background(brightness),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 0,
                expandedHeight:
                    (widget.isEmbedded ? 57.0 : 0.0) +
                        52.0 +
                        (_isFilterBarVisible ? 58.0 : 0.0),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(
                    (widget.isEmbedded ? 57.0 : 0.0) +
                        52.0 +
                        (_isFilterBarVisible ? 58.0 : 0.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isEmbedded && widget.embeddedTabs != null)
                        widget.embeddedTabs!,
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          widget.isEmbedded ? 0 : 10,
                          16,
                          10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppPalette.tabContainer(brightness),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: AppPalette.hairline(brightness),
                                  ),
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
                                        key: const Key('discovery_search_field'),
                                        controller: _searchController,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              AppPalette.textPrimary(brightness),
                                        ),
                                        decoration: InputDecoration(
                                          isCollapsed: true,
                                          border: InputBorder.none,
                                          hintText: strings.discoverySearchHint,
                                          hintStyle: TextStyle(
                                            fontSize: 14,
                                            color: AppPalette.textSecondary(
                                                brightness),
                                          ),
                                        ),
                                        onChanged: (v) =>
                                            setState(() => _searchQuery = v),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      IconButton(
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
                                          setState(() => _searchQuery = '');
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
                            _buildTuneButton(brightness),
                          ],
                        ),
                      ),
                      if (_isFilterBarVisible)
                        TapRegion(
                          groupId: 'discovery_filter_bar',
                          onTapOutside: (_) {
                            if (_isFilterBarVisible) {
                              setState(() => _isFilterBarVisible = false);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildFilterChips(brightness),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 3. Grid content
              Builder(
                builder: (context) {
                  if (status == CloudAccessStatus.noConnection) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _errorState(
                        brightness,
                        AppGlyph.cloud,
                        strings.discoveryOfflineTitle,
                        strings.discoveryOfflineDesc,
                      ),
                    );
                  }
                  if (status == CloudAccessStatus.requiresWifi) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _errorState(
                        brightness,
                        AppGlyph.cloudDown,
                        strings.discoveryWifiTitle,
                        strings.discoveryWifiDesc,
                      ),
                    );
                  }
                  return publicMealsAsync.when(
                    data: (cloudMeals) {
                      final localMeals = allMealsAsync.valueOrNull ?? [];
                      final bookmarkedCloudIds = ref.watch(savedCloudMealsProvider);
                      final filtered =
                          _filterCloudMeals(cloudMeals, bookmarkedCloudIds);
                      if (cloudMeals.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _emptyState(
                            brightness,
                            strings.discoveryEmptyTitle,
                            strings.discoveryEmptyDesc,
                          ),
                        );
                      }
                      if (filtered.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _emptyState(
                            brightness,
                            strings.vaultNoResultsTitle,
                            strings.discoveryNoResultsDesc,
                          ),
                        );
                      }
                      // The tile height is derived from the viewport width, so
                      // it is measured here rather than hardcoded as a ratio
                      // (see [_cloudTileExtent]).
                      return SliverLayoutBuilder(
                        builder: (context, viewport) => SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                              _gridGutter, 0, _gridGutter, 96),
                          sliver: ref.watch(vaultViewModeProvider)
                              ? SliverGrid.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _gridColumns,
                                    crossAxisSpacing: _gridSpacing,
                                    mainAxisSpacing: _gridSpacing,
                                    mainAxisExtent: _cloudTileExtent(
                                        viewport.crossAxisExtent),
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final cloudMeal = filtered[index];
                                    final linked = localMeals
                                        .where((m) => m.cloudId == cloudMeal.id)
                                        .toList();
                                    return _CloudMealCard(
                                      cloudMeal: cloudMeal,
                                      linkedMeal:
                                          linked.isNotEmpty ? linked.first : null,
                                      index: index,
                                    );
                                  },
                                )
                              : SliverList.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final cloudMeal = filtered[index];
                                    final linked = localMeals
                                        .where((m) => m.cloudId == cloudMeal.id)
                                        .toList();
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _CloudMealListTile(
                                        cloudMeal: cloudMeal,
                                        linkedMeal: linked.isNotEmpty
                                            ? linked.first
                                            : null,
                                        index: index,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      );
                    },
                    loading: () => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppPalette.brandGreen,
                        ),
                      ),
                    ),
                    error: (err, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: _errorState(
                        brightness,
                        AppGlyph.alert,
                        strings.discoveryError,
                        err is CloudMealsFetchException
                            ? strings.discoveryFetchFailed(err.cause)
                            : '$err',
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    if (widget.isEmbedded) return content;

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      body: SafeArea(bottom: false, child: content),
    );
  }

  Widget _buildStandaloneHeader(Brightness brightness) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Material(
            color: AppPalette.tabContainer(brightness),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.maybePop(context),
              child: SizedBox(width: 40, height: 40, child: Center(child: AppIcon(AppGlyph.chevron, color: AppPalette.textPrimary(brightness), size: 18))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.discoveryTitle, style: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness))),
                Text(strings.discoverySearchHint, style: TextStyle(fontSize: 13, color: AppPalette.textSecondary(brightness))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Brightness brightness) {
    final strings = AppStrings.of(context);
    // Mock: Trending (orange/gold) / Admin Picks (blue) / Quick Meals (green) / Global (purple)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _chip(brightness, index: 0, emoji: '🔥', label: strings.discoveryTrending, style: AppPalette.chipGold(brightness)),
          const SizedBox(width: 8),
          _chip(brightness, index: 1, emoji: '👑', label: strings.discoveryAdminPicks, style: AppPalette.chipBlue(brightness)),
          const SizedBox(width: 8),
          _chip(brightness, index: 2, emoji: '⚡', label: strings.discoveryQuickMeals, style: AppPalette.chipGreen(brightness)),
          const SizedBox(width: 8),
          _chip(brightness, index: 3, emoji: '🌍', label: strings.discoveryGlobal, style: AppPalette.chipViolet(brightness)),
          const SizedBox(width: 8),
          // Its 🔖 lives in the label, not in front of it.
          _chip(brightness, index: 4, emoji: null, label: strings.filterSaved, style: AppPalette.chipRose(brightness)),
        ],
      ),
    );
  }

  Widget _chip(Brightness brightness, {required int index, required String? emoji, required String label, required ChipStyle style}) {
    final selected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilterIndex = index;
        _isFilterBarVisible = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? style.background : AppPalette.tabContainer(brightness),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? style.foreground.withValues(alpha: 0.3) : AppPalette.hairline(brightness)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? style.foreground : AppPalette.textSecondary(brightness))),
          ],
        ),
      ),
    );
  }

  Widget _buildTuneButton(Brightness brightness) {
    final hasActiveFilter = _selectedFilterIndex != 0;
    final isExpanded = _isFilterBarVisible;

    return TapRegion(
      groupId: 'discovery_filter_bar',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            key: const Key('discovery_filter_toggle_button'),
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
                    : Border.all(color: AppPalette.hairline(brightness)),
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
                key: const Key('discovery_filter_clear_button'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedFilterIndex = 0;
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
      groupId: 'discovery_view_toggle',
      child: CompositedTransformTarget(
        link: _viewToggleLink,
        child: OverlayPortal(
          controller: _viewTogglePortal,
          overlayChildBuilder: (context) =>
              _buildViewToggleOverlay(context, brightness),
          child: GestureDetector(
            key: const Key('discovery_view_toggle_button'),
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
                border: Border.all(color: AppPalette.hairline(brightness)),
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
        groupId: 'discovery_view_toggle',
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
                  key: const Key('discovery_view_option_grid'),
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
                  key: const Key('discovery_view_option_list'),
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

  Widget _emptyState(Brightness b, String title, String subtitle) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppGlyph.cloud, color: AppPalette.textSecondary(b), size: 64),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(b))),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppPalette.textSecondary(b))),
          ],
        ),
      ),
    );
  }

  Widget _errorState(Brightness b, AppGlyph glyph, String title, String subtitle) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppPalette.tabContainer(b), shape: BoxShape.circle),
              child: Center(child: AppIcon(glyph, color: AppPalette.textSecondary(b), size: 32)),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(b))),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppPalette.textSecondary(b))),
          ],
        ),
      ),
    );
  }
}

class _CloudMealCard extends ConsumerWidget {
  final CloudMeal cloudMeal;
  final Meal? linkedMeal;
  final int index;

  const _CloudMealCard({required this.cloudMeal, this.linkedMeal, required this.index});

  /// Photo band ratio from the Explore mockups.
  static const double photoAspectRatio = 1.42;

  /// The footer band's own height: 8+10 of padding, a 20px name line, a 6px
  /// gap, the 34px badge row, a 4px gap, a 16px meta line and the 48px action
  /// row, plus 2px of slack so the shrink-to-fit guard below never has to
  /// engage at the widths the design was drawn for. [_DiscoveryScreenState]
  /// sizes the grid tile with this number, so the two must stay in sync.
  static const double footerHeight = 148.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final discoveryState = ref.watch(discoveryControllerProvider);
    final isLinked = linkedMeal != null;

    final colors = [AppPalette.brandCoral, AppPalette.brandGreen, const Color(0xFF2563EB), const Color(0xFF7C3AED)];
    final btnColor = colors[index % colors.length];

    return InkWell(
      key: ValueKey('cloud_meal_card_${cloudMeal.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => MealDetailsSheet.show(
        context,
        detailsContext: MealDetailsContext.explore,
        cloudMeal: cloudMeal,
        isSavedToVault: isLinked,
      ),
      child: Container(
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.35) : AppPalette.lightTextPrimary.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: photoAspectRatio,
            child: cloudMeal.imageUrl != null && cloudMeal.imageUrl!.isNotEmpty
                ? MealImage(photoPath: cloudMeal.imageUrl, cacheWidth: 480, fallback: _placeholder(brightness))
                : _placeholder(brightness),
          ),
          // Footer band = whatever height the photo band left over. The block
          // shrinks itself to fit that height (`scaleDown`, never clip) rather
          // than pushing past it: Arabic lines are taller than English ones and
          // the system text scale is unbounded, which is what overflowed this
          // Column by 86px on a 360px phone. At the widths the mockups were
          // drawn for the block already fits, so the guard never engages.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: LayoutBuilder(
                builder: (context, footer) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.topStart,
                  child: SizedBox(
                    // Width is locked to the card so the name and the meta line
                    // keep ellipsizing at the design's line length; only the
                    // block's height is ever scaled.
                    width: footer.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cloudMeal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _miniBadge(brightness, _proteinEmoji(cloudMeal.proteinType), _proteinStyle(cloudMeal.proteinType, brightness)),
                            const SizedBox(width: 6),
                            // The pill is the only member of this row that can
                            // give ground — the 28px badge and the 34px bookmark
                            // are fixed-size tap targets — so it absorbs the
                            // narrow-width slack (the row overflowed by 52px at
                            // 360px once the Spacer had nothing left to take).
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: _timePill(brightness, cloudMeal.prepTimeMinutes, strings),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _BookmarkCloudButton(cloudId: cloudMeal.id),
                          ],
                        ),
                        // One constant-height action slot, so the tile height
                        // [_DiscoveryScreenState] budgets for stays honest in
                        // both branches (the button still grows with text).
                        if (discoveryState.isLoading)
                          SizedBox(
                            height: 48,
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppPalette.brandGreen))),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                if (isLinked) {
                                  _showCloudMealUpdateOptions(
                                      context, ref, linkedMeal!, cloudMeal);
                                } else {
                                  final localId = await ref
                                      .read(discoveryControllerProvider.notifier)
                                      .downloadMeal(cloudMeal);
                                  if (!context.mounted) return;
                                  if (localId != null) {
                                    AppToast.showSuccess(context,
                                        strings.mealDownloaded(cloudMeal.name));
                                  } else {
                                    AppToast.showError(
                                        context, strings.mealDownloadFailed);
                                  }
                                }
                              },
                              icon: AppIcon(isLinked ? AppGlyph.swap : AppGlyph.cloudDown, color: isLinked ? AppPalette.textSecondary(brightness) : Colors.white, size: 14),
                              label: Text(isLinked ? strings.discoveryUpdate : strings.discoveryDownload, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              style: FilledButton.styleFrom(
                                backgroundColor: isLinked ? AppPalette.tabContainer(brightness) : btnColor,
                                foregroundColor: isLinked ? AppPalette.textPrimary(brightness) : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _placeholder(Brightness b) {
    return Container(
      color: AppPalette.tabContainer(b),
      child: Center(child: AppIcon(AppGlyph.cloud, color: AppPalette.textSecondary(b).withValues(alpha: 0.5), size: 36)),
    );
  }

  Widget _miniBadge(Brightness b, String emoji, ChipStyle style) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
    );
  }

  Widget _timePill(Brightness b, int minutes, AppStrings strings) {
    final style = AppPalette.chipViolet(b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppGlyph.clock, color: style.foreground, size: 12),
          const SizedBox(width: 4),
          Text(strings.minutes(minutes), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.foreground)),
        ],
      ),
    );
  }

  String _proteinEmoji(String p) {
    switch (p) {
      case 'chicken': return '🐔';
      case 'beef': return '🥩';
      case 'fish': return '🐟';
      case 'meatless': return '🫘';
      default: return '🍽️';
    }
  }

  ChipStyle _proteinStyle(String p, Brightness b) {
    switch (p) {
      case 'chicken': return AppPalette.chipGold(b);
      case 'beef': return AppPalette.chipRose(b);
      case 'fish': return AppPalette.chipBlue(b);
      case 'meatless': return AppPalette.chipGreen(b);
      default: return AppPalette.chipGreen(b);
    }
  }
}

/// Shared by [_CloudMealCard] and [_CloudMealListTile]: bottom sheet
/// offering "update existing" vs "download as new" for a linked meal.
void _showCloudMealUpdateOptions(
  BuildContext context,
  WidgetRef ref,
  Meal linkedMeal,
  CloudMeal cloudMeal,
) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.card(brightness),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 5, decoration: BoxDecoration(color: AppPalette.hairline(brightness), borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await ref
                        .read(discoveryControllerProvider.notifier)
                        .updateMeal(linkedMeal.id, cloudMeal);
                    if (!context.mounted) return;
                    if (success) {
                      AppToast.showSuccess(
                          context, strings.mealUpdatedToast(cloudMeal.name));
                    } else {
                      AppToast.showError(
                          context, strings.mealDownloadFailed);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppPalette.tabContainer(brightness), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppPalette.chipGreen(brightness).background, shape: BoxShape.circle), child: Center(child: AppIcon(AppGlyph.swap, color: AppPalette.chipGreen(brightness).foreground, size: 20))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.discoveryUpdateExistingTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness))), Text(strings.discoveryUpdateExistingDesc, style: TextStyle(fontSize: 12, color: AppPalette.textSecondary(brightness)))])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(discoveryControllerProvider.notifier)
                          .downloadAsNew(linkedMeal.id, cloudMeal);
                      if (!context.mounted) return;
                      AppToast.showSuccess(
                          context, strings.mealAddedNewCopy(cloudMeal.name));
                    } catch (_) {
                      if (!context.mounted) return;
                      AppToast.showError(
                          context, strings.mealDownloadFailed);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppPalette.tabContainer(brightness), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppPalette.chipBlue(brightness).background, shape: BoxShape.circle), child: Center(child: AppIcon(AppGlyph.plus, color: AppPalette.chipBlue(brightness).foreground, size: 20))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.discoveryAddAsNewTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness))), Text(strings.discoveryAddAsNewDesc, style: TextStyle(fontSize: 12, color: AppPalette.textSecondary(brightness)))])),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
}

/// Compact list-row variant of [_CloudMealCard] for list view.
///
/// (The grid card cannot be reused in a list: it sizes itself with
/// `Expanded`, which crashes under a `SliverList`'s unbounded height.)
class _CloudMealListTile extends ConsumerWidget {
  final CloudMeal cloudMeal;
  final Meal? linkedMeal;
  final int index;

  const _CloudMealListTile({
    required this.cloudMeal,
    this.linkedMeal,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final strings = AppStrings.of(context);
    final discoveryState = ref.watch(discoveryControllerProvider);
    final isLinked = linkedMeal != null;

    final colors = [AppPalette.brandCoral, AppPalette.brandGreen, const Color(0xFF2563EB), const Color(0xFF7C3AED)];
    final btnColor = colors[index % colors.length];

    return InkWell(
      key: ValueKey('cloud_meal_list_tile_${cloudMeal.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => MealDetailsSheet.show(
        context,
        detailsContext: MealDetailsContext.explore,
        cloudMeal: cloudMeal,
        isSavedToVault: isLinked,
      ),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.35) : AppPalette.lightTextPrimary.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: cloudMeal.imageUrl != null && cloudMeal.imageUrl!.isNotEmpty
                ? MealImage(photoPath: cloudMeal.imageUrl, width: 60, height: 60, cacheWidth: 400, fallback: _listPlaceholder(brightness))
                : _listPlaceholder(brightness),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cloudMeal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _listMiniBadge(brightness, _listProteinEmoji(cloudMeal.proteinType), _listProteinStyle(cloudMeal.proteinType, brightness)),
                    const SizedBox(width: 6),
                    Flexible(child: _listTimePill(brightness, cloudMeal.prepTimeMinutes, strings)),
                    const Spacer(),
                    _BookmarkCloudButton(cloudId: cloudMeal.id),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (discoveryState.isLoading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton.filled(
              onPressed: () async {
                if (isLinked) {
                  _showCloudMealUpdateOptions(
                      context, ref, linkedMeal!, cloudMeal);
                } else {
                  final localId = await ref
                      .read(discoveryControllerProvider.notifier)
                      .downloadMeal(cloudMeal);
                  if (!context.mounted) return;
                  if (localId != null) {
                    AppToast.showSuccess(
                        context, strings.mealDownloaded(cloudMeal.name));
                  } else {
                    AppToast.showError(context, strings.mealDownloadFailed);
                  }
                }
              },
              icon: AppIcon(isLinked ? AppGlyph.swap : AppGlyph.cloudDown, color: isLinked ? AppPalette.textSecondary(brightness) : Colors.white, size: 16),
              style: IconButton.styleFrom(backgroundColor: isLinked ? AppPalette.tabContainer(brightness) : btnColor),
              tooltip: isLinked ? strings.discoveryUpdate : strings.discoveryDownload,
            ),
        ],
      ),
      ),
    );
  }
}

Widget _listPlaceholder(Brightness b) {
  return Container(
    width: 60,
    height: 60,
    color: AppPalette.tabContainer(b),
    child: Center(child: AppIcon(AppGlyph.cloud, color: AppPalette.textSecondary(b).withValues(alpha: 0.5), size: 24)),
  );
}

Widget _listMiniBadge(Brightness b, String emoji, ChipStyle style) {
  return Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
  );
}

Widget _listTimePill(Brightness b, int minutes, AppStrings strings) {
  final style = AppPalette.chipViolet(b);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(9)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(AppGlyph.clock, color: style.foreground, size: 12),
        const SizedBox(width: 4),
        Flexible(child: Text(strings.minutes(minutes), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.foreground))),
      ],
    ),
  );
}

String _listProteinEmoji(String p) {
  switch (p) {
    case 'chicken': return '🐔';
    case 'beef': return '🥩';
    case 'fish': return '🐟';
    case 'meatless': return '🫘';
    default: return '🍽️';
  }
}

ChipStyle _listProteinStyle(String p, Brightness b) {
  switch (p) {
    case 'chicken': return AppPalette.chipGold(b);
    case 'beef': return AppPalette.chipRose(b);
    case 'fish': return AppPalette.chipBlue(b);
    case 'meatless': return AppPalette.chipGreen(b);
    default: return AppPalette.chipGreen(b);
  }
}

class _BookmarkCloudButton extends ConsumerWidget {
  final String cloudId;

  const _BookmarkCloudButton({required this.cloudId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final savedCloudIds = ref.watch(savedCloudMealsProvider);
    final isSaved = savedCloudIds.contains(cloudId);
    
    return InkWell(
      key: ValueKey('cloud_bookmark_$cloudId'),
      customBorder: const CircleBorder(),
      onTap: () {
        ref.read(savedCloudMealsProvider.notifier).toggleSaved(cloudId);
      },
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: AppIcon(
            isSaved ? AppGlyph.bookmarkFill : AppGlyph.bookmark,
            color: isSaved
                ? AppPalette.brandGreen
                : AppPalette.textSecondary(brightness),
            size: 18,
          ),
        ),
      ),
    );
  }
}
