import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../providers/vault_providers.dart';

class AddEditMealDialog extends ConsumerStatefulWidget {
  final Meal? mealToEdit;

  const AddEditMealDialog({super.key, this.mealToEdit});

  static Future<void> show(BuildContext context, {Meal? mealToEdit}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddEditMealDialog(mealToEdit: mealToEdit),
    );
  }

  @override
  ConsumerState<AddEditMealDialog> createState() => _AddEditMealDialogState();
}

class _AddEditMealDialogState extends ConsumerState<AddEditMealDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _prepTimeController;

  late MealCategory _selectedCategory;
  late ProteinType _selectedProtein;
  late CarbsType _selectedCarbs;
  late bool _isFridaySpecial;
  late bool _isBudgetFriendly;
  late bool _isFavorite;
  String? _photoPath;

  bool get isEditing => widget.mealToEdit != null;

  @override
  void initState() {
    super.initState();
    final meal = widget.mealToEdit;
    _nameController = TextEditingController(text: meal?.name ?? '');
    _prepTimeController =
        TextEditingController(text: meal?.prepTime.toString() ?? '30');

    _selectedCategory = meal?.category ?? MealCategory.egyptianTraditional;
    _selectedProtein = meal?.proteinType ?? ProteinType.beef;
    _selectedCarbs = meal?.carbsType ?? CarbsType.rice;
    _isFridaySpecial = meal?.isFridaySpecial ?? false;
    _isBudgetFriendly = meal?.isBudgetFriendly ?? false;
    _isFavorite = meal?.isFavorite ?? false;
    _photoPath = meal?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final prepMinutes = int.parse(_prepTimeController.text.trim());

    try {
      if (isEditing) {
        final updatedMeal = widget.mealToEdit!.copyWith(
          name: name,
          category: _selectedCategory,
          proteinType: _selectedProtein,
          carbsType: _selectedCarbs,
          prepTime: prepMinutes,
          photoPath: Value(_photoPath),
          isFridaySpecial: _isFridaySpecial,
          isBudgetFriendly: _isBudgetFriendly,
          isFavorite: _isFavorite,
          updatedAt: DateTime.now(),
        );

        await ref.read(vaultControllerProvider.notifier).updateMeal(updatedMeal);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تعديل أكلة "$name" بنجاح'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await ref.read(vaultControllerProvider.notifier).addMeal(
              name: name,
              category: _selectedCategory,
              proteinType: _selectedProtein,
              carbsType: _selectedCarbs,
              prepTimeMinutes: prepMinutes,
              photoPath: _photoPath,
              isFridaySpecial: _isFridaySpecial,
              isBudgetFriendly: _isBudgetFriendly,
              isFavorite: _isFavorite,
            );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تمت إضافة "$name" إلى خزانة الأكلات'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title — Flexible to handle 1.4x on 320px (was overflowing 218px)
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            isEditing ? 'تعديل الأكلة' : 'إضافة أكلة جديدة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Scrollable Form Fields
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Meal Name Field
                          TextFormField(
                            key: const Key('meal_form_name_field'),
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم الأكلة *',
                              hintText: 'مثال: ملوخية بالفراخ، كفتة مشوية...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.restaurant_menu),
                            ),
                            maxLength: 120,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'من فضلك أدخل اسم الأكلة';
                              }
                              if (val.trim().length < 2) {
                                return 'اسم الأكلة يجب أن يكون حرفين على الأقل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Category Dropdown
                          DropdownButtonFormField<MealCategory>(
                            key: const Key('meal_form_category_dropdown'),
                            initialValue: _selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'التصنيف *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: MealCategory.values.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat.labelArabic,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Protein & Carbs Row — Wrap to avoid overflow at 1.4x on 320px
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final useWrap = constraints.maxWidth < 360;
                              if (useWrap) {
                                return Column(
                                  children: [
                                    DropdownButtonFormField<ProteinType>(
                                      key: const Key('meal_form_protein_dropdown'),
                                      initialValue: _selectedProtein,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'نوع البروتين *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.egg_alt_outlined),
                                      ),
                                      items: ProteinType.values.map((p) => DropdownMenuItem(value: p, child: Text(p.labelArabic, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) { if (val != null) setState(() => _selectedProtein = val);},
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<CarbsType>(
                                      key: const Key('meal_form_carbs_dropdown'),
                                      initialValue: _selectedCarbs,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'نوع النشويات *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.bakery_dining_outlined),
                                      ),
                                      items: CarbsType.values.map((c) => DropdownMenuItem(value: c, child: Text(c.labelArabic, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) { if (val != null) setState(() => _selectedCarbs = val);},
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<ProteinType>(
                                      key: const Key('meal_form_protein_dropdown'),
                                      initialValue: _selectedProtein,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'نوع البروتين *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.egg_alt_outlined),
                                      ),
                                      items: ProteinType.values.map((p) => DropdownMenuItem(value: p, child: Text(p.labelArabic, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) { if (val != null) setState(() => _selectedProtein = val);},
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<CarbsType>(
                                      key: const Key('meal_form_carbs_dropdown'),
                                      initialValue: _selectedCarbs,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'نوع النشويات *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.bakery_dining_outlined),
                                      ),
                                      items: CarbsType.values.map((c) => DropdownMenuItem(value: c, child: Text(c.labelArabic, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) { if (val != null) setState(() => _selectedCarbs = val);},
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Preparation Time Field
                          TextFormField(
                            key: const Key('meal_form_prep_time_field'),
                            controller: _prepTimeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'وقت التحضير (بالدقائق) *',
                              hintText: 'مثال: 30, 45, 60',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.timer_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'من فضلك أدخل وقت التحضير بالدقائق';
                              }
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'يجب إدخال عدد صحيح أكبر من صفر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Boolean Flags — custom rows with Flexible to avoid overflow at 1.4x on 320px
                          _switchRow(
                            key: const Key('meal_form_friday_checkbox'),
                            title: 'أكلة خاصة بالجمعة',
                            subtitle: 'ترشيحها كأولوية في أيام الجمعة',
                            value: _isFridaySpecial,
                            onChanged: (val) => setState(() => _isFridaySpecial = val),
                          ),
                          _switchRow(
                            key: const Key('meal_form_budget_checkbox'),
                            title: 'أكلة اقتصادية (على قد الإيد)',
                            subtitle: 'وجبة موفرة في الميزانية',
                            value: _isBudgetFriendly,
                            onChanged: (val) => setState(() => _isBudgetFriendly = val),
                          ),
                          _switchRow(
                            key: const Key('meal_form_favorite_checkbox'),
                            title: 'إضافة إلى المفضلة',
                            subtitle: 'الأكلات المحببة لأسرتك',
                            value: _isFavorite,
                            onChanged: (val) => setState(() => _isFavorite = val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons — Wrap to avoid 220px overflow at 1.4x on 320px
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          key: const Key('meal_form_cancel_button'),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          key: const Key('meal_form_save_button'),
                          onPressed: _handleSave,
                          child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الأكلة'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _switchRow({Key? key, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }

}
