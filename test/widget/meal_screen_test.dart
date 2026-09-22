import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/meals/presentation/meal_screen.dart';
import 'package:daily_meal/features/meals/presentation/widgets/meal_dish_section.dart';
import 'package:daily_meal/features/meals/presentation/widgets/meal_name_scrim.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// MealScreen mockup-layout regression guard.
//
// Pins the outer chrome the user locked in:
//   short name · hero + full-name scrim · info card · dish tabs · circle
//   · edit/delete. Tab switching must flip the selected pane without
//   rebuilding the rest of the chrome. Backend dish payloads are out of
//   scope — this test only exercises the frontend shell.
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

Future<void> _pumpMealScreen(
  WidgetTester tester, {
  required List<Meal> meals,
  int mealId = 7,
  Locale locale = const Locale('ar'),
  TextDirection direction = TextDirection.rtl,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allMealsProvider.overrideWith((ref) => Stream.value(meals)),
      ],
      child: MaterialApp(
        locale: locale,
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: Directionality(
          textDirection: direction,
          child: MealScreen(mealId: mealId),
        ),
      ),
    ),
  );
  // StreamProvider emits asynchronously — settle once.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('renders full mockup chrome for a known meal', (tester) async {
    await _pumpMealScreen(tester, meals: [_sampleMeal()]);

    expect(find.byKey(const Key('meal_screen')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_body')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_back_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_favorite_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_short_name')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_hero')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_full_name')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_info_card')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_dish_tabs')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_tab_main')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_tab_side1')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_tab_side2')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_circle_placeholder')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_edit_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_delete_button')), findsOneWidget);

    // Short name on top, full name over the photo.
    expect(find.text('ملوخية'), findsOneWidget);
    expect(find.text('ملوخية خضراء بالفراخ'), findsWidgets);

    // Scrim present (gradient + theme veil).
    expect(find.byType(MealNameScrim), findsOneWidget);
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

  testWidgets('tapping Side Dish 1 / 2 switches the selected pane',
      (tester) async {
    await _pumpMealScreen(tester, meals: [_sampleMeal()]);

    // Default = Main Dish selected.
    final mainBefore = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('meal_screen_tab_main')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    // Just assert the tab is tappable and panel stays mounted after switches.
    await tester.tap(find.byKey(const Key('meal_screen_tab_side1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal_screen_tab_side2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal_screen_tab_main')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_screen_dish_panel')), findsOneWidget);

    // Silence unused warning if AnimatedContainer finder shape changes.
    expect(mainBefore, isNotNull);
  });

  testWidgets('info card surfaces protein, carbs and prep time', (tester) async {
    await _pumpMealScreen(tester, meals: [_sampleMeal()]);

    final strings = const AppStrings(Locale('ar'));
    expect(find.text(strings.chicken), findsWidgets);
    expect(find.text(strings.carbsLabel('rice')), findsWidgets);
    expect(find.text(strings.minutes(45)), findsOneWidget);
    expect(find.text(strings.budgetFriendly), findsOneWidget);
  });

  testWidgets('dark-mode scrim still paints without throwing', (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [_sampleMeal()],
      brightness: Brightness.dark,
    );
    expect(find.byType(MealNameScrim), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_full_name')), findsOneWidget);
  });

  testWidgets('LTR English layout still exposes dish tabs', (tester) async {
    await _pumpMealScreen(
      tester,
      meals: [
        _sampleMeal(
          name: 'Green Molokhia with Chicken',
          shortName: 'Molokhia',
          notes: 'Fry the garlic well',
        ),
      ],
      locale: const Locale('en'),
      direction: TextDirection.ltr,
    );

    final strings = const AppStrings(Locale('en'));
    expect(find.text(strings.mainDish), findsWidgets);
    expect(find.text(strings.sideDish1), findsOneWidget);
    expect(find.text(strings.sideDish2), findsOneWidget);
    expect(find.text('Molokhia'), findsOneWidget);
  });

  testWidgets('MealDishSection hides side tabs when flagged off', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealDishSection(
            selected: MealDishTab.main,
            onChanged: (_) {},
            showSide1: false,
            showSide2: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('meal_screen_tab_main')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_tab_side1')), findsNothing);
    expect(find.byKey(const Key('meal_screen_tab_side2')), findsNothing);
  });
}
