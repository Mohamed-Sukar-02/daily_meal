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
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// The meal screen cloud mark: download · upload · sync · sync-with-pending-
// cloud-changes.
//
// The last one is the one that matters — the mark turns orange only when the
// cloud row genuinely disagrees with the local one, and that is the single
// entry point to the sync window.
//
// Every state is exercised twice: once on `/meal/:id`, where the screen opens
// on a vault row it already holds, and once on `/meal/cloud/:cloudId`, where
// the route only says the caller had no id to open with and the vault is
// consulted for the real state.
// ---------------------------------------------------------------------------

const String _cloudId = 'cloud-1';
const String _name = 'ملوخية خضراء بالفراخ';

Meal _localMeal({int id = 7, String? cloudId, int prepTime = 45}) {
  final now = DateTime(2026, 9, 22, 12);
  return Meal(
    id: id,
    name: _name,
    nameNormalized: _name,
    photoPath: null,
    proteinType: ProteinType.chicken,
    carbsType: CarbsType.rice,
    category: MealCategory.egyptianTraditional,
    prepTime: prepTime,
    isFridaySpecial: false,
    isBudgetFriendly: false,
    isFavorite: false,
    isStarterMeal: false,
    createdAt: now,
    updatedAt: now,
    cloudId: cloudId,
  );
}

CloudMeal _cloudMeal({int prepTimeMinutes = 45, String? name}) {
  return CloudMeal(
    id: _cloudId,
    name: name ?? _name,
    proteinType: 'chicken',
    carbsType: 'rice',
    category: 'tabeekh',
    prepTimeMinutes: prepTimeMinutes,
    createdAt: DateTime(2026, 9, 20, 12),
  );
}

/// Pumps [MealScreen] over a vault holding [localMeals] (or just [meal]).
///
/// [meal] doubles as the row the local route opens on, so a test that only
/// cares about the cloud route can leave it out and pass the whole vault
/// through [localMeals] instead.
Future<void> _pump(
  WidgetTester tester, {
  Meal? meal,
  List<Meal>? localMeals,
  CloudMeal? cloud,
  bool viaCloudRoute = false,
  AppDatabase? db,
}) async {
  final effectiveMeals = localMeals ?? (meal != null ? [meal] : const <Meal>[]);
  final targetMealId =
      meal?.id ?? (effectiveMeals.isNotEmpty ? effectiveMeals.first.id : 1);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allMealsProvider.overrideWith((ref) => Stream.value(effectiveMeals)),
        favoriteMealsProvider.overrideWith((ref) => Stream.value(const [])),
        if (cloud != null)
          cloudMealByIdProvider.overrideWith((ref, arg) async => cloud),
        if (db != null) appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: viaCloudRoute
              ? MealScreen(cloudId: _cloudId)
              : MealScreen(mealId: targetMealId),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Taps the orange mark and fails loudly if the window does not come up — the
/// one entry point, so every window test starts through it.
Future<void> _openSyncWindow(WidgetTester tester, AppStrings strings) async {
  await tester.tap(find.byTooltip(strings.syncWindowCloudHint));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('sync-diff-window')), findsOneWidget);
}

void main() {
  final strings = const AppStrings(Locale('ar'));

  // ── /meal/:id ─────────────────────────────────────────────────────────────

  testWidgets('a meal with no cloud copy offers the upload mark', (
    tester,
  ) async {
    await _pump(tester, meal: _localMeal());

    expect(find.byTooltip(strings.proposalCta), findsOneWidget);
    expect(find.byTooltip(strings.discoveryDownload), findsNothing);
    expect(find.byTooltip(strings.syncStateSynced), findsNothing);
    expect(find.byKey(const Key('meal_screen_cloud_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_sync_window')), findsNothing);
  });

  testWidgets('a matching cloud copy reads as plain sync, with no window', (
    tester,
  ) async {
    await _pump(
      tester,
      meal: _localMeal(cloudId: _cloudId),
      cloud: _cloudMeal(),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.syncStateSynced), findsOneWidget);
    expect(find.byTooltip(strings.syncWindowCloudHint), findsNothing);

    await tester.tap(find.byTooltip(strings.syncStateSynced));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_sync_window')), findsNothing);
    expect(find.byKey(const Key('sync-diff-window')), findsNothing);
  });

  testWidgets('a changed cloud detail turns the mark orange and opens the '
      'sync window', (tester) async {
    await _pump(
      tester,
      meal: _localMeal(cloudId: _cloudId, prepTime: 45),
      cloud: _cloudMeal(prepTimeMinutes: 60),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.syncWindowCloudHint), findsOneWidget);
    expect(find.byTooltip(strings.syncStateSynced), findsNothing);

    await _openSyncWindow(tester, strings);

    final window = find.byKey(const Key('meal_sync_window'));
    expect(
      find.descendant(of: window, matching: find.text(strings.timeLabel)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: window,
        matching: find.text(strings.prepMinutesShort(45)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: window,
        matching: find.text(strings.prepMinutesShort(60)),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('meal_sync_window_update_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('meal_sync_window_keep_button')),
      findsOneWidget,
    );
  });

  testWidgets('every disagreeing field gets its own row in the window', (
    tester,
  ) async {
    await _pump(
      tester,
      meal: _localMeal(cloudId: _cloudId, prepTime: 45),
      cloud: _cloudMeal(prepTimeMinutes: 60, name: 'ملوخية بالفراخ'),
    );
    await tester.pumpAndSettle();

    await _openSyncWindow(tester, strings);

    final window = find.byKey(const Key('meal_sync_window'));
    expect(
      find.descendant(of: window, matching: find.text(strings.mealNameLabel)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: window, matching: find.text(strings.timeLabel)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: window, matching: find.text('ملوخية بالفراخ')),
      findsOneWidget,
    );
  });

  // ── /meal/cloud/:cloudId ──────────────────────────────────────────────────

  testWidgets('the cloud-only route offers the download mark, with no local '
      'row to love', (tester) async {
    // The download mark watches the discovery notifier for its spinner, which
    // builds a dao, which wants a database — give it the in-memory one rather
    // than the on-device file it would open in the app.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pump(
      tester,
      localMeals: const [],
      cloud: _cloudMeal(),
      viaCloudRoute: true,
      db: db,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.discoveryDownload), findsOneWidget);
    expect(find.byTooltip(strings.proposalCta), findsNothing);
    expect(find.byTooltip(strings.syncStateSynced), findsNothing);
    expect(find.byKey(const Key('meal_screen_favorite_button')), findsNothing);
    expect(find.text(_name), findsWidgets);
  });

  testWidgets('the cloud route for a meal already saved locally offers the '
      'sync mark', (tester) async {
    await _pump(
      tester,
      meal: _localMeal(cloudId: _cloudId),
      cloud: _cloudMeal(),
      viaCloudRoute: true,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.syncStateSynced), findsOneWidget);
    expect(find.byTooltip(strings.discoveryDownload), findsNothing);
    expect(find.byTooltip(strings.proposalCta), findsNothing);
    expect(
      find.byKey(const Key('meal_screen_favorite_button')),
      findsOneWidget,
    );
  });

  testWidgets('the cloud route of a saved meal that disagrees opens the sync '
      'window', (tester) async {
    await _pump(
      tester,
      meal: _localMeal(cloudId: _cloudId, prepTime: 45),
      cloud: _cloudMeal(prepTimeMinutes: 60),
      viaCloudRoute: true,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.syncWindowCloudHint), findsOneWidget);

    await _openSyncWindow(tester, strings);

    final window = find.byKey(const Key('meal_sync_window'));
    expect(
      find.descendant(
        of: window,
        matching: find.text(strings.prepMinutesShort(60)),
      ),
      findsOneWidget,
    );
  });

  // A meal downloaded then detached from its cloud row carries no cloud id.
  // The visited one is the only link left, and borrowing it is what stops the
  // mark offering an upload that would duplicate the row.
  testWidgets('the cloud route adopts a name-only local match instead of '
      'offering an upload', (tester) async {
    await _pump(
      tester,
      localMeals: [_localMeal(id: 9)],
      cloud: _cloudMeal(),
      viaCloudRoute: true,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.syncStateSynced), findsOneWidget);
    expect(find.byTooltip(strings.proposalCta), findsNothing);
    expect(find.byTooltip(strings.discoveryDownload), findsNothing);
    expect(
      find.byKey(const Key('meal_screen_favorite_button')),
      findsOneWidget,
    );
  });

  // The window's two decisions, exercised end to end against an in-memory
  // vault: update rewrites the local row from the cloud copy, keep does not.
  group('sync window actions', () {
    // The seeded vault owns small ids, so the row under test takes whatever
    // id the insert returns and the screen is pointed at that same row.
    Future<(AppDatabase, int)> pumpDifferingMeal(WidgetTester tester) async {
      // MealsDao.insertMeal consults the starter-meal blacklist; without a
      // mock the platform channel never answers under the test binding.
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 9, 22, 12);
      final id = await db.mealsDao.insertMeal(
        MealsCompanion.insert(
          name: _name,
          nameNormalized: const drift.Value(_name),
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTime: 45,
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
          cloudId: const drift.Value(_cloudId),
        ),
      );
      await _pump(
        tester,
        meal: _localMeal(id: id, cloudId: _cloudId, prepTime: 45),
        cloud: _cloudMeal(prepTimeMinutes: 60),
        db: db,
      );
      final strings = const AppStrings(Locale('ar'));
      await _openSyncWindow(tester, strings);
      return (db, id);
    }

    testWidgets('update rewrites the local row from the cloud copy', (
      tester,
    ) async {
      final (db, id) = await pumpDifferingMeal(tester);
      final strings = const AppStrings(Locale('ar'));

      await tester.tap(find.byKey(const Key('meal_sync_window_update_button')));
      await tester.pumpAndSettle();

      expect(find.text(strings.mealUpdatedToast(_name)), findsOneWidget);
      // Drain the toast's 1.5 s dismiss timer so no Timer is pending at end.
      await tester.pump(const Duration(seconds: 2));

      final row = (await db.mealsDao.getMealById(id))!;
      expect(row.prepTime, 60);
    });

    testWidgets('keep dismisses the window and leaves the row untouched', (
      tester,
    ) async {
      final (db, id) = await pumpDifferingMeal(tester);

      await tester.tap(find.byKey(const Key('meal_sync_window_keep_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('meal_sync_window')), findsNothing);
      expect(find.byKey(const Key('sync-diff-window')), findsNothing);
      final row = (await db.mealsDao.getMealById(id))!;
      expect(row.prepTime, 45);
    });
  });
}
