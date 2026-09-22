import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/meals/presentation/meal_screen.dart';
import 'package:daily_meal/features/meals/presentation/widgets/meal_dish_tabs.dart';
import 'package:daily_meal/features/meals/presentation/widgets/meal_info_banner.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// MealScreen mockup-layout regression guard.
//
// Pins the outer chrome locked to meal_screen-light / meal_screen-dark:
//   floating short name · cloud · hero + full-name scrim · green info banner
//   · Main/Side tabs · More Favorites · bottom pill.
// ---------------------------------------------------------------------------

Meal _sampleMeal({
  int id = 7,
  String name = 'ملوخية خضراء بالفراخ',
  String? shortName = 'ملوخية',
  String? notes = 'تتقلى الثوم كويس قبل الإضافة',
  bool favorite = true,
  bool friday = false,
  bool budget = true,
}) {
  final now = DateTime(2026, 9, 22, 12);
  return Meal(
    id: id,
    name: name,
    nameNormalized: name,
    photoPath: null,
    proteinType: ProteinType.chicken,
    carbsType: CarbsType.rice,
    category: MealCategory.egyptianTraditional,
    prepTime: 45,
    isFridaySpecial: friday,
    isBudgetFriendly: budget,
    isFavorite: favorite,
    isStarterMeal: false,
    createdAt: now,
    updatedAt: now,
    notes: notes,
    shortName: shortName,
  );
}

Meal _favMeal(int id, String name) {
  final now = DateTime(2026, 9, 22, 12);
  return Meal(
    id: id,
    name: name,
    nameNormalized: name,
    photoPath: null,
    proteinType: ProteinType.beef,
    carbsType: CarbsType.pasta,
    category: MealCategory.ovenBaked,
    prepTime: 30,
    isFridaySpecial: false,
    isBudgetFriendly: false,
    isFavorite: true,
    isStarterMeal: false,
    createdAt: now,
    updatedAt: now,
    shortName: name,
  );
}

Future<void> _pumpMealScreen(
  WidgetTester tester, {
  required List<Meal> meals,
  List<Meal>? favorites,
  int mealId = 7,
  Locale locale = const Locale('ar'),
  TextDirection direction = TextDirection.rtl,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allMealsProvider.overrideWith((ref) => Stream.value(meals)),
        favoriteMealsProvider.overrideWith(
          (ref) => Stream.value(favorites ?? meals.where((m) => m.isFavorite).toList()),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: Directionality(
          textDirection: direction,
          child: MealScreen(mealId: mealId),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('renders mockup chrome for a known meal', (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [
        _sampleMeal(),
        _favMeal(8, 'كشري'),
        _favMeal(9, 'محشي'),
      ],
    );

    expect(find.byKey(const Key('meal_screen')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_body')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_back_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_favorite_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_cloud_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_short_name')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_hero')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_full_name')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_info_card')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_dish_tabs')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_tab_main')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_tab_side1')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_tab_side2')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_more_favorites')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_bottom_pill')), findsOneWidget);

    expect(find.byType(MealInfoBanner), findsOneWidget);
    expect(find.byType(MealDishTabs), findsOneWidget);

    expect(find.text('ملوخية'), findsWidgets);
    expect(find.text('ملوخية خضراء بالفراخ'), findsOneWidget);
  });

  testWidgets('falls back to full name when shortName is empty', (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [_sampleMeal(shortName: null, name: 'كشري محترم')],
    );

    final short = tester.widget<Text>(
      find.byKey(const Key('meal_screen_short_name')),
    );
    expect(short.data, 'كشري محترم');
  });

  testWidgets('shows not-found state for a missing meal id', (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [_sampleMeal(id: 1)],
      mealId: 999,
    );

    expect(find.byKey(const Key('meal_screen_not_found')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_body')), findsNothing);
  });

  testWidgets('tapping Side Dish tabs keeps the panel mounted', (tester) async {
    await _pumpMealScreen(tester, meals: [_sampleMeal()]);

    await tester.tap(find.byKey(const Key('meal_screen_tab_side1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal_screen_tab_side2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal_screen_tab_main')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);
  });

  testWidgets('info banner shows prep time and fresh label', (tester) async {
    await _pumpMealScreen(tester, meals: [_sampleMeal()]);

    final strings = const AppStrings(Locale('ar'));
    expect(find.text(strings.freshAndNatural), findsOneWidget);
    expect(find.text(strings.prepMinutesShort(45)), findsWidgets);
  });

  testWidgets('dark mode paints without throwing', (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [_sampleMeal(), _favMeal(2, 'فتة')],
      brightness: Brightness.dark,
    );
    expect(find.byKey(const Key('meal_screen_hero')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_info_card')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_bottom_pill')), findsOneWidget);
  });

  testWidgets('LTR English layout exposes dish tabs and more favorites',
      (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [
        _sampleMeal(
          name: 'Green Molokhia with Chicken',
          shortName: 'Molokhia',
          notes: 'Fry the garlic well',
        ),
        _favMeal(3, 'Koshary'),
      ],
      locale: const Locale('en'),
      direction: TextDirection.ltr,
    );

    final strings = const AppStrings(Locale('en'));
    expect(find.text(strings.mainDish), findsWidgets);
    expect(find.text(strings.sideDish1), findsOneWidget);
    expect(find.text(strings.sideDish2), findsOneWidget);
    expect(find.text(strings.moreFavorites), findsOneWidget);
    expect(find.text('Molokhia'), findsWidgets);
  });

  testWidgets('hides more-favorites when no other favorites exist',
      (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [_sampleMeal()],
      favorites: const [],
    );
    expect(find.byKey(const Key('meal_screen_more_favorites')), findsNothing);
  });
}
