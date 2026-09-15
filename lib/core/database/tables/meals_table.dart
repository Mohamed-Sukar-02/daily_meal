import 'package:drift/drift.dart';

enum ProteinType {
  chicken, // فراخ / دواجن
  beef, // لحمة / مفروم
  fish, // أسماك / مأكولات بحرية
  legume, // بقوليات (كشري، عدس، فول)
  dairy, // بيض / أجبان
  none, // بدون بروتين
}

enum CarbsType {
  rice, // أرز
  pasta, // مكرونة
  bread, // عيش
  potato, // بطاطس
  grains, // فريك / برغل
  none, // بدون نشويات
}

enum MealCategory {
  egyptianTraditional, // أكلات شعبية وطبيخ
  ovenBaked, // صواني وطواجن فرن
  fastFood, // سندوتشات وسريع
  seafood, // أسماك وبحريات
  soupStew, // شوربات ويخنات
  vegetarian, // قرديحي / نباتي
}

class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get nameNormalized => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get proteinType => textEnum<ProteinType>()();
  TextColumn get carbsType => textEnum<CarbsType>()();
  TextColumn get category => textEnum<MealCategory>()();
  IntColumn get prepTime => integer()(); // in minutes
  BoolColumn get isFridaySpecial => boolean().withDefault(const Constant(false))();
  BoolColumn get isBudgetFriendly => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get cloudId => text().nullable()();
}

extension ProteinTypeX on ProteinType {
  String get labelArabic {
    switch (this) {
      case ProteinType.chicken:
        return 'فراخ';
      case ProteinType.beef:
        return 'لحمة';
      case ProteinType.fish:
        return 'سمك';
      case ProteinType.legume:
        return 'بقوليات';
      case ProteinType.dairy:
        return 'بيض / أجبان';
      case ProteinType.none:
        return 'بدون بروتين';
    }
  }

  /// Emoji used by the vault / history badges (matches the mockups).
  String get emoji {
    switch (this) {
      case ProteinType.chicken:
        return '🐔';
      case ProteinType.beef:
        return '🥩';
      case ProteinType.fish:
        return '🐟';
      case ProteinType.legume:
        return '🫘';
      case ProteinType.dairy:
        return '🧀';
      case ProteinType.none:
        return '🥗';
    }
  }
}

extension CarbsTypeX on CarbsType {
  String get labelArabic {
    switch (this) {
      case CarbsType.rice:
        return 'أرز';
      case CarbsType.pasta:
        return 'مكرونة';
      case CarbsType.bread:
        return 'عيش';
      case CarbsType.potato:
        return 'بطاطس';
      case CarbsType.grains:
        return 'حبوب / فريك';
      case CarbsType.none:
        return 'بدون نشويات';
    }
  }
}

extension MealCategoryX on MealCategory {
  String get labelArabic {
    switch (this) {
      case MealCategory.egyptianTraditional:
        return 'أكلات شعبية وطبيخ';
      case MealCategory.ovenBaked:
        return 'طواجن وصواني فرن';
      case MealCategory.fastFood:
        return 'سريع وسندوتشات';
      case MealCategory.seafood:
        return 'أسماك وبحريات';
      case MealCategory.soupStew:
        return 'شوربات ويخنات';
      case MealCategory.vegetarian:
        return 'نباتي / قرديحي';
    }
  }
}
