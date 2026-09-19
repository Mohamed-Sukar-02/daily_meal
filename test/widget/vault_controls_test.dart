import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Vault screen controls: dynamic subtitle, collapsible filter bar with clear badge, and vertical view toggle', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
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

    // 5b. Dragging horizontally on the filter bar must NOT dismiss it
    await tester.drag(find.text('فراخ'), const Offset(-60, 0));
    await tester.pumpAndSettle();
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

    // Verify list view icon on Vault toggle button
    expect(
      find.descendant(
        of: find.byKey(const Key('vault_view_toggle_button')),
        matching: find.byIcon(Icons.view_list_rounded),
      ),
      findsOneWidget,
    );

    // 11. Switch to Explore tab -> verify it also reflects List view (synchronized)
    await tester.tap(find.byKey(const Key('vault_tab_explore')));
    await tester.pumpAndSettle();
    final discoveryToggleFinder = find.byKey(const Key('discovery_view_toggle_button'));
    expect(discoveryToggleFinder, findsOneWidget);
    expect(
      find.descendant(
        of: discoveryToggleFinder,
        matching: find.byIcon(Icons.view_list_rounded),
      ),
      findsOneWidget,
    );

    // 12. Switch view mode from Explore tab back to Grid
    await tester.tap(discoveryToggleFinder);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('discovery_view_option_grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('discovery_view_option_grid')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: discoveryToggleFinder,
        matching: find.byIcon(Icons.grid_view_rounded),
      ),
      findsOneWidget,
    );

    // 13. Switch back to My Vault tab -> verify it is also Grid view (synchronized)
    await tester.tap(find.byKey(const Key('vault_tab_my_vault')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('vault_view_toggle_button')),
        matching: find.byIcon(Icons.grid_view_rounded),
      ),
      findsOneWidget,
    );

    // 14. Verify SharedPreferences has persisted the grid view value
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('vault_is_grid_view'), isTrue);

    await inMemoryDb.close();
  });

  testWidgets('Vault and Explore initialize in List mode when persisted in SharedPreferences', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'vault_is_grid_view': false});
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

    // Vault should start in List view
    expect(
      find.descendant(
        of: find.byKey(const Key('vault_view_toggle_button')),
        matching: find.byIcon(Icons.view_list_rounded),
      ),
      findsOneWidget,
    );

    // Switch to Explore tab -> Explore should also start in List view
    await tester.tap(find.byKey(const Key('vault_tab_explore')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('discovery_view_toggle_button')),
        matching: find.byIcon(Icons.view_list_rounded),
      ),
      findsOneWidget,
    );

    await inMemoryDb.close();
  });
}
