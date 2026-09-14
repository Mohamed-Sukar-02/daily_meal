import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/discovery_providers.dart';
import '../providers/vault_providers.dart';
import '../data/models/cloud_meal.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/network_provider.dart';
import '../../../../core/theme/app_colors.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  
  const DiscoveryScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _searchController = TextEditingController();
  int _selectedFilterIndex = 0; // 0=Trending, 1=Admin, 2=Quick, 3=Global

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final publicMealsAsync = ref.watch(publicMealsProvider);
    final allMealsAsync = ref.watch(allMealsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Column(
      children: [
        if (!widget.isEmbedded)
          _buildStandaloneHeader(context, isDark),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            controller: _searchController,
            leading: const Icon(Icons.search),
            hintText: 'ابحث في الوصفات...',
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(
              isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
            ),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            )),
          ),
        ),

        // Filter Chips
        _buildFilterChips(context, isDark),

        // Grid Content
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final accessStatusAsync = ref.watch(cloudAccessStatusProvider);
              
              return accessStatusAsync.when(
                data: (status) {
                  if (status == CloudAccessStatus.noConnection) {
                    return _buildErrorState(context, Icons.wifi_off, 'أنت غير متصل بالإنترنت', 'يرجى التحقق من اتصالك بالشبكة للمتابعة.');
                  }
                  
                  if (status == CloudAccessStatus.requiresWifi) {
                    return _buildErrorState(context, Icons.perm_scan_wifi, 'طلب اتصال Wi-Fi', 'تم تفعيل خيار التحميل عبر الواي فاي فقط.');
                  }

                  return publicMealsAsync.when(
                    data: (cloudMeals) {
                      final localMeals = allMealsAsync.valueOrNull ?? [];
                      
                      if (cloudMeals.isEmpty) {
                        return const Center(child: Text('لا توجد أكلات في السحابة حالياً.'));
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 4, left: 16, right: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: cloudMeals.length,
                        itemBuilder: (context, index) {
                          final cloudMeal = cloudMeals[index];
                          final linkedMeals = localMeals.where((m) => m.cloudId == cloudMeal.id).toList();
                          final linkedMeal = linkedMeals.isNotEmpty ? linkedMeals.first : null;

                          return _CloudMealCard(
                            cloudMeal: cloudMeal,
                            linkedMeal: linkedMeal,
                            index: index,
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                    error: (err, st) => Center(child: Text('خطأ: $err')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                error: (err, st) => Center(child: Text('خطأ: $err')),
              );
            }
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(child: content),
    );
  }

  Widget _buildStandaloneHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Text(
            'استكشاف',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip(0, '🔥', 'تريند', isDark),
          _buildChip(1, '👑', 'مختارة', isDark),
          _buildChip(2, '⚡', 'سريعة', isDark),
          _buildChip(3, '🌍', 'عالمية', isDark),
        ],
      ),
    );
  }

  Widget _buildChip(int index, String emoji, String label, bool isDark) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilterIndex == index;
    
    // Choose color based on category
    Color activeColor;
    switch (index) {
      case 0: activeColor = AppColors.lightAccentCoral; break; // Trending -> Orange/Coral
      case 1: activeColor = const Color(0xFF2563EB); break;    // Admin -> Blue
      case 2: activeColor = AppColors.lightPrimary; break;     // Quick -> Green
      case 3: activeColor = const Color(0xFF7C3AED); break;    // Global -> Purple
      default: activeColor = theme.colorScheme.primary;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: isDark ? 0.8 : 1) : (isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? activeColor 
                : (isDark ? theme.colorScheme.outlineVariant : theme.colorScheme.outline),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _CloudMealCard extends ConsumerWidget {
  final CloudMeal cloudMeal;
  final Meal? linkedMeal;
  final int index;

  const _CloudMealCard({
    required this.cloudMeal,
    this.linkedMeal,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final discoveryState = ref.watch(discoveryControllerProvider);
    final isLinked = linkedMeal != null;
    final isDark = theme.brightness == Brightness.dark;

    // Alternating button colors (Coral, Green, Purple)
    final colors = [
      AppColors.lightAccentCoral,
      AppColors.lightPrimary,
      const Color(0xFF7C3AED),
    ];
    final btnColor = colors[index % colors.length];

    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Placeholder
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Icon(
                Icons.cloud,
                size: 40,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cloudMeal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Fake users count for UI
                  Text(
                    'أضيفت من ${1.2 + (index * 0.3)}k مستخدم',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  
                  // Download Button
                  if (discoveryState.isLoading)
                    const Center(child: CircularProgressIndicator.adaptive())
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (isLinked) {
                            _showUpdateOptions(context, ref);
                          } else {
                            ref.read(discoveryControllerProvider.notifier).downloadMeal(cloudMeal);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم تنزيل: ${cloudMeal.name}')),
                            );
                          }
                        },
                        icon: Icon(isLinked ? Icons.sync : Icons.download, size: 16),
                        label: Text(
                          isLinked ? 'تحديث' : 'تنزيل',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: isLinked ? theme.colorScheme.surfaceContainerHighest : btnColor,
                          foregroundColor: isLinked ? theme.colorScheme.onSurfaceVariant : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.update),
                title: const Text('تحديث الأكلة الموجودة'),
                subtitle: const Text('سيتم تحديث بيانات الأكلة في خزانتك بالبيانات الجديدة.'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(discoveryControllerProvider.notifier).updateMeal(linkedMeal!.id, cloudMeal);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم التحديث: ${cloudMeal.name}')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_to_photos),
                title: const Text('إضافة كنسخة جديدة'),
                subtitle: const Text('سيتم إضافة هذه الأكلة كوجبة جديدة دون مسح النسخة القديمة.'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(discoveryControllerProvider.notifier).downloadAsNew(linkedMeal!.id, cloudMeal);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تنزيل نسخة جديدة: ${cloudMeal.name}')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
