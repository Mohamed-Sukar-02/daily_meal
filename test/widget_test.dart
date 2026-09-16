import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/main.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';

void main() {
  testWidgets('App launches successfully smoke test', (WidgetTester tester) async {
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
    
    // Wait for the async splash screen navigation to resolve
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('أكلة النهاردة'), findsOneWidget);
    await inMemoryDb.close();
  });
}
