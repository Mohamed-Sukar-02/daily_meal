import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vault_providers.dart';
import 'add_edit_meal_dialog.dart';
import 'widgets/delete_meal_dialog.dart';
import 'widgets/meal_vault_card.dart';
import 'widgets/vault_empty_state.dart';
import 'widgets/vault_filter_bar.dart';

class MealVaultScreen extends ConsumerStatefulWidget {
  const MealVaultScreen({super.key});

  @override
  ConsumerState<MealVaultScreen> createState() => _MealVaultScreenState();
}

enum VaultTab { myKitchen, discovery }

class _MealVaultScreenState extends ConsumerState<MealVaultScreen> {
  final _searchController = TextEditingController();
  VaultTab _selectedTab = VaultTab.myKitchen;

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
    final theme = Theme.of(context);

    final totalCount = allMealsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('خزانة الأكلات'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '$totalCount أكلة',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 0. Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<VaultTab>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.green; // Active tab is green
                    }
                    return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5); // Inactive is grey/white
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return theme.colorScheme.onSurfaceVariant;
                  }),
                  side: WidgetStateProperty.all(BorderSide.none), // Remove borders
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: VaultTab.myKitchen,
                    label: Text('خزنتي', style: TextStyle(fontWeight: FontWeight.bold)),
                    icon: Icon(Icons.kitchen),
                  ),
                  ButtonSegment(
                    value: VaultTab.discovery,
                    label: Text('اكتشف', style: TextStyle(fontWeight: FontWeight.bold)),
                    icon: Icon(Icons.explore),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (selected) {
                  setState(() {
                    _selectedTab = selected.first;
                  });
                },
              ),
            ),
          ),

          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              key: const Key('vault_search_field'),
              controller: _searchController,
              leading: const Icon(Icons.search),
              hintText: 'ابحث عن أكلة بالاسم...',
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    key: const Key('vault_search_clear_button'),
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(vaultFilterProvider.notifier).setSearchQuery('');
                      setState(() {});
                    },
                  ),
              ],
              onChanged: (val) {
                ref.read(vaultFilterProvider.notifier).setSearchQuery(val);
                setState(() {});
              },
            ),
          ),

          // 2. Filter Bar
          const VaultFilterBar(),

          const SizedBox(height: 6),

          // 3. Meals List or Empty State
          Expanded(
            child: filteredMealsAsync.when(
              data: (meals) {
                if (meals.isEmpty) {
                  final isFiltered = filter.hasActiveFilters;
                  return VaultEmptyState(
                    isSearchResult: isFiltered,
                    onAction: () {
                      if (isFiltered) {
                        _searchController.clear();
                        ref.read(vaultFilterProvider.notifier).resetFilters();
                        setState(() {});
                      } else {
                        AddEditMealDialog.show(context);
                      }
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 4),
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    return MealVaultCard(
                      meal: meal,
                      onEdit: () => AddEditMealDialog.show(context, mealToEdit: meal),
                      onDelete: () => DeleteMealDialog.show(context, meal),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
              error: (err, _) => Center(
                child: Text('حدث خطأ في عرض الوجبات: $err'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('vault_add_fab'),
        onPressed: () => AddEditMealDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة أكلة'),
      ),
    );
  }
}
