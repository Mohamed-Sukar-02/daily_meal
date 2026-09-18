import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/database/tables/app_settings_table.dart';
import 'package:daily_meal/features/home/presentation/widgets/emphasis_marks.dart';
import 'package:daily_meal/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('Settings screen EmphasisMarks is unmirrored in Arabic and mirrored in English',
      (tester) async {
    // 1. Test Arabic locale (mirrored = false)
    final dbAr = AppDatabase(NativeDatabase.memory());
    await dbAr.appSettingsDao.ensureSettings();
    await dbAr.appSettingsDao.updateSettings(
      const AppSettingsCompanion(
        isFirstRun: drift.Value(false),
        language: drift.Value(AppLanguagePreference.ar),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(dbAr)],
        child: const DailyMealApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tapNav(tester, 'settings');

    final sparkArFinder = find.byType(EmphasisMarks);
    expect(sparkArFinder, findsOneWidget);
    final sparkArWidget = tester.widget<EmphasisMarks>(sparkArFinder);
    expect(sparkArWidget.mirrored, isFalse, reason: 'Arabic sparkles must not be mirrored');

    await dbAr.close();

    // 2. Test English locale (mirrored = true)
    final dbEn = AppDatabase(NativeDatabase.memory());
    await dbEn.appSettingsDao.ensureSettings();
    await dbEn.appSettingsDao.updateSettings(
      const AppSettingsCompanion(
        isFirstRun: drift.Value(false),
        language: drift.Value(AppLanguagePreference.en),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(dbEn)],
        child: const DailyMealApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tapNav(tester, 'settings');

    final sparkEnFinder = find.byType(EmphasisMarks);
    expect(sparkEnFinder, findsOneWidget);
    final sparkEnWidget = tester.widget<EmphasisMarks>(sparkEnFinder);
    expect(sparkEnWidget.mirrored, isTrue, reason: 'English sparkles must be mirrored');

    await dbEn.close();
  });
}
