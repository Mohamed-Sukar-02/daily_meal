import 'package:daily_meal/main.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots the real app against an in-memory database with onboarding already
/// completed, so tests land on the Home tab.
Future<AppDatabase> pumpApp(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.appSettingsDao.ensureSettings();
  await db.appSettingsDao.updateSettings(
    const AppSettingsCompanion(isFirstRun: drift.Value(false)),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const DailyMealApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  return db;
}

double scrollOffset(WidgetTester tester, Key key) {
  final finder = find
      .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
      .first;
  return tester.state<ScrollableState>(finder).position.pixels;
}

Future<void> tapNav(WidgetTester tester, String destination) async {
  await tester.tap(find.byKey(ValueKey('nav_destination_$destination')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pumpAndSettle();
}

Future<void> tearDownApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await db.close();
}

