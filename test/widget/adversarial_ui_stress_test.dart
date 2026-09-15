import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/core/router/app_router.dart';
import 'package:daily_meal/features/home/presentation/home_screen.dart';
import 'package:daily_meal/features/home/presentation/widgets/meal_card.dart';
import 'package:daily_meal/features/home/presentation/widgets/quick_actions.dart';
import 'package:daily_meal/features/home/presentation/widgets/spin_wheel_dialog.dart';
import 'package:daily_meal/features/vault/presentation/meal_vault_screen.dart';
import 'package:daily_meal/features/vault/presentation/add_edit_meal_dialog.dart';
import 'package:daily_meal/features/vault/presentation/widgets/delete_meal_dialog.dart';
import 'package:daily_meal/features/vault/presentation/widgets/meal_vault_card.dart';

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

/// Test wrapper providing standard Arabic RTL Material 3 environment
Widget buildTestApp({
  required Widget child,
  ProviderContainer? container,
  List<Override> overrides = const [],
  Size surfaceSize = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final app = MaterialApp(
    title: 'أكلة النهاردة اختبار',
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

  group('DIMENSION 1: Ultra-Long Meal Names (>150 Characters) & Extreme Arabic Strings', () {
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

    testWidgets('1.1: MealCard gracefully renders 180+ character Arabic name without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = createTestMeal(
        id: 1,
        name: extremeArabicLongName,
        proteinType: ProteinType.fish,
        carbsType: CarbsType.rice,
        category: MealCategory.seafood,
        prepTime: 45,
        isFridaySpecial: true,
        isBudgetFriendly: true,
        isFavorite: true,
      );

      await tester.pumpWidget(
        buildTestApp(
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

      expect(tester.takeException(), isNull, reason: 'Must not trigger RenderFlex overflow');
      expect(find.byType(MealCard), findsOneWidget);
      expect(find.text('أكلة جمعة'), findsOneWidget);
      expect(find.text('اقتصادي'), findsOneWidget);
      expect(find.text('مفضلة'), findsOneWidget);
    });

    testWidgets('1.2: MealVaultCard gracefully renders 180+ character Arabic name in list item', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = createTestMeal(
        id: 10,
        name: extremeArabicLongName,
        proteinType: ProteinType.fish,
        carbsType: CarbsType.rice,
        category: MealCategory.seafood,
        prepTime: 60,
        isFridaySpecial: true,
        isBudgetFriendly: true,
        isFavorite: false,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: MealVaultCard(
            meal: meal,
            onEdit: () {},
            onDelete: () {},
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must not overflow in MealVaultCard Row');
      expect(find.byKey(const Key('meal_card_10')), findsOneWidget);
      expect(find.byKey(const Key('meal_edit_button_10')), findsOneWidget);
      expect(find.byKey(const Key('meal_delete_button_10')), findsOneWidget);
    });

    testWidgets('1.3: DeleteMealDialog contains 180+ character name without dialog overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = createTestMeal(
        id: 99,
        name: extremeArabicLongName,
        proteinType: ProteinType.beef,
        carbsType: CarbsType.pasta,
        category: MealCategory.ovenBaked,
        prepTime: 30,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DeleteMealDialog.show(ctx, meal),
              child: const Text('افتح الحوار'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('افتح الحوار'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Delete dialog must not overflow');
      expect(find.text('حذف الأكلة'), findsWidgets);
      expect(find.byKey(const Key('meal_delete_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('meal_delete_confirm_button')), findsOneWidget);
    });

    testWidgets('1.4: SpinWheelDialog handles extreme Arabic meal names and winner banner', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final candidates = <Meal>[
        createTestMeal(
          id: 1,
          name: extremeArabicLongName,
          proteinType: ProteinType.beef,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTime: 40,
        ),
        createTestMeal(
          id: 2,
          name: 'طاجن كوارع بالصلصة والحمص في طاجن فخار بلدي مسبك بالثوم والخل البلدي الأصيل',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.bread,
          category: MealCategory.ovenBaked,
          prepTime: 90,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
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

      final ex = tester.takeException();
      expect(ex, isNull, reason: 'SpinWheelDialog painter and layout should render long names without RenderFlex overflow: $ex');
      expect(find.text('عجلة الحظ 🎡'), findsOneWidget);

      // Trigger spin
      await tester.tap(find.text('ابدأ التدوير'));
      // Advance animation
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Wheel animation and winner selection must not overflow');
      expect(find.text('لف تاني'), findsOneWidget);
    });
  });

  group('DIMENSION 2: Extreme Prep Times & Input Boundaries', () {
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

    testWidgets('2.1: formatPrepTime outputs correct Arabic strings for 0, 1, 10, 11, and 99999 minutes', (tester) async {
      expect(formatPrepTime(0), equals('0 دقائق'));
      expect(formatPrepTime(1), equals('1 دقائق'));
      expect(formatPrepTime(5), equals('5 دقائق'));
      expect(formatPrepTime(10), equals('10 دقائق'));
      expect(formatPrepTime(11), equals('11 دقيقة'));
      expect(formatPrepTime(99999), equals('99999 دقيقة'));
      expect(formatPrepTime(-5), equals('-5 دقائق'));

      final extremeMeal = createTestMeal(
        id: 5,
        name: 'كوارع معتقة بطيئة الطبخ',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.bread,
        category: MealCategory.egyptianTraditional,
        prepTime: 99999,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: SingleChildScrollView(
            child: MealCard(
              meal: extremeMeal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99999 دقيقة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.2: AddEditMealDialog enforces positive prep time validation and rejects 0 or negative', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AddEditMealDialog.show(ctx),
              child: const Text('إضافة'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      // Enter valid name
      await tester.enterText(find.byKey(const Key('meal_form_name_field')), 'مسقعة باللحمة المفرومة');

      // Enter prep time = 0
      await tester.enterText(find.byKey(const Key('meal_form_prep_time_field')), '0');
      await tester.tap(find.byKey(const Key('meal_form_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('يجب إدخال عدد صحيح أكبر من صفر'), findsOneWidget);

      // Enter prep time = -10
      await tester.enterText(find.byKey(const Key('meal_form_prep_time_field')), '-10');
      await tester.tap(find.byKey(const Key('meal_form_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('يجب إدخال عدد صحيح أكبر من صفر'), findsOneWidget);

      // Enter valid prep time = 45
      await tester.enterText(find.byKey(const Key('meal_form_prep_time_field')), '45');
      await tester.tap(find.byKey(const Key('meal_form_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('تمت إضافة "مسقعة باللحمة المفرومة" إلى خزانة الأكلات'), findsOneWidget);
    });
  });

  group('DIMENSION 3: 0-Meal Vault Boundary States (Zero Candidates)', () {
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

    testWidgets('3.1: HomeScreen displays empty state when vault has 0 meals', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const HomeScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('خزنة الأكلات فارغة!'), findsOneWidget);
      expect(find.text('ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.'), findsOneWidget);
      expect(find.text('أضف أكلتك الأولى'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3.2: MealVaultScreen displays VaultEmptyState when 0 meals exist', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const MealVaultScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 أكلة'), findsOneWidget);
      expect(find.text('خزنة الأكلات فارغة!'), findsOneWidget);
      expect(find.byKey(const Key('vault_empty_add_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_add_fab')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3.3: SpinWheelDialog with fewer than 2 candidates shows safety warning and does not crash', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => const SpinWheelDialog(candidates: []),
                );
              },
              child: const Text('عجلة فارغة'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('عجلة فارغة'));
      await tester.pumpAndSettle();

      expect(find.text('عجلة الحظ تحتاج إلى وجبتين على الأقل في الاقتراحات للتدوير!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();
    });
  });

  group('DIMENSION 4: 100+ Meals in Vault (Scalability Stress)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.appSettingsDao.ensureSettings();
      await db.mealsDao.deleteAllMeals();

      // Seed 120 unique meals
      for (int i = 1; i <= 120; i++) {
        final protein = ProteinType.values[i % ProteinType.values.length];
        final carbs = CarbsType.values[i % CarbsType.values.length];
        final category = MealCategory.values[i % MealCategory.values.length];

        await db.mealsDao.insertMeal(
          MealsCompanion.insert(
            name: 'وجبة تجريبية رقم $i بنكهة مصرية',
            proteinType: protein,
            carbsType: carbs,
            category: category,
            prepTime: 20 + (i % 60),
            isFridaySpecial: Value(i % 5 == 0),
            isBudgetFriendly: Value(i % 3 == 0),
            isFavorite: Value(i % 4 == 0),
          ),
        );
      }

      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('4.1: MealVaultScreen smoothly handles 120 meals, fast scrolling, and search filtering', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          child: const MealVaultScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Counter in AppBar displays 120 meals
      expect(find.text('120 أكلة'), findsOneWidget);

      // Fast scroll down 3000px
      await tester.drag(find.byKey(const Key('vault_grid_view')), const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Virtualized scrolling through 120 items must be error-free');

      // Scroll back up
      await tester.drag(find.byKey(const Key('vault_grid_view')), const Offset(0, 3000));
      await tester.pumpAndSettle();

      // Search for specific meal 'رقم 77'
      await tester.enterText(find.byKey(const Key('vault_search_field')), 'رقم 77');
      await tester.pumpAndSettle();

      expect(find.text('وجبة تجريبية رقم 77 بنكهة مصرية'), findsOneWidget);
      expect(find.byKey(const Key('vault_search_clear_button')), findsOneWidget);

      // Clear search
      await tester.tap(find.byKey(const Key('vault_search_clear_button')));
      await tester.pumpAndSettle();

      // Search for non-existent item
      await tester.enterText(find.byKey(const Key('vault_search_field')), 'كافيار بالزعفران المستورد');
      await tester.pumpAndSettle();

      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
      expect(find.byKey(const Key('vault_clear_filters_button')), findsOneWidget);

      // Reset filters button
      await tester.tap(find.byKey(const Key('vault_clear_filters_button')));
      await tester.pumpAndSettle();

      expect(find.text('120 أكلة'), findsOneWidget);
    });
  });

  group('DIMENSION 5: Rapid Tab Switching & Router Stress', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.appSettingsDao.ensureSettings();
      await db.appSettingsDao.updateSettings(
        const AppSettingsCompanion(isFirstRun: Value(false)),
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('5.1: Rapid switching between all 4 tabs does not crash or lose state', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Wait for the async splash screen navigation to resolve
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final homeTab = find.byKey(const ValueKey('nav_destination_home'));
      final vaultTab = find.byKey(const ValueKey('nav_destination_vault'));
      final historyTab = find.byKey(const ValueKey('nav_destination_history'));
      final settingsTab = find.byKey(const ValueKey('nav_destination_settings'));

      expect(homeTab, findsOneWidget);
      expect(vaultTab, findsOneWidget);
      expect(historyTab, findsOneWidget);
      expect(settingsTab, findsOneWidget);

      // Rapidly switch tabs 20 times in quick succession without pumpAndSettle in-between
      final tabs = [vaultTab, historyTab, settingsTab, homeTab];
      for (int i = 0; i < 20; i++) {
        await tester.tap(tabs[i % tabs.length]);
        await tester.pump(const Duration(milliseconds: 30));
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Rapid navigation switching must not throw');

      // Unmount the widget tree and pump to cleanly cancel drift stream queries before teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('DIMENSION 6: Viewport Size & Accessibility Text Scaling Stress', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.appSettingsDao.ensureSettings();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('6.1: QuickActions and MealCard on compact 320px width phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meal = createTestMeal(
        id: 1,
        name: 'ملوخية بالأرانب مع أرز بالشعرية',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        category: MealCategory.egyptianTraditional,
        prepTime: 35,
        isFridaySpecial: true,
        isBudgetFriendly: false,
        isFavorite: true,
      );

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 568),
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

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'QuickActions buttons on 320px screen must not trigger RenderFlex overflow: $exception');
      expect(find.byKey(const ValueKey('btn_cooked_today')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_leftover')), findsOneWidget);
    });

    testWidgets('6.2: QuickActions with 1.4x accessibility TextScaler on 360px screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(360, 640),
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

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'QuickActions under 1.4x text scaling must not trigger RenderFlex overflow: $exception');
    });

    testWidgets('6.3: SpinWheelDialog on small height viewport (550px)', (tester) async {
      tester.view.physicalSize = const Size(360, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final candidates = <Meal>[
        createTestMeal(
          id: 1,
          name: 'حواوشي إسكندراني',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.bread,
          category: MealCategory.fastFood,
          prepTime: 25,
        ),
        createTestMeal(
          id: 2,
          name: 'كشري مصري بالصلصة والدقة',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTime: 40,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(360, 550),
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => SpinWheelDialog(candidates: candidates),
                );
              },
              child: const Text('عرض العجلة'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('عرض العجلة'));
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'SpinWheelDialog on 550px height must not overflow: $exception');
    });
  });
}
