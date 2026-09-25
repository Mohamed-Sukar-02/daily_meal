import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/meals/presentation/meal_screen.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/providers/discovery_providers.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

// ---------------------------------------------------------------------------
// The full meal screen's two local actions: edit and delete.
//
// What is pinned here is that both are the *shared* surfaces the rest of the
// app already uses (the vault's edit sheet and the delete confirmation), that
// the screen needs no manual refresh after a save because it reads the drift
// stream, that a confirmed delete really removes the row and leaves the route,
// and that a cloud-only meal — which has no local row to change — offers
// neither.
// ---------------------------------------------------------------------------

const String _cloudId = 'cloud-1';

/// A meal row as the vault stores it: [name] is the display name,
/// [shortName] the app bar one, [notes] the dish panel body.
Future<int> _insertMeal(
  AppDatabase db, {
  required String name,
  String? shortName,
  String? notes,
  String? cloudId,
}) {
  return db.mealsDao.insertMeal(
    MealsCompanion(
      name: drift.Value(name),
      shortName: drift.Value(shortName),
      notes: drift.Value(notes),
      cloudId: drift.Value(cloudId),
      proteinType: const drift.Value(ProteinType.chicken),
      carbsType: const drift.Value(CarbsType.rice),
      category: const drift.Value(MealCategory.egyptianTraditional),
      prepTime: const drift.Value(45),
    ),
  );
}

CloudMeal _cloudMeal({required String name, int prepTimeMinutes = 45}) {
  return CloudMeal(
    id: _cloudId,
    name: name,
    proteinType: 'chicken',
    carbsType: 'rice',
    category: 'tabeekh',
    prepTimeMinutes: prepTimeMinutes,
    createdAt: DateTime(2026, 9, 20, 12),
  );
}

/// Boots the real app (real router, real drift database) and pushes its own
/// `/meal/:id` route on top of the shell — the same way the details sheet's
/// "full details" button reaches the screen.
Future<(AppDatabase, int)> _pumpMealRoute(
  WidgetTester tester, {
  required String name,
  String? shortName,
  String? notes,
  bool withHistoryEntry = false,
}) async {
  final db = await pumpApp(tester);
  final id = await _insertMeal(
    db,
    name: name,
    shortName: shortName,
    notes: notes,
  );
  if (withHistoryEntry) {
    await db.mealHistoryDao.logMeal(
      mealId: id,
      mealName: name,
      proteinType: ProteinType.chicken,
      carbsType: CarbsType.rice,
      cookedAt: DateTime(2026, 9, 20, 12),
    );
  }
  await tester.pumpAndSettle();

  GoRouter.of(
    tester.element(find.byKey(const ValueKey('nav_destination_home'))),
  ).push('/meal/$id');
  await tester.pumpAndSettle();

  expect(
    find.byKey(const Key('meal_screen')),
    findsOneWidget,
    reason: '/meal/:id must land on the full meal screen',
  );
  return (db, id);
}

/// A screen pumped straight onto a route, with the vault left to [db] (or just
/// [localMeals]) and the cloud read faked by [cloud].
Future<void> _pumpScreen(
  WidgetTester tester, {
  required AppDatabase db,
  required Widget Function() screen,
  CloudMeal? cloud,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        favoriteMealsProvider.overrideWith((ref) => Stream.value(const [])),
        if (cloud != null)
          cloudMealByIdProvider.overrideWith((ref, arg) async => cloud),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(useMaterial3: true),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: screen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// Opens the app bar overflow and taps [item].
Future<void> _runAction(WidgetTester tester, Key item) async {
  await tester.tap(find.byKey(const Key('meal_screen_actions_button')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(item),
    findsOneWidget,
    reason: 'the overflow must carry the action',
  );
  await tester.tap(find.byKey(item));
  await tester.pumpAndSettle();
}

/// A success toast leaves a 1.5 s timer behind, which
/// [AutomatedTestWidgetsFlutterBinding] refuses to see pending at teardown.
Future<void> _runOutToasts(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 2));

String _prefilledName(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const Key('meal_form_name_field')))
    .controller!
    .text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── /meal/:id — a row the vault holds ─────────────────────────────────────

  testWidgets('edit opens the shared sheet prefilled with this meal', (
    tester,
  ) async {
    const name = 'ملوخية خضراء بالفراخ';
    final (db, _) = await _pumpMealRoute(
      tester,
      name: name,
      shortName: 'ملوخية',
      notes: 'تتقلى الثوم كويس قبل الإضافة',
    );
    final strings = AppStrings.of(
      tester.element(find.byKey(const Key('meal_screen'))),
    );

    expect(find.byTooltip(strings.mealScreenActionsMenu), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal_screen_actions_button')));
    await tester.pumpAndSettle();
    expect(find.text(strings.edit), findsOneWidget);
    expect(find.text(strings.delete), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal_screen_edit_action')));
    await tester.pumpAndSettle();

    // The very sheet the vault cards open — not a second edit form.
    expect(find.byKey(const Key('meal_form_save_button')), findsOneWidget);
    expect(find.text(strings.quickAddMealTitle), findsOneWidget);
    expect(_prefilledName(tester), name, reason: 'the sheet opens on this meal');

    await tearDownApp(tester, db);
  });

  testWidgets('saving an edit repaints the screen from the vault stream', (
    tester,
  ) async {
    const name = 'كشري بالجبن';
    const editedName = 'كشري بالدجاج';
    const notes = 'ارز وشعرية و العدس';
    final (db, id) = await _pumpMealRoute(
      tester,
      name: name,
      shortName: name,
      notes: notes,
    );

    await _runAction(tester, const Key('meal_screen_edit_action'));
    expect(find.byKey(const Key('meal_form_name_field')), findsOneWidget);
    expect(_prefilledName(tester), name);

    await tester.enterText(
      find.byKey(const Key('meal_form_name_field')),
      editedName,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('meal_form_save_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meal_form_save_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal_form_save_button')), findsNothing);
    final row = await db.mealsDao.getMealById(id);
    expect(row!.name, editedName);

    // No manual refresh anywhere in the screen: the drift stream behind
    // `allMealsProvider` re-emits and the hero repaints itself.
    expect(
      tester.widget<Text>(find.byKey(const Key('meal_screen_full_name'))).data,
      editedName,
    );
    // The notes the closed ISSUES item claims really are rendered.
    expect(find.text(notes), findsOneWidget);

    await _runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  testWidgets('delete confirms first, then removes the row and pops the route', (
    tester,
  ) async {
    const name = 'فتة الناعم';
    final (db, id) = await _pumpMealRoute(
      tester,
      name: name,
      shortName: name,
      withHistoryEntry: true,
    );
    final strings = AppStrings.of(
      tester.element(find.byKey(const Key('meal_screen'))),
    );

    await _runAction(tester, const Key('meal_screen_delete_action'));

    // The shared confirmation dialog, with the app-wide copy.
    expect(find.byKey(const Key('meal_delete_confirm_button')), findsOneWidget);
    expect(find.text(strings.deleteMealTitle), findsWidgets);
    expect(find.text(strings.deleteMealHistorySafe), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal_delete_cancel_button')));
    await tester.pumpAndSettle();
    expect(
      await db.mealsDao.getMealById(id),
      isNotNull,
      reason: 'cancelling deletes nothing',
    );
    expect(find.byKey(const Key('meal_screen')), findsOneWidget);

    await _runAction(tester, const Key('meal_screen_delete_action'));
    await tester.tap(find.byKey(const Key('meal_delete_confirm_button')));
    await tester.pumpAndSettle();

    expect(await db.mealsDao.getMealById(id), isNull);
    expect(
      find.byKey(const Key('meal_screen')),
      findsNothing,
      reason: 'a screen about a meal that is gone has nothing left to show',
    );
    expect(
      find.byKey(const ValueKey('nav_destination_home')),
      findsOneWidget,
      reason: 'and it leaves the way the user came in',
    );

    // The promised cascade: the cooking log survives, its meal link nulled.
    final history = await db.mealHistoryDao.getAllHistory();
    expect(history, hasLength(1));
    expect(history.single.mealName, name);
    expect(history.single.mealId, isNull);

    await _runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  testWidgets('the third app bar action never crowds the centred name', (
    tester,
  ) async {
    // The narrowest realistic phone: the header group has to fit here, because
    // the centred name keeps its clearance symmetric on both sides.
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    final id = await _insertMeal(
      db,
      name: 'كشري باللبن الرايب',
      shortName: 'كشري باللبن الرايب',
    );
    await _pumpScreen(tester, db: db, screen: () => MealScreen(mealId: id));

    final screenW =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final name = tester.getRect(find.byKey(const Key('meal_screen_short_name')));
    expect(
      (name.center.dx - screenW / 2).abs(),
      lessThan(1.0),
      reason: 'the name stays truly centred next to the new button',
    );

    final buttons = {
      'back': const Key('meal_screen_back_button'),
      'cloud': const Key('meal_screen_cloud_button'),
      'favorite': const Key('meal_screen_favorite_button'),
      'actions': const Key('meal_screen_actions_button'),
    };
    for (final button in buttons.entries) {
      final buttonRect = tester.getRect(find.byKey(button.value));
      expect(
        name.overlaps(buttonRect),
        isFalse,
        reason:
            'the name ($name) sits under the ${button.key} button '
            '($buttonRect) at 360dp',
      );
    }

    await tearDownApp(tester, db);
  });

  // ── /meal/cloud/:cloudId ──────────────────────────────────────────────────

  testWidgets('a cloud-only meal offers neither edit nor delete', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    const name = 'كلود اونلي فاكانسي';
    await _pumpScreen(
      tester,
      db: db,
      cloud: _cloudMeal(name: name),
      screen: () => MealScreen(cloudId: _cloudId),
    );
    final strings = const AppStrings(Locale('ar'));

    expect(find.byKey(const Key('meal_screen_full_name')), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_actions_button')), findsNothing);
    expect(find.byTooltip(strings.mealScreenActionsMenu), findsNothing);
    // What the cloud variant offers instead: the download mark.
    expect(find.byTooltip(strings.discoveryDownload), findsOneWidget);

    await tearDownApp(tester, db);
  });

  testWidgets('the cloud route edits the real local row, not its display copy', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    const name = 'طاجن الكلاوجي';
    final id = await _insertMeal(db, name: name, shortName: name);
    await tester.pump();

    // The vault holds this meal under no cloud id, so the screen shows a local
    // row with the visited cloud id borrowed for the sync mark only.
    await _pumpScreen(
      tester,
      db: db,
      cloud: _cloudMeal(name: name),
      screen: () => MealScreen(cloudId: _cloudId),
    );
    final strings = const AppStrings(Locale('ar'));

    expect(find.byKey(const Key('meal_screen_actions_button')), findsOneWidget);
    expect(find.byTooltip(strings.proposalCta), findsNothing);

    await _runAction(tester, const Key('meal_screen_edit_action'));
    expect(_prefilledName(tester), name);
    await tester.enterText(
      find.byKey(const Key('meal_form_name_field')),
      'طاجن الكلاوجي بالعيش',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('meal_form_save_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meal_form_save_button')));
    await tester.pumpAndSettle();

    final row = await db.mealsDao.getMealById(id);
    expect(row!.name, 'طاجن الكلاوجي بالعيش');
    expect(
      row.cloudId,
      isNull,
      reason: 'the borrowed display cloud id must never be written back',
    );

    await _runOutToasts(tester);
    await tearDownApp(tester, db);
  });
}
