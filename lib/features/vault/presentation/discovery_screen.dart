import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/meal_image.dart';
import '../data/models/cloud_meal.dart';
import '../providers/discovery_providers.dart';
import '../providers/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/network_provider.dart';

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
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0=Trending, 1=Admin, 2=Quick, 3=Global

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CloudMeal> _filterCloudMeals(List<CloudMeal> meals) {
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
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final publicMealsAsync = ref.watch(publicMealsProvider);
    final allMealsAsync = ref.watch(allMealsProvider);
    final brightness = Theme.of(context).brightness;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isEmbedded) _buildStandaloneHeader(brightness),
        // Search bar — mock uses English placeholder, pill shape like vault
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppPalette.tabContainer(brightness),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.hairline(brightness)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                AppIcon(AppGlyph.search, color: AppPalette.textSecondary(brightness), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 14, color: AppPalette.textPrimary(brightness)),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search for meals, cuisines, or ingredients...',
                      hintStyle: TextStyle(fontSize: 14, color: AppPalette.textSecondary(brightness)),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: AppIcon(AppGlyph.close, color: AppPalette.textSecondary(brightness), size: 16),
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
        _buildFilterChips(brightness),
        const SizedBox(height: 10),
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              // Optimal: cloudAccessStatusProvider now is synchronous Provider watching connectivity stream
              final status = ref.watch(cloudAccessStatusProvider);
              if (status == CloudAccessStatus.noConnection) {
                return _errorState(brightness, AppGlyph.cloud, 'أنت غير متصل بالإنترنت', 'تحقّق من اتصالك بالشبكة لمشاهدة الوصفات السحابية.');
              }
              if (status == CloudAccessStatus.requiresWifi) {
                return _errorState(brightness, AppGlyph.cloudDown, 'مطلوب اتصال Wi-Fi', 'فعّلت خيار التحميل عبر الواي فاي فقط.');
              }
              return publicMealsAsync.when(
                data: (cloudMeals) {
                  final filtered = _filterCloudMeals(cloudMeals);
                  if (cloudMeals.isEmpty) {
                    return _emptyState(brightness, 'لا توجد وصفات سحابية حالياً', 'جرّب لاحقاً أو أضف وصفاتك الخاصة.');
                  }
                  if (filtered.isEmpty) {
                    return _emptyState(brightness, 'لا توجد نتائج مطابقة', 'جرّب كلمات بحث مختلفة أو غيّر الفلتر.');
                  }
                  final localMeals = allMealsAsync.valueOrNull ?? [];
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cloudMeal = filtered[index];
                      final linked = localMeals.where((m) => m.cloudId == cloudMeal.id).toList();
                      return _CloudMealCard(
                        cloudMeal: cloudMeal,
                        linkedMeal: linked.isNotEmpty ? linked.first : null,
                        index: index,
                      );
                    },
                  );
                },
                loading: () => Center(child: CircularProgressIndicator(color: AppPalette.brandGreen)),
                error: (err, _) => _errorState(brightness, AppGlyph.alert, 'حدث خطأ', '$err'),
              );
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) return content;

    return Scaffold(
      backgroundColor: AppPalette.background(brightness),
      body: SafeArea(bottom: false, child: content),
    );
  }

  Widget _buildStandaloneHeader(Brightness brightness) {
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
                Text('Discover', style: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness))),
                Text('Search for meals, cuisines, or ingredients...', style: TextStyle(fontSize: 13, color: AppPalette.textSecondary(brightness))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Brightness brightness) {
    // Mock: Trending (orange/gold) / Admin Picks (blue) / Quick Meals (green) / Global (purple)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _chip(brightness, index: 0, emoji: '🔥', label: 'Trending', style: AppPalette.chipGold(brightness)),
          const SizedBox(width: 8),
          _chip(brightness, index: 1, emoji: '👑', label: 'Admin Picks', style: AppPalette.chipBlue(brightness)),
          const SizedBox(width: 8),
          _chip(brightness, index: 2, emoji: '⚡', label: 'Quick Meals', style: AppPalette.chipGreen(brightness)),
          const SizedBox(width: 8),
          _chip(brightness, index: 3, emoji: '🌍', label: 'Global', style: AppPalette.chipViolet(brightness)),
        ],
      ),
    );
  }

  Widget _chip(Brightness brightness, {required int index, required String emoji, required String label, required ChipStyle style}) {
    final selected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
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
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? style.foreground : AppPalette.textSecondary(brightness))),
          ],
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final discoveryState = ref.watch(discoveryControllerProvider);
    final isLinked = linkedMeal != null;

    final colors = [AppPalette.brandCoral, AppPalette.brandGreen, const Color(0xFF2563EB), const Color(0xFF7C3AED)];
    final btnColor = colors[index % colors.length];

    return Container(
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
            aspectRatio: 1.42,
            child: cloudMeal.imageUrl != null && cloudMeal.imageUrl!.isNotEmpty
                ? MealImage(photoPath: cloudMeal.imageUrl, cacheWidth: 480, fallback: _placeholder(brightness))
                : _placeholder(brightness),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
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
                      _timePill(brightness, cloudMeal.prepTimeMinutes),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('أضيفت من ${1.2 + (index * 0.3)}k مستخدم', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppPalette.textSecondary(brightness))),
                  const Spacer(),
                  if (discoveryState.isLoading)
                    Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppPalette.brandGreen)))
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (isLinked) {
                            _showUpdateOptions(context, ref);
                          } else {
                            ref.read(discoveryControllerProvider.notifier).downloadMeal(cloudMeal);
                            AppToast.showSuccess(context, 'تم تنزيل: ${cloudMeal.name}');
                          }
                        },
                        icon: AppIcon(isLinked ? AppGlyph.swap : AppGlyph.cloudDown, color: isLinked ? AppPalette.textSecondary(brightness) : Colors.white, size: 14),
                        label: Text(isLinked ? 'تحديث' : 'تنزيل', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
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
        ],
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

  Widget _timePill(Brightness b, int minutes) {
    final style = AppPalette.chipViolet(b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppGlyph.clock, color: style.foreground, size: 12),
          const SizedBox(width: 4),
          Text(_formatPrep(minutes), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.foreground)),
        ],
      ),
    );
  }

  String _formatPrep(int m) => m <= 10 ? '$m دقائق' : '$m دقيقة';

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

  void _showUpdateOptions(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
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
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(discoveryControllerProvider.notifier).updateMeal(linkedMeal!.id, cloudMeal);
                    AppToast.showSuccess(context, 'تم التحديث: ${cloudMeal.name}');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppPalette.tabContainer(brightness), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppPalette.chipGreen(brightness).background, shape: BoxShape.circle), child: Center(child: AppIcon(AppGlyph.swap, color: AppPalette.chipGreen(brightness).foreground, size: 20))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تحديث الأكلة الموجودة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness))), Text('سيتم تحديث بيانات الأكلة في خزانتك بالبيانات الجديدة.', style: TextStyle(fontSize: 12, color: AppPalette.textSecondary(brightness)))])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(discoveryControllerProvider.notifier).downloadAsNew(linkedMeal!.id, cloudMeal);
                    AppToast.showSuccess(context, 'تم تنزيل نسخة جديدة: ${cloudMeal.name}');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppPalette.tabContainer(brightness), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppPalette.chipBlue(brightness).background, shape: BoxShape.circle), child: Center(child: AppIcon(AppGlyph.plus, color: AppPalette.chipBlue(brightness).foreground, size: 20))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('إضافة كنسخة جديدة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppPalette.textPrimary(brightness))), Text('سيتم إضافة هذه الأكلة كوجبة جديدة دون مسح النسخة القديمة.', style: TextStyle(fontSize: 12, color: AppPalette.textSecondary(brightness)))])),
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
}
