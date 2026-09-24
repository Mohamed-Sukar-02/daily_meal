import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/meals/presentation/meal_screen.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/providers/discovery_providers.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// The meal screen cloud mark: download · upload · sync · sync-with-pending-
// cloud-changes.
//
// The last two are the ones that matter — the mark turns orange only when the
// cloud row genuinely disagrees with the local one, and that is the single
// entry point to the sync window.
// ---------------------------------------------------------------------------

const String _cloudId = 'cloud-1';
const String _name = 'ملوخية خضراء بالفراخ';

Meal _localMeal({String? cloudId, int prepTime = 45}) {
  final now = DateTime(2026, 9, 22, 12);
  return Meal(
    id: 7,
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

CloudMeal _cloudMeal({int prepTimeMinutes = 45}) {
  return CloudMeal(
    id: _cloudId,
    name: _name,
    proteinType: 'chicken',
    carbsType: 'rice',
    category: 'tabeekh',
    prepTimeMinutes: prepTimeMinutes,
    createdAt: DateTime(2026, 9, 20, 12),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Meal meal,
  CloudMeal? cloud,
  bool viaCloudRoute = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allMealsProvider.overrideWith((ref) => Stream.value([meal])),
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
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: viaCloudRoute
              ? MealScreen(cloudId: _cloudId)
              : MealScreen(mealId: meal.id),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  final strings = const AppStrings(Locale('ar'));

  testWidgets('a meal with no cloud copy offers the upload mark',
      (tester) async {
    await _pump(tester, meal: _localMeal());

    expect(find.byTooltip(strings.proposalCta), findsOneWidget);
    expect(find.byKey(const Key('meal_sync_window')), findsNothing);
  });

  testWidgets('a matching cloud copy reads as plain sync, with no window',
      (tester) async {
    await _pump(
      tester,
      meal: _localMeal(cloudId: _cloudId),
      cloud: _cloudMeal(),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.syncStateSynced), findsOneWidget);

    await tester.tap(find.byTooltip(strings.syncStateSynced));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_sync_window')), findsNothing);
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

    await tester.tap(find.byTooltip(strings.syncWindowCloudHint));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal_sync_window')), findsOneWidget);

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

  testWidgets('the cloud-only route offers the download mark, with no local '
      'row to love', (tester) async {
    await _pump(
      tester,
      meal: _localMeal(cloudId: _cloudId),
      cloud: _cloudMeal(),
      viaCloudRoute: true,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(strings.discoveryDownload), findsOneWidget);
    expect(find.byKey(const Key('meal_screen_favorite_button')), findsNothing);
    expect(find.text(_name), findsWidgets);
  });
}
