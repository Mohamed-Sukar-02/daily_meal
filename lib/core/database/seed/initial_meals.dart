import 'package:drift/drift.dart';
import '../app_database.dart';

final initialEgyptianMealsSeed = <MealsCompanion>[
  // 1
  const MealsCompanion(
    id: Value(1),
    cloudId: Value('seed_1'),
    name: Value('كشري مصري أصلي بالصلصة والدقة'),
    proteinType: Value(ProteinType.legume),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(50),
    isFridaySpecial: Value(false),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 2
  const MealsCompanion(
    id: Value(2),
    cloudId: Value('seed_2'),
    name: Value('ملوخية خضراء بالفراخ المحمرة وأرز بالشعرية'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(45),
    isFridaySpecial: Value(false),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 3
  const MealsCompanion(
    id: Value(3),
    cloudId: Value('seed_3'),
    name: Value('صينية بطاطس باللحمة في الفرن وأرز مصري'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.potato),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(60),
    isFridaySpecial: Value(false),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 4
  const MealsCompanion(
    id: Value(4),
    cloudId: Value('seed_4'),
    name: Value('سمك بلطي مشوي بالردة ورز صيادية وسلطة بلدي'),
    proteinType: Value(ProteinType.fish),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.seafood),
    prepTime: Value(40),
    isFridaySpecial: Value(true),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 5
  const MealsCompanion(
    id: Value(5),
    cloudId: Value('seed_5'),
    name: Value('حواوشي بلدي مقرمش في الفرن ومخلل'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.fastFood),
    prepTime: Value(30),
    isFridaySpecial: Value(false),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 6
  const MealsCompanion(
    id: Value(6),
    cloudId: Value('seed_6'),
    name: Value('صينية مكرونة بالبشاميل واللحمة المفرومة'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.pasta),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(65),
    isFridaySpecial: Value(true),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 7
  const MealsCompanion(
    id: Value(7),
    cloudId: Value('seed_7'),
    name: Value('طاجن بامية باللحمة الضاني وأرز أبيض'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(60),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 8
  const MealsCompanion(
    id: Value(8),
    cloudId: Value('seed_8'),
    name: Value('كبدة إسكندراني بالثوم والفلفل الحامي وعيش بلدي'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.fastFood),
    prepTime: Value(20),
    isFridaySpecial: Value(false),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 9
  const MealsCompanion(
    id: Value(9),
    cloudId: Value('seed_9'),
    name: Value('صينية فراخ مشوية بالبصل والبطاطس'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.potato),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(50),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 10
  const MealsCompanion(
    id: Value(10),
    cloudId: Value('seed_10'),
    name: Value('مسقعة باللحمة المفرومة والبشاميل وعيش'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    // An oven tray by any definition the app uses — béchamel in a tray is the
    // picture on the `ovenBaked` chip, and the cloud vocabulary agrees
    // (`casserole` → `ovenBaked`, `lib/features/vault/data/cloud_vocabulary.dart`).
    // `egyptianTraditional` means "طبيخ/شعبي": a pot on the stove, which is what
    // its label says («أكلات شعبية وطبيخ»), so leaving this row there made the
    // first thing a new user sees disagree with the chip the editor offers.
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(45),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 11
  const MealsCompanion(
    id: Value(11),
    cloudId: Value('seed_11'),
    name: Value('شيش طاووق متبل مع أرز بسمتي بالخلطة'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(40),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 12
  const MealsCompanion(
    id: Value(12),
    cloudId: Value('seed_12'),
    name: Value('كفتة حاتي مشوية مع سلطة طحينة وعيش سخن'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(35),
    isFridaySpecial: Value(true),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 13
  const MealsCompanion(
    id: Value(13),
    cloudId: Value('seed_13'),
    name: Value('سمك فيليه مقلي مع سلطة طحينة وأرز أحمر'),
    proteinType: Value(ProteinType.fish),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.seafood),
    prepTime: Value(30),
    isFridaySpecial: Value(true),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 14
  const MealsCompanion(
    id: Value(14),
    cloudId: Value('seed_14'),
    name: Value('شوربة عدس أصفر بالشعرية والليمون وعيش محمص'),
    proteinType: Value(ProteinType.legume),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.soupStew),
    prepTime: Value(25),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 15
  const MealsCompanion(
    id: Value(15),
    cloudId: Value('seed_15'),
    name: Value('بانيه دجاج ذهبي مقرمش مع مكرونة بالصلصة'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.pasta),
    category: Value(MealCategory.fastFood),
    prepTime: Value(30),
    isFridaySpecial: Value(false),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 16
  const MealsCompanion(
    id: Value(16),
    cloudId: Value('seed_16'),
    name: Value('طاجن مكرونة بالسجق البلدي زي المحلات'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.pasta),
    // A طاجن goes in the oven. `fastFood` is the app's "سندوتشات وسريع" chip, and
    // this dish is not that even though the chain it imitates is fast food — the
    // tag describes how it is cooked and served at home, not where it was born.
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(30),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 17
  const MealsCompanion(
    id: Value(17),
    cloudId: Value('seed_17'),
    name: Value('فتة مصرية بالخل والثوم وموزة لحمة مسلوقة'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(75),
    isFridaySpecial: Value(true),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
  // 18
  const MealsCompanion(
    id: Value(18),
    cloudId: Value('seed_18'),
    name: Value('فول مدمس بالزيت الحار وطعمية سخنة وبتنجان مخلل'),
    proteinType: Value(ProteinType.legume),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(15),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 19
  const MealsCompanion(
    id: Value(19),
    cloudId: Value('seed_19'),
    name: Value('شكشوكة بالبيض والطماطم والجبنة الرومي وعيش'),
    proteinType: Value(ProteinType.dairy),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(15),
    isFridaySpecial: Value(false),
    isFavorite: Value(false),
    isStarterMeal: Value(true),
  ),
  // 20
  const MealsCompanion(
    id: Value(20),
    cloudId: Value('seed_20'),
    name: Value('طاجن جمبري وسبيط بالصوص الأحمر وأرز صيادية'),
    proteinType: Value(ProteinType.fish),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.seafood),
    prepTime: Value(40),
    isFridaySpecial: Value(true),
    isFavorite: Value(true),
    isStarterMeal: Value(true),
  ),
];
