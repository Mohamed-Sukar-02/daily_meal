import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/features/home/presentation/home_screen.dart';
import 'package:daily_meal/features/home/presentation/widgets/meal_card.dart';
import 'package:daily_meal/features/home/presentation/widgets/quick_actions.dart';
import 'package:daily_meal/features/home/presentation/widgets/spin_wheel_dialog.dart';
import 'package:daily_meal/features/vault/presentation/add_edit_meal_dialog.dart';
import 'package:daily_meal/features/vault/presentation/widgets/delete_meal_dialog.dart';
import 'package:daily_meal/features/vault/presentation/widgets/meal_vault_card.dart';
import 'package:daily_meal/features/vault/presentation/widgets/vault_empty_state.dart';
import 'package:daily_meal/features/history/presentation/history_screen.dart';
import 'package:daily_meal/features/settings/presentation/settings_screen.dart';

Meal createTestMeal({
  required int id,
  required String name,
  ProteinType proteinType = ProteinType.beef,
  CarbsType carbsType = CarbsType.rice,
  MealCategory category = MealCategory.egyptianTraditional,
  int prepTime = 30,
  bool isFridaySpecial = false,
  bool isBudgetFriendly = false,
  bool isFavorite = false,
  String? photoPath,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return Meal(
    id: id,
    name: name,
    photoPath: photoPath,
    proteinType: proteinType,
    carbsType: carbsType,
    category: category,
    prepTime: prepTime,
    isFridaySpecial: isFridaySpecial,
    isBudgetFriendly: isBudgetFriendly,
    isFavorite: isFavorite,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

Widget buildTestApp({
  required Widget child,
  ProviderContainer? container,
  List<Override> overrides = const [],
  Size surfaceSize = const Size(320, 550),
  TextScaler textScaler = const TextScaler.linear(1.4),
}) {
  final app = MaterialApp(
    title: 'Challenger UI Stress Test',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );

  return MediaQuery(
    data: MediaQueryData(
      size: surfaceSize,
      textScaler: textScaler,
    ),
    child: container != null
        ? UncontrolledProviderScope(
            container: container,
            child: app,
          )
        : ProviderScope(
            overrides: overrides,
            child: app,
          ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const extremeArabicLongName =
      'طاجن سمك وقار إسكندراني بلدي بالخل والتوم والليمون المعصفر والصلصة الحارة المسبكة بالفرن مع بطاطس محمرة وأرز صيادية وسلطة بلدي ومخلل لفت وفلفل حامي مشوي على الفحم';

  group('CHALLENGER VERIFICATION: Passing Baseline under Extreme Constraints', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.appSettingsDao.ensureSettings();
      await db.mealsDao.deleteAllMeals();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('PASS-1: QuickActions standalone on 320px width + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: QuickActions(
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PASS-2: MealCard with 180+ chars name on 320x550 + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = createTestMeal(
        id: 1,
        name: extremeArabicLongName,
        prepTime: 99999,
        isFridaySpecial: true,
        isBudgetFriendly: true,
        isFavorite: true,
      );

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: SingleChildScrollView(
            child: MealCard(
              meal: meal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PASS-3: HomeScreen with 3 valid long meals on 320x550 + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      for (int i = 1; i <= 3; i++) {
        // Construct exact 120-character string (maximum valid length for MealsTable.name schema: min 1, max 120)
        final exact120CharName = '${extremeArabicLongName.substring(0, 118)} $i';
        expect(exact120CharName.length, equals(120), reason: 'Must test maximum allowed schema boundary of 120 chars');
        await db.mealsDao.insertMeal(
          MealsCompanion.insert(
            name: exact120CharName,
            proteinType: ProteinType.values[i % ProteinType.values.length],
            carbsType: CarbsType.values[i % CarbsType.values.length],
            category: MealCategory.values[i % MealCategory.values.length],
            prepTime: 35 * i,
            isFridaySpecial: Value(i == 1),
            isBudgetFriendly: Value(i == 2),
            isFavorite: Value(i == 3),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: const HomeScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('PASS-4: SpinWheelDialog on 320x550 + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final candidates = [
        createTestMeal(id: 1, name: extremeArabicLongName),
        createTestMeal(id: 2, name: 'طاجن كوارع معتق ومسبك بصلصة الطماطم الحارة والخل والثوم البلدي الأصيل'),
      ];

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => SpinWheelDialog(candidates: candidates),
                );
              },
              child: const Text('عجلة'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('عجلة'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ابدأ التدوير'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PASS-5: SettingsScreen on 320x550 + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: const SettingsScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('CHALLENGER REGRESSION: Verified Zero RenderFlex Overflows in Constrained Viewports', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.appSettingsDao.ensureSettings();
      await db.mealsDao.deleteAllMeals();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('PASS-6: redesigned MealVaultCard no longer overflows on 320px width + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = createTestMeal(
        id: 42,
        name: extremeArabicLongName,
        prepTime: 45,
        isFridaySpecial: true,
        isBudgetFriendly: true,
      );

      String? overflowError;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('RenderFlex overflowed')) {
          overflowError = details.summary.toString();
        }
      };

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: MealVaultCard(
            meal: meal,
            onEdit: () {},
            onDelete: () {},
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(overflowError, isNull, reason: 'Redesigned vault card must not overflow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('PASS-2: AddEditMealDialog header & actions no longer overflow on 320px width + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final existingMeal = createTestMeal(
        id: 7,
        name: extremeArabicLongName,
        prepTime: 99999,
        isFridaySpecial: true,
        isBudgetFriendly: true,
        isFavorite: true,
      );

      final overflows = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('RenderFlex overflowed')) {
          overflows.add(details.summary.toString());
        }
      };

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AddEditMealDialog.show(ctx, mealToEdit: existingMeal),
              child: const Text('تعديل'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(overflows.isEmpty, isTrue, reason: 'AddEditMealDialog header and action rows must not overflow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('PASS-3: DeleteMealDialog content no longer overflows on 550px height + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = createTestMeal(
        id: 99,
        name: extremeArabicLongName,
      );

      String? overflowError;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('RenderFlex overflowed')) {
          overflowError = details.summary.toString();
        }
      };

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DeleteMealDialog.show(ctx, meal),
              child: const Text('حذف'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(overflowError, isNull, reason: 'DeleteMealDialog must scroll cleanly without vertical overflow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('PASS-7: redesigned VaultEmptyState no longer overflows on 550px height + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? overflowError;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('RenderFlex overflowed')) {
          overflowError = details.summary.toString();
        }
      };

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: SizedBox(
            height: 280,
            child: VaultEmptyState(
              isSearchResult: false,
              onAction: () {},
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(overflowError, isNull, reason: 'Redesigned empty state must not overflow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('PASS-5: HistoryScreen empty state no longer overflows on 550px height + 1.4x textScaler', (tester) async {
      tester.view.physicalSize = const Size(320, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? overflowError;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('RenderFlex overflowed')) {
          overflowError = details.summary.toString();
        }
      };

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 550),
          textScaler: const TextScaler.linear(1.4),
          child: const SizedBox(
            height: 440,
            child: HistoryScreen(),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldHandler;

      expect(overflowError, isNull, reason: 'HistoryScreen empty state must fit or scroll without vertical overflow');
      expect(tester.takeException(), isNull);
    });
  });
}
