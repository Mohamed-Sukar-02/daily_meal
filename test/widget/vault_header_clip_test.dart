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

/// The header clips its bottom edge to `toolbarHeight`, so a subtitle laid out
/// below that line is invisible even though it is still in the widget tree.
/// A presence assertion (`findsOneWidget`) passed while the bug was live — this
/// checks the painted geometry instead.
void main() {
  testWidgets('My Vault header keeps the subtitle inside the app bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await db.appSettingsDao.ensureSettings();
    await db.appSettingsDao.updateSettings(
      const AppSettingsCompanion(
        isFirstRun: drift.Value(false),
        language: drift.Value(AppLanguagePreference.ar),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const DailyMealApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav_destination_vault')));
    await tester.pumpAndSettle();

    const strings = AppStrings(Locale('ar'));
    final appBar = tester.getRect(find.byType(FlexibleSpaceBar).first);
    final localCount =
        tester.getRect(find.byKey(const ValueKey('vault_local_count')));
    final subtitle = tester.getRect(find.text(strings.vaultSubtitle).first);
    final syncButton =
        tester.getRect(find.byKey(const ValueKey('vault_sync_defaults_button')));

    expect(
      subtitle.bottom,
      lessThanOrEqualTo(appBar.bottom + 0.5),
      reason: 'subtitle is pushed out of the toolbar — the original bug',
    );
    expect(subtitle.top, greaterThanOrEqualTo(appBar.top));
    // The sync icon sits inline on the meals chip's leading side (its right in
    // Arabic) — stacking it under the chip was what pushed the subtitle out.
    expect(syncButton.left, greaterThanOrEqualTo(localCount.right - 0.5));
    expect(syncButton.top, lessThanOrEqualTo(localCount.bottom));
    expect(syncButton.bottom, lessThanOrEqualTo(appBar.bottom + 0.5));

    await db.close();
  });
}
