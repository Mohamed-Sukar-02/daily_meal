import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/theme/app_palette.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/features/home/presentation/widgets/meal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildThemedApp({
  required Widget child,
  required ThemeData theme,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: child,
      ),
    ),
  );
}

Meal _createSampleMeal({
  int id = 1,
  String name = 'طاجن بامية باللحمة الضاني',
  bool isFridaySpecial = true,
  bool isBudgetFriendly = true,
  bool isFavorite = true,
}) {
  return Meal(
    id: id,
    name: name,
    category: MealCategory.egyptianTraditional,
    proteinType: ProteinType.beef,
    carbsType: CarbsType.rice,
    prepTime: 45,
    isFridaySpecial: isFridaySpecial,
    isBudgetFriendly: isBudgetFriendly,
    isFavorite: isFavorite,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('Modern Typography & Font Integration Tests', () {
    test('R1.1: lightTheme applies Cairo font family globally', () {
      final light = AppTheme.lightTheme;
      expect(light.textTheme.bodyMedium?.fontFamily, contains('Cairo'));
      expect(light.textTheme.titleLarge?.fontFamily, contains('Cairo'));
      expect(light.textTheme.bodyLarge?.fontFamily, contains('Cairo'));
    });

    test('R1.2: darkTheme applies Cairo font family globally', () {
      final dark = AppTheme.darkTheme;
      expect(dark.textTheme.bodyMedium?.fontFamily, contains('Cairo'));
      expect(dark.textTheme.titleLarge?.fontFamily, contains('Cairo'));
      expect(dark.textTheme.bodyLarge?.fontFamily, contains('Cairo'));
    });
  });

  group('Design-token Palette Tests (mockup-derived)', () {
    test('R2.1: darkTheme uses the mockup deep-navy surfaces, not pitch black', () {
      final dark = AppTheme.darkTheme;
      final cs = dark.colorScheme;

      expect(cs.brightness, equals(Brightness.dark));

      // Page / card surfaces sampled from `home page - dark.png`
      expect(cs.surfaceDim, equals(AppPalette.darkBg));
      expect(cs.surfaceContainerLow, equals(AppPalette.darkCard));
      expect(cs.surface, equals(const Color(0xFF10151C)));

      // Scaffold background is the page colour
      expect(dark.scaffoldBackgroundColor, equals(AppPalette.darkBg));

      // Text + brand accents
      expect(cs.onSurface, equals(AppPalette.darkTextPrimary));
      expect(cs.primary, equals(AppPalette.brandGreen));
      expect(cs.secondary, equals(const Color(0xFF8B93F8)));
      expect(cs.tertiary, equals(const Color(0xFFE9B33C)));
    });

    test('R2.2: lightTheme uses the mockup off-white page on white cards', () {
      final light = AppTheme.lightTheme;
      final cs = light.colorScheme;

      expect(cs.brightness, equals(Brightness.light));
      expect(light.scaffoldBackgroundColor, equals(AppPalette.lightBg));
      expect(cs.surface, equals(AppPalette.lightCard));
      expect(cs.onSurface, equals(AppPalette.lightTextPrimary));
      expect(cs.primary, equals(AppPalette.brandGreen));
      expect(cs.secondary, equals(AppPalette.brandCoral));
    });

    test('R2.3: card, chip and dialog themes follow the token palette', () {
      final dark = AppTheme.darkTheme;
      final light = AppTheme.lightTheme;

      expect(dark.cardTheme.elevation, equals(0));
      expect(dark.cardTheme.color, equals(AppPalette.darkCard));
      expect(light.cardTheme.color, equals(AppPalette.lightCard));
      expect(dark.chipTheme.backgroundColor, equals(AppPalette.darkTabContainer));
      expect(dark.dialogTheme.backgroundColor, equals(AppPalette.darkCard));
      expect(light.dialogTheme.backgroundColor, equals(AppPalette.lightCard));
    });
  });

  group('MealCard mockup styling Tests', () {
    testWidgets('R3.1: MealCard renders smoothly in light mode with all elements', (tester) async {
      final meal = _createSampleMeal();

      await tester.pumpWidget(
        _buildThemedApp(
          theme: AppTheme.lightTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: meal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MealCard), findsOneWidget);
      expect(find.text('طاجن بامية باللحمة الضاني'), findsOneWidget);
      expect(find.text('أكلة جمعة'), findsOneWidget);
      expect(find.text('اقتصادي'), findsOneWidget);
      expect(find.text('مفضلة'), findsOneWidget);
      expect(find.text('45 دقيقة'), findsOneWidget);
      expect(find.text('Cook This'), findsOneWidget);
    });

    testWidgets('R3.2: MealCard renders smoothly in dark mode with dark-adaptive styling', (tester) async {
      final meal = _createSampleMeal();

      await tester.pumpWidget(
        _buildThemedApp(
          theme: AppTheme.darkTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: meal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MealCard), findsOneWidget);
      expect(find.text('طاجن بامية باللحمة الضاني'), findsOneWidget);
      expect(find.text('أكلة جمعة'), findsOneWidget);
      expect(find.text('اقتصادي'), findsOneWidget);
      expect(find.text('مفضلة'), findsOneWidget);
      expect(find.text('45 دقيقة'), findsOneWidget);
      expect(find.text('Cook This'), findsOneWidget);
    });

    testWidgets('R3.3: every card index renders the same mockup layout (no priority banners)', (tester) async {
      final meal1 = _createSampleMeal(id: 1, name: 'كفتة مشوية');
      final meal2 = _createSampleMeal(id: 2, name: 'كشري مصري');

      await tester.pumpWidget(
        _buildThemedApp(
          theme: AppTheme.darkTheme,
          child: SingleChildScrollView(
            child: Column(
              children: [
                MealCard(
                  meal: meal1,
                  cardIndex: 1,
                  onCookedToday: () {},
                  onLeftover: () {},
                ),
                MealCard(
                  meal: meal2,
                  cardIndex: 2,
                  onCookedToday: () {},
                  onLeftover: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('كفتة مشوية'), findsOneWidget);
      expect(find.text('كشري مصري'), findsOneWidget);
      // Two cook buttons + two leftover buttons, one pair per card
      expect(find.text('Cook This'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('btn_leftover')), findsNWidgets(2));
    });
  });
}
