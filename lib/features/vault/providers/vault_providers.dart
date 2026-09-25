import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utils/arabic_normalizer.dart';

final allMealsProvider = StreamProvider<List<Meal>>((ref) {
  final dao = ref.watch(mealsDaoProvider);
  return dao.watchAllMeals();
});

/// Cloud ids of starter meals the user explicitly deleted. `MealsDao.deleteMeal`
/// blacklists a deleted starter's cloud id so auto-sync never re-adds it; the
/// vault sync-status icon ignores blacklisted ids when deciding whether the
/// defaults are fully synced.
final deletedStarterMealIdsProvider = FutureProvider<Set<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList('deleted_starter_meals') ?? const []).toSet();
});

final favoriteMealsProvider = StreamProvider<List<Meal>>((ref) {
  final dao = ref.watch(mealsDaoProvider);
  return dao.watchFavorites();
});

class VaultFilterState {
  final String searchQuery;
  final ProteinType? proteinType;
  final CarbsType? carbsType;
  final MealCategory? category;
  final bool isFavoriteOnly;
  final bool isFridaySpecialOnly;
  final bool isBudgetFriendlyOnly;
  final int? maxPrepTime;

  const VaultFilterState({
    this.searchQuery = '',
    this.proteinType,
    this.carbsType,
    this.category,
    this.isFavoriteOnly = false,
    this.isFridaySpecialOnly = false,
    this.isBudgetFriendlyOnly = false,
    this.maxPrepTime,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      proteinType != null ||
      carbsType != null ||
      category != null ||
      isFavoriteOnly ||
      isFridaySpecialOnly ||
      isBudgetFriendlyOnly ||
      maxPrepTime != null;

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (proteinType != null) count++;
    if (carbsType != null) count++;
    if (category != null) count++;
    if (isFavoriteOnly) count++;
    if (isFridaySpecialOnly) count++;
    if (isBudgetFriendlyOnly) count++;
    if (maxPrepTime != null) count++;
    return count;
  }

  VaultFilterState copyWith({
    String? searchQuery,
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFavoriteOnly,
    bool? isFridaySpecialOnly,
    bool? isBudgetFriendlyOnly,
    int? maxPrepTime,
    bool clearProtein = false,
    bool clearCarbs = false,
    bool clearCategory = false,
  }) {
    return VaultFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      proteinType: clearProtein ? null : (proteinType ?? this.proteinType),
      carbsType: clearCarbs ? null : (carbsType ?? this.carbsType),
      category: clearCategory ? null : (category ?? this.category),
      isFavoriteOnly: isFavoriteOnly ?? this.isFavoriteOnly,
      isFridaySpecialOnly: isFridaySpecialOnly ?? this.isFridaySpecialOnly,
      isBudgetFriendlyOnly: isBudgetFriendlyOnly ?? this.isBudgetFriendlyOnly,
      maxPrepTime: maxPrepTime ?? this.maxPrepTime,
    );
  }
}

class VaultFilterNotifier extends Notifier<VaultFilterState> {
  @override
  VaultFilterState build() => const VaultFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleProtein(ProteinType protein) {
    if (state.proteinType == protein) {
      state = state.copyWith(clearProtein: true);
    } else {
      state = state.copyWith(proteinType: protein);
    }
  }

  void toggleCarbs(CarbsType carbs) {
    if (state.carbsType == carbs) {
      state = state.copyWith(clearCarbs: true);
    } else {
      state = state.copyWith(carbsType: carbs);
    }
  }

  void toggleCategory(MealCategory category) {
    if (state.category == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(category: category);
    }
  }

  void toggleFridayFilter() {
    state = state.copyWith(isFridaySpecialOnly: !state.isFridaySpecialOnly);
  }

  void toggleBudgetFilter() {
    state = state.copyWith(isBudgetFriendlyOnly: !state.isBudgetFriendlyOnly);
  }

  void toggleFavoriteFilter() {
    state = state.copyWith(isFavoriteOnly: !state.isFavoriteOnly);
  }

  void resetFilters() {
    state = const VaultFilterState();
  }
}

final vaultFilterProvider = NotifierProvider<VaultFilterNotifier, VaultFilterState>(() {
  return VaultFilterNotifier();
});

final filteredMealsProvider = Provider<AsyncValue<List<Meal>>>((ref) {
  final allMealsAsync = ref.watch(allMealsProvider);
  final filter = ref.watch(vaultFilterProvider);

  return allMealsAsync.whenData((meals) {
    return meals.where((meal) {
      if (filter.searchQuery.trim().isNotEmpty) {
        final normalizedQuery = normalizeArabic(filter.searchQuery.trim());
        final mealNormalized = meal.nameNormalized ?? normalizeArabic(meal.name);
        if (!mealNormalized.contains(normalizedQuery)) {
          return false;
        }
      }

      if (filter.proteinType != null && meal.proteinType != filter.proteinType) {
        return false;
      }

      if (filter.carbsType != null && meal.carbsType != filter.carbsType) {
        return false;
      }

      if (filter.category != null && meal.category != filter.category) {
        return false;
      }

      if (filter.isFavoriteOnly && !meal.isFavorite) {
        return false;
      }
      if (filter.isFridaySpecialOnly && !meal.isFridaySpecial) {
        return false;
      }
      if (filter.isBudgetFriendlyOnly && !meal.isBudgetFriendly) {
        return false;
      }
      if (filter.maxPrepTime != null && meal.prepTime > filter.maxPrepTime!) {
        return false;
      }

      return true;
    }).toList();
  });
});

class VaultController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<int> addMeal({
    required String name,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required MealCategory category,
    required int prepTimeMinutes,
    String? photoPath,
    bool isFridaySpecial = false,
    bool isBudgetFriendly = false,
    bool isFavorite = false,
    String? notes,
    String? shortName,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Meal name cannot be empty');
    }
    if (prepTimeMinutes <= 0) {
      throw ArgumentError('Prep time must be positive');
    }

    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealsDaoProvider);
      final id = await dao.insertMeal(
        MealsCompanion(
          name: Value(cleanName),
          proteinType: Value(proteinType),
          carbsType: Value(carbsType),
          category: Value(category),
          prepTime: Value(prepTimeMinutes),
          photoPath: photoPath != null ? Value(photoPath) : const Value.absent(),
          isFridaySpecial: Value(isFridaySpecial),
          isBudgetFriendly: Value(isBudgetFriendly),
          isFavorite: Value(isFavorite),
          notes: notes != null && notes.trim().isNotEmpty
              ? Value(notes.trim())
              : const Value.absent(),
          shortName: shortName != null && shortName.trim().isNotEmpty
              ? Value(shortName.trim())
              : const Value.absent(),
        ),
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<int> addMealCompanion(MealsCompanion companion) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealsDaoProvider);
      final id = await dao.insertMeal(companion);
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<bool> updateMeal(Meal meal) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealsDaoProvider);
      final success = await dao.updateMeal(meal);
      state = const AsyncValue.data(null);
      return success;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  Future<int> deleteMeal(int id) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealsDaoProvider);
      final deleted = await dao.deleteMeal(id);
      // Deleting a starter meal may add its cloud id to the sync blacklist —
      // refresh it so the sync-status icon reflects the new state.
      ref.invalidate(deletedStarterMealIdsProvider);
      state = const AsyncValue.data(null);
      return deleted;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Toggles a meal's favourite flag (bookmark button on the vault cards).
  ///
  /// The caller fires this without awaiting, so errors are captured in
  /// [state] instead of being rethrown — a rethrown, unawaited future would
  /// surface as an unhandled async exception.
  Future<void> toggleFavorite(int id, [bool? currentStatus]) async {
    try {
      final dao = ref.read(mealsDaoProvider);
      await dao.toggleFavorite(id, currentStatus);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }
}

final vaultControllerProvider = AsyncNotifierProvider<VaultController, void>(() {
  return VaultController();
});

const String _kVaultIsGridViewKey = 'vault_is_grid_view';

class VaultViewModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadPreference();
    return true; // Default to Grid view
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kVaultIsGridViewKey);
      if (saved != null) {
        state = saved;
      }
    } catch (_) {
      // Fallback silently in test or offline environments
    }
  }

  Future<void> setGridView(bool isGrid) async {
    state = isGrid;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kVaultIsGridViewKey, isGrid);
    } catch (_) {
      // Fallback silently in test or offline environments
    }
  }
}

final vaultViewModeProvider =
    NotifierProvider<VaultViewModeNotifier, bool>(() {
  return VaultViewModeNotifier();
});

const String _kSavedCloudMealsKey = 'saved_cloud_meals';

class SavedCloudMealsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadPreference();
    return const {};
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kSavedCloudMealsKey);
      if (saved != null) {
        state = saved.toSet();
      }
    } catch (_) {
      // Fallback silently in test or offline environments
    }
  }

  Future<void> toggleSaved(String cloudId) async {
    final newState = Set<String>.from(state);
    if (newState.contains(cloudId)) {
      newState.remove(cloudId);
    } else {
      newState.add(cloudId);
    }
    state = newState;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSavedCloudMealsKey, newState.toList());
    } catch (_) {
      // Fallback silently in test or offline environments
    }
  }
}

final savedCloudMealsProvider = NotifierProvider<SavedCloudMealsNotifier, Set<String>>(() {
  return SavedCloudMealsNotifier();
});
