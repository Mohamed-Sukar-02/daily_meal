// test/support/contracts.dart
// Type-safe contracts and domain models matching PROJECT.md § Interface Contracts
// and architecture_report.md § 2.1 & 2.2.

enum ProteinType {
  chicken, // فراخ / دواجن
  beef, // لحمة بلدي / مفرومة
  fish, // سمك / مأكولات بحرية
  legume, // بقوليات / نباتي (كشري، فول، عدس)
  dairy, // بيض / أجبان
  none, // بدون بروتين رئيسي
}

enum CarbsType {
  rice, // أرز (مصري، بسمتي، صيادية)
  pasta, // مكرونة (بشاميل، صلصة حمراء، طواجن)
  bread, // عيش بلدي / شامي / فينو
  potato, // بطاطس (صينية، بوريه، مقلية)
  grains, // فريك / برغل / كسكسي
  none, // قليل النشويات / بدون
}

enum MealCategory {
  egyptianTraditional, // أكلات شعبية وطبيخ مصري أصيل
  ovenBaked, // صواني وطواجن فرن
  fastFood, // سندوتشات وسريع (حواوشي، كبدة، بانيه)
  seafood, // أسماك ومأكولات بحرية
  soupStew, // شوربات ويخنات شتوية
  vegetarian, // قرديحي / نباتي
}

enum MealHistoryStatus {
  cookedToday, // تم طبخها اليوم
  leftover, // أكل بواقي من اليوم السابق
}

enum AppThemeModePreference {
  system,
  light,
  dark,
}

class Meal {
  final int id;
  final String name;
  final String? photoPath;
  final ProteinType proteinType;
  final CarbsType carbsType;
  final MealCategory category;
  final int prepTimeMinutes;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Meal({
    required this.id,
    required this.name,
    this.photoPath,
    required this.proteinType,
    required this.carbsType,
    required this.category,
    required this.prepTimeMinutes,
    this.isFridaySpecial = false,
    this.isBudgetFriendly = false,
    this.isFavorite = false,
    required this.createdAt,
    this.updatedAt,
  });

  Meal copyWith({
    int? id,
    String? name,
    String? photoPath,
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    int? prepTimeMinutes,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      proteinType: proteinType ?? this.proteinType,
      carbsType: carbsType ?? this.carbsType,
      category: category ?? this.category,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      isFridaySpecial: isFridaySpecial ?? this.isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly ?? this.isBudgetFriendly,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Meal && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MealHistoryData {
  final int id;
  final int? mealId; // Nullable to preserve history on meal deletion
  final String mealName;
  final ProteinType proteinType;
  final CarbsType carbsType;
  final DateTime cookedDate;
  final MealHistoryStatus status;
  final String? notes;
  final DateTime createdAt;

  const MealHistoryData({
    required this.id,
    this.mealId,
    required this.mealName,
    required this.proteinType,
    required this.carbsType,
    required this.cookedDate,
    required this.status,
    this.notes,
    required this.createdAt,
  });
}

class MealHistoryWithMeal {
  final MealHistoryData history;
  final Meal? meal;

  const MealHistoryWithMeal({
    required this.history,
    this.meal,
  });
}

class AppSetting {
  final int id;
  final int cooldownDays;
  final bool preventRepeatProtein;
  final bool preventRepeatCarbs;
  final int notificationHour;
  final int notificationMinute;
  final bool notificationsEnabled;
  final AppThemeModePreference themeMode;
  final bool isFirstRun;

  const AppSetting({
    this.id = 1,
    this.cooldownDays = 14,
    this.preventRepeatProtein = true,
    this.preventRepeatCarbs = true,
    this.notificationHour = 11,
    this.notificationMinute = 0,
    this.notificationsEnabled = false,
    this.themeMode = AppThemeModePreference.system,
    this.isFirstRun = true,
  });

  AppSetting copyWith({
    int? id,
    int? cooldownDays,
    bool? preventRepeatProtein,
    bool? preventRepeatCarbs,
    int? notificationHour,
    int? notificationMinute,
    bool? notificationsEnabled,
    AppThemeModePreference? themeMode,
    bool? isFirstRun,
  }) {
    return AppSetting(
      id: id ?? this.id,
      cooldownDays: cooldownDays ?? this.cooldownDays,
      preventRepeatProtein: preventRepeatProtein ?? this.preventRepeatProtein,
      preventRepeatCarbs: preventRepeatCarbs ?? this.preventRepeatCarbs,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      isFirstRun: isFirstRun ?? this.isFirstRun,
    );
  }
}

class RecommendationResult {
  final List<Meal> recommendations;
  final int relaxationLevel;
  final String relaxationReason;
  final DateTime computedDate;

  const RecommendationResult({
    required this.recommendations,
    required this.relaxationLevel,
    required this.relaxationReason,
    required this.computedDate,
  });
}

class MealsCompanion {
  final String name;
  final String? photoPath;
  final ProteinType proteinType;
  final CarbsType carbsType;
  final MealCategory category;
  final int prepTimeMinutes;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isFavorite;

  const MealsCompanion({
    required this.name,
    this.photoPath,
    required this.proteinType,
    required this.carbsType,
    required this.category,
    required this.prepTimeMinutes,
    this.isFridaySpecial = false,
    this.isBudgetFriendly = false,
    this.isFavorite = false,
  });
}
