import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bottom navigation bar renders custom icons and switches tabs', (WidgetTester tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    await inMemoryDb.appSettingsDao.ensureSettings();
    await inMemoryDb.appSettingsDao.updateSettings(
      const AppSettingsCompanion(isFirstRun: drift.Value(false)),
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

    // Settle splash navigation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify nav destinations exist
    expect(find.byKey(const ValueKey('nav_destination_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_destination_vault')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_destination_history')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_destination_settings')), findsOneWidget);

    // Verify ImageIcons are rendered for vault and history
    expect(find.byType(ImageIcon), findsNWidgets(2));

    // Tap Vault tab
    await tester.tap(find.byKey(const ValueKey('nav_destination_vault')));
    await tester.pumpAndSettle();

    // Tap History tab
    await tester.tap(find.byKey(const ValueKey('nav_destination_history')));
    await tester.pumpAndSettle();

    // Tap Home tab
    await tester.tap(find.byKey(const ValueKey('nav_destination_home')));
    await tester.pumpAndSettle();

    await inMemoryDb.close();
  });
}
