// Scratch render of the home page "Cook This" pill, used to eyeball the pill's
// proportions after its height was trimmed. Not a regression test.
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/features/home/presentation/widgets/quick_actions.dart';
import 'package:daily_meal/features/meals/presentation/quick_meal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Meal _meal() {
  final now = DateTime(2026, 9, 24, 12);
  return Meal(
    id: 1,
    name: 'أرز باللحمة',
    nameNormalized: 'ارز مع مروة',
    photoPath: null,
    proteinType: ProteinType.beef,
    carbsType: CarbsType.rice,
    category: MealCategory.egyptianTraditional,
    prepTime: 35,
    isFridaySpecial: false,
    isFavorite: false,
    isStarterMeal: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required bool dark,
  required Widget pill,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 240));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: _delegates,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(body: Center(child: pill)),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final size = tester.getSize(find.byKey(const ValueKey('btn_cooked_today')));
  final label = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const ValueKey('btn_cooked_today')),
      matching: find.text('هطبخها'),
    ),
  );
  debugPrint('$name -> pillHeight=${size.height} labelFontSize=${label.style?.fontSize}');

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  testWidgets('bare pill, light', (tester) async {
    await _shoot(
      tester,
      name: 'cook_pill_bare_light',
      dark: false,
      pill: SizedBox(width: 260, child: QuickActions(onCookedToday: () {})),
    );
  });

  testWidgets('inside the home card, light', (tester) async {
    await _shoot(
      tester,
      name: 'cook_pill_card_light',
      dark: false,
      pill: SizedBox(
        width: 320,
        child: QuickMealView.fromMeal(
          _meal(),
          shape: MealViewShape.quick,
          cardVariant: MealCardVariant.photoWide,
          footer: QuickActions(onCookedToday: () {}),
          onToggleFavorite: () {},
        ),
      ),
    );
  });

  testWidgets('inside the home card, dark', (tester) async {
    await _shoot(
      tester,
      name: 'cook_pill_card_dark',
      dark: true,
      pill: SizedBox(
        width: 320,
        child: QuickMealView.fromMeal(
          _meal(),
          shape: MealViewShape.quick,
          cardVariant: MealCardVariant.photoWide,
          footer: QuickActions(onCookedToday: () {}),
          onToggleFavorite: () {},
        ),
      ),
    );
  });
}
