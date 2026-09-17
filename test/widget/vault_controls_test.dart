import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Vault screen controls: dynamic subtitle, collapsible filter bar with clear badge, and vertical view toggle', (WidgetTester tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    await inMemoryDb.appSettingsDao.ensureSettings();
    await inMemoryDb.appSettingsDao.updateSettings(
      const AppSettingsCompanion(
        isFirstRun: drift.Value(false),
        language: drift.Value(AppLanguagePreference.ar),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const DailyMealApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Navigate to Vault
    await tester.tap(find.byKey(const ValueKey('nav_destination_vault')));
    await tester.pumpAndSettle();

    const strings = AppStrings(Locale('ar'));

    // 1. Verify initial subtitle for "My Vault"
    expect(find.text(strings.vaultSubtitle), findsOneWidget);

    // 2. Switch to Explore tab -> subtitle changes
    await tester.tap(find.byKey(const Key('vault_tab_explore')));
    await tester.pumpAndSettle();
    expect(find.text(strings.vaultSubtitleExplore), findsOneWidget);

    // 3. Switch back to My Vault -> subtitle restored
    await tester.tap(find.byKey(const Key('vault_tab_my_vault')));
    await tester.pumpAndSettle();
    expect(find.text(strings.vaultSubtitle), findsOneWidget);

    // 4. Verify filter bar is initially collapsed
    expect(find.text('فراخ'), findsNothing);

    // 5. Tap tune icon to show filter bar
    final filterToggleFinder = find.byKey(const Key('vault_filter_toggle_button'));
    expect(filterToggleFinder, findsOneWidget);
    await tester.tap(filterToggleFinder);
    await tester.pumpAndSettle();

    // Filter bar is now visible
    expect(find.text('فراخ'), findsOneWidget);

    // 6. Tap a filter chip (e.g. Chicken "فراخ") -> filter applied and bar auto-collapses
    await tester.tap(find.text('فراخ'));
    await tester.pumpAndSettle();
    expect(find.text('فراخ'), findsNothing);

    // 7. Tap tune icon again to open filter bar while filter is active -> 'X' clear button appears
    await tester.tap(filterToggleFinder);
    await tester.pumpAndSettle();
    expect(find.text('فراخ'), findsOneWidget);
    final clearButtonFinder = find.byKey(const Key('vault_filter_clear_button'));
    expect(clearButtonFinder, findsOneWidget);

    // 8. Tap the 'X' clear button -> resets filters back to default All
    await tester.tap(clearButtonFinder);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vault_filter_clear_button')), findsNothing);

    // 9. Tap view mode toggle button -> vertical toggle switch appears
    final viewToggleFinder = find.byKey(const Key('vault_view_toggle_button'));
    expect(viewToggleFinder, findsOneWidget);
    await tester.tap(viewToggleFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vault_view_option_grid')), findsOneWidget);
    expect(find.byKey(const Key('vault_view_option_list')), findsOneWidget);

    // 10. Tap list view option -> selection updates and overlay closes
    await tester.tap(find.byKey(const Key('vault_view_option_list')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vault_view_option_list')), findsNothing);

    await inMemoryDb.close();
  });
}
