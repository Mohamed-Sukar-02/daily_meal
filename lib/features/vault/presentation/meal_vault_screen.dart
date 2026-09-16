import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class MealVaultScreen extends ConsumerStatefulWidget {
  const MealVaultScreen({super.key});

  @override
  ConsumerState<MealVaultScreen> createState() => _MealVaultScreenState();
}

class _MealVaultScreenState extends ConsumerState<MealVaultScreen> {
  final _searchController = TextEditingController();
  bool _quickOnly = false;
  int _tabIndex = 0; // 0 = my vault, 1 = discovery (embedded)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMealsAsync = ref.watch(filteredMealsProvider);
    final allMealsAsync = ref.watch(allMealsProvider);
    final filter = ref.watch(vaultFilterProvider);
    final brightness = Theme.of(context).brightness;

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
                            'خزانة الأكلات',
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
                            'احفظ أكلاتك المفضلة واطبخها في أي وقت 🧡',
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
                      '$totalCount أكلة',
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
                onChanged: (i) => setState(() => _tabIndex = i),
                brightness: brightness,
              ),
            ),
            const SizedBox(height: 12),
            if (_tabIndex == 0) ...[
              // Vault: search + filters
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
                            hintText: 'ابحث عن أكلة بالاسم...',
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
                        'حدث خطأ في عرض الوجبات: $err',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppPalette.textSecondary(brightness),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: DiscoveryScreen(isEmbedded: true),
              ),
          ],
        ),
      ),
      floatingActionButton: _tabIndex == 0
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
}

class _VaultTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Brightness brightness;

  const _VaultTabs({required this.index, required this.onChanged, required this.brightness});

  @override
  Widget build(BuildContext context) {
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
              child: _segment(selected: index == 0, glyph: AppGlyph.vault, label: 'خزانتي', onTap: () => onChanged(0)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _segment(selected: index == 1, glyph: AppGlyph.compass, label: 'استكشاف', onTap: () => onChanged(1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment({required bool selected, required AppGlyph glyph, required String label, required VoidCallback onTap}) {
    return GestureDetector(
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
