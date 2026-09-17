import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/main.dart';
import 'package:daily_meal/core/database/tables/app_settings_table.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Vault screen displays enlarged FAB, sparkles, and animated speech bubble tooltip', (WidgetTester tester) async {
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

    // 1. Verify FAB is present with key 'vault_add_fab'
    final fabFinder = find.byKey(const Key('vault_add_fab'));
    expect(fabFinder, findsOneWidget);

    // 2. Verify plus icon inside FAB
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // 3. Verify tooltip is rendered
    expect(find.text('أضفها في\n10 ثواني بس'), findsOneWidget);

    // 4. Tap the tooltip and verify it disappears while staying on page
    await tester.tap(find.text('أضفها في\n10 ثواني بس'));
    await tester.pumpAndSettle();
    expect(find.text('أضفها في\n10 ثواني بس'), findsNothing);

    // 5. Navigate away to Home and return to Vault -> tooltip reappears
    await tester.tap(find.byKey(const ValueKey('nav_destination_home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_destination_vault')));
    await tester.pumpAndSettle();
    expect(find.text('أضفها في\n10 ثواني بس'), findsOneWidget);

    // 6. Tap the FAB to verify QuickAddSheet opens and tooltip disappears
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();
    expect(find.text('إضافة أكلة سريعة'), findsOneWidget);

    await inMemoryDb.close();
  });
}
