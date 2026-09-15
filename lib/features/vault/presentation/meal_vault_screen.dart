import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../providers/vault_providers.dart';
import 'add_edit_meal_dialog.dart';
import 'widgets/delete_meal_dialog.dart';
import 'widgets/meal_vault_card.dart';
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
            // 1. Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خزانة الأكلات',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.textPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'احفظ أكلاتك المفضلة واطبخها في أي وقت 🧡',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppPalette.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
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

            // 2. Search bar
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
                          ref
                              .read(vaultFilterProvider.notifier)
                              .setSearchQuery(val);
                          setState(() {});
                        },
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        key: const Key('vault_search_clear_button'),
                        icon: AppIcon(
                          AppGlyph.close,
                          color: AppPalette.textSecondary(brightness),
                          size: 16,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(vaultFilterProvider.notifier)
                              .setSearchQuery('');
                          setState(() {});
                        },
                      ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),

            // 3. Filter chips
            VaultFilterBar(
              quickOnly: _quickOnly,
              onQuickChanged: (v) => setState(() => _quickOnly = v),
            ),

            const SizedBox(height: 10),

            // 4. Grid / empty state
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
                          AddEditMealDialog.show(context);
                        }
                      },
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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
                            AddEditMealDialog.show(context, mealToEdit: meal),
                        onDelete: () => DeleteMealDialog.show(context, meal),
                      );
                    },
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('vault_add_fab'),
        backgroundColor: AppPalette.brandGreen,
        elevation: 4,
        onPressed: () => AddEditMealDialog.show(context),
        child: const AppIcon(AppGlyph.plus, color: Colors.white, size: 26),
      ),
    );
  }
}
