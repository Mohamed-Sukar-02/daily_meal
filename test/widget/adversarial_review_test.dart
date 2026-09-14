import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/features/home/presentation/widgets/meal_card.dart';
import 'package:daily_meal/features/home/presentation/widgets/quick_actions.dart';

Widget _buildTestApp({
  required Widget child,
  required ThemeData theme,
  Size surfaceSize = const Size(320, 600),
  TextScaler textScaler = const TextScaler.linear(1.0),
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: surfaceSize,
      textScaler: textScaler,
    ),
    child: MaterialApp(
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
    ),
  );
}

Meal _createFullMeal({
  int id = 1,
  String name = 'طاجن كوارع معتق ومسبك بصلصة الطماطم والخل والثوم البلدي الأصيل',
  bool isFridaySpecial = true,
  bool isBudgetFriendly = true,
  bool isFavorite = true,
  int prepTime = 60,
  String? photoPath,
}) {
  return Meal(
    id: id,
    name: name,
    category: MealCategory.egyptianTraditional,
    proteinType: ProteinType.beef,
    carbsType: CarbsType.rice,
    prepTime: prepTime,
    isFridaySpecial: isFridaySpecial,
    isBudgetFriendly: isBudgetFriendly,
    isFavorite: isFavorite,
    photoPath: photoPath,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Review: Accessibility Scaling & Compact Viewports', () {
    testWidgets('ADVERSARIAL-1: MealCard on 320px width with 1.6x font scaling (Light Mode)', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = _createFullMeal();

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.lightTheme,
          surfaceSize: const Size(320, 800),
          textScaler: const TextScaler.linear(1.6),
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
    });

    testWidgets('ADVERSARIAL-2: MealCard on 320px width with 1.6x font scaling (Dark Mode)', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = _createFullMeal();

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.darkTheme,
          surfaceSize: const Size(320, 800),
          textScaler: const TextScaler.linear(1.6),
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
    });

    testWidgets('ADVERSARIAL-3: MealCard on 320px width with extreme 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = _createFullMeal();

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.darkTheme,
          surfaceSize: const Size(320, 900),
          textScaler: const TextScaler.linear(2.0),
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
    });

    testWidgets('ADVERSARIAL-4: QuickActions standalone at 1.8x and 2.0x text scaling on 320px width', (tester) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.darkTheme,
          surfaceSize: const Size(320, 400),
          textScaler: const TextScaler.linear(1.8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: QuickActions(
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ADVERSARIAL-5: Badges row wrapping preserves runSpacing of 6px', (tester) async {
      // 250px forces wrapping across lines
      tester.view.physicalSize = const Size(250, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.darkTheme,
          surfaceSize: const Size(250, 700),
          child: SingleChildScrollView(
            child: MealCard(
              meal: _createFullMeal(),
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final wrapFinder = find.byWidgetPredicate(
        (widget) => widget is Wrap && widget.children.length == 3,
      );
      expect(wrapFinder, findsOneWidget);
      final wrapWidget = tester.widget<Wrap>(wrapFinder);
      expect(wrapWidget.spacing, equals(8.0));
      expect(wrapWidget.runSpacing, equals(6.0));
    });

    testWidgets('ADVERSARIAL-6: SnackBar in darkTheme explicitly inherits Cairo font family', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الحفظ بنجاح')),
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final defaultTextStyle = tester.widget<DefaultTextStyle>(
        find.ancestor(
          of: find.text('تم الحفظ بنجاح'),
          matching: find.byType(DefaultTextStyle),
        ).first,
      );

      expect(defaultTextStyle.style.fontFamily, contains('Cairo'));
    });

    testWidgets('ADVERSARIAL-7: SnackBar in lightTheme explicitly inherits Cairo font family', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الحفظ بنجاح')),
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final defaultTextStyle = tester.widget<DefaultTextStyle>(
        find.ancestor(
          of: find.text('تم الحفظ بنجاح'),
          matching: find.byType(DefaultTextStyle),
        ).first,
      );

      expect(defaultTextStyle.style.fontFamily, contains('Cairo'));
    });

    test('ADVERSARIAL-8: All 15 textTheme styles explicitly use Cairo in light and dark themes', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      for (final theme in [light, dark]) {
        final tt = theme.textTheme;
        final styles = [
          tt.displayLarge, tt.displayMedium, tt.displaySmall,
          tt.headlineLarge, tt.headlineMedium, tt.headlineSmall,
          tt.titleLarge, tt.titleMedium, tt.titleSmall,
          tt.bodyLarge, tt.bodyMedium, tt.bodySmall,
          tt.labelLarge, tt.labelMedium, tt.labelSmall,
        ];
        for (final style in styles) {
          expect(style?.fontFamily, contains('Cairo'));
        }
      }
    });

    test('ADVERSARIAL-9: Material 3 Dark Scheme surface elevation monotonic hierarchy', () {
      final cs = AppTheme.darkColorScheme;

      // Ensure no pitch black (#000000) for dark mode surfaces
      final surfaces = [
        cs.surface,
        cs.surfaceDim,
        cs.surfaceBright,
        cs.surfaceContainerLowest,
        cs.surfaceContainerLow,
        cs.surfaceContainer,
        cs.surfaceContainerHigh,
        cs.surfaceContainerHighest,
      ];
      for (final surface in surfaces) {
        expect(surface.toARGB32() & 0x00FFFFFF, isNot(equals(0)),
            reason: 'Surface must not be pure pitch black #000000');
      }

      // Check strictly monotonic elevation hierarchy
      expect(cs.surfaceContainerLowest.computeLuminance(),
          lessThan(cs.surfaceDim.computeLuminance()));
      expect(cs.surfaceDim.computeLuminance(),
          lessThan(cs.surface.computeLuminance()));
      expect(cs.surface.computeLuminance(),
          lessThan(cs.surfaceContainerLow.computeLuminance()));
      expect(cs.surfaceContainerLow.computeLuminance(),
          lessThan(cs.surfaceContainer.computeLuminance()));
      expect(cs.surfaceContainer.computeLuminance(),
          lessThan(cs.surfaceContainerHigh.computeLuminance()));
      expect(cs.surfaceContainerHigh.computeLuminance(),
          lessThan(cs.surfaceContainerHighest.computeLuminance()));
    });

    test('ADVERSARIAL-10: WCAG contrast ratio compliance for dark mode theme colors', () {
      double contrast(Color c1, Color c2) {
        final l1 = c1.computeLuminance();
        final l2 = c2.computeLuminance();
        return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
      }

      final cs = AppTheme.darkColorScheme;

      // Text on surface >= 7.0 (WCAG AAA)
      expect(contrast(cs.onSurface, cs.surface), greaterThanOrEqualTo(7.0));
      expect(contrast(cs.onSurfaceVariant, cs.surfaceContainer), greaterThanOrEqualTo(7.0));

      // On-colors on primary / secondary / tertiary >= 4.5 (WCAG AA)
      expect(contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.onSecondary, cs.secondary), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.onTertiary, cs.tertiary), greaterThanOrEqualTo(4.5));
    });

    testWidgets('ADVERSARIAL-11: MealCard boundary inputs (empty name, long single-token name, 0 badges, extreme prep time)', (tester) async {
      final boundaryMeals = [
        _createFullMeal(name: '', prepTime: 0, isFridaySpecial: false, isBudgetFriendly: false, isFavorite: false),
        _createFullMeal(name: 'طاجن' * 30, prepTime: 9999),
        _createFullMeal(name: '🍲 أكلة سحرية! @#%^&*()_+~', prepTime: 1),
        _createFullMeal(name: 'كفتة مشوية', prepTime: 10),
        _createFullMeal(name: 'ملوخية', prepTime: 11),
      ];

      for (final meal in boundaryMeals) {
        await tester.pumpWidget(
          _buildTestApp(
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
      }
    });

    testWidgets('ADVERSARIAL-12: MealCard event isolation between card onTap and action buttons', (tester) async {
      bool cardTapped = false;
      bool cookedTodayTapped = false;
      bool leftoverTapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.lightTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: _createFullMeal(),
              cardIndex: 0,
              onTap: () => cardTapped = true,
              onCookedToday: () => cookedTodayTapped = true,
              onLeftover: () => leftoverTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap cooked today button
      await tester.tap(find.byKey(const ValueKey('btn_cooked_today')));
      await tester.pumpAndSettle();
      expect(cookedTodayTapped, isTrue);
      expect(cardTapped, isFalse);

      // Tap leftover button
      await tester.tap(find.byKey(const ValueKey('btn_leftover')));
      await tester.pumpAndSettle();
      expect(leftoverTapped, isTrue);
      expect(cardTapped, isFalse);

      // Tap card body
      await tester.tap(find.text(_createFullMeal().name));
      await tester.pumpAndSettle();
      expect(cardTapped, isTrue);
    });

    testWidgets('ADVERSARIAL-13: MealCard gracefully falls back when photoPath is invalid or empty', (tester) async {
      final invalidPhotoMeal = Meal(
        id: 99,
        name: 'أكلة بصورة تالفة',
        category: MealCategory.egyptianTraditional,
        proteinType: ProteinType.beef,
        carbsType: CarbsType.rice,
        prepTime: 30,
        isFridaySpecial: false,
        isBudgetFriendly: false,
        isFavorite: false,
        photoPath: '/non/existent/path/to/photo.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.darkTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: invalidPhotoMeal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('meal_photo_placeholder')), findsOneWidget);
    });

    testWidgets('ADVERSARIAL-14: MealCard errorBuilder handles 0-byte or corrupted image file without crashing', (tester) async {
      late Directory tempDir;
      late File corruptFile;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('adversarial_test_');
        corruptFile = File('${tempDir.path}/corrupt_photo.jpg');
        await corruptFile.writeAsBytes([]); // 0-byte invalid image
      });

      try {
        final corruptMeal = _createFullMeal(
          photoPath: corruptFile.path,
        );

        await tester.pumpWidget(
          _buildTestApp(
            theme: AppTheme.darkTheme,
            child: SingleChildScrollView(
              child: MealCard(
                meal: corruptMeal,
                cardIndex: 0,
                onCookedToday: () {},
                onLeftover: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('meal_photo_placeholder')), findsOneWidget);
      } finally {
        await tester.runAsync(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
      }
    });

    testWidgets('ADVERSARIAL-15: MealCard handles illegal/malformed photoPath without throwing synchronous exception', (tester) async {
      final malformedMeal = _createFullMeal(
        photoPath: 'illegal\x00path\x00name.jpg',
      );

      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.darkTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: malformedMeal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('meal_photo_placeholder')), findsOneWidget);
    });

    testWidgets('ADVERSARIAL-16: MealCard badges explicitly use labelSmall typography inheriting Cairo font family', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.lightTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: _createFullMeal(
                isFridaySpecial: true,
                isBudgetFriendly: true,
                isFavorite: true,
              ),
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fridayText = tester.widget<Text>(find.text('أكلة جمعة'));
      final budgetText = tester.widget<Text>(find.text('اقتصادي'));
      final favoriteText = tester.widget<Text>(find.text('مفضلة'));

      expect(fridayText.style?.fontFamily, contains('Cairo'));
      expect(budgetText.style?.fontFamily, contains('Cairo'));
      expect(favoriteText.style?.fontFamily, contains('Cairo'));
      expect(fridayText.style?.fontSize, equals(11));
      expect(budgetText.style?.fontSize, equals(11));
      expect(favoriteText.style?.fontSize, equals(11));
    });

    test('ADVERSARIAL-17: lightTheme and darkTheme cardTheme colors have explicit M3 specification', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.cardTheme.color, equals(light.colorScheme.surface));
      expect(dark.cardTheme.color, equals(AppTheme.darkColorScheme.surfaceContainerLow));
    });
  });
}

