import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:drift/native.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';

/// Mirrors the monthly protein counting used by `history_screen.dart`
/// (filter current month/year first, then count with enum equality).
class _MonthStats {
  final int chicken;
  final int beef;
  final int fish;
  final int meatless;
  const _MonthStats(this.chicken, this.beef, this.fish, this.meatless);
}

_MonthStats _computeMonthStats(List<MealHistoryData> all, DateTime now) {
  final month = all
      .where((e) => e.cookedAt.year == now.year && e.cookedAt.month == now.month)
      .toList();
  return _MonthStats(
    month.where((e) => e.proteinType == ProteinType.chicken).length,
    month.where((e) => e.proteinType == ProteinType.beef).length,
    month.where((e) => e.proteinType == ProteinType.fish).length,
    month
        .where((e) =>
            e.proteinType == ProteinType.legume ||
            e.proteinType == ProteinType.none ||
            e.proteinType == ProteinType.dairy)
        .length,
  );
}

void main() {
  const en = AppStrings(Locale('en'));
  const ar = AppStrings(Locale('ar'));

  // ---------------------------------------------------------------------------
  // DAO now persists language-neutral keys instead of hardcoded Arabic.
  // ---------------------------------------------------------------------------
  group('MealHistoryDao takeout/skip persist language-neutral keys', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('logTakeoutMeal stores "takeout" (not Arabic) with takeout type',
        () async {
      final id = await db.mealHistoryDao.logTakeoutMeal();
      final entry = (await db.mealHistoryDao.getAllHistory())
          .firstWhere((e) => e.id == id);
      expect(entry.mealName, 'takeout');
      expect(entry.entryType, MealEntryType.takeout);
      expect(entry.proteinType, ProteinType.none);
    });

    test('logSkippedMeal stores "skipped" (not Arabic) with skipped type',
        () async {
      final id = await db.mealHistoryDao.logSkippedMeal();
      final entry = (await db.mealHistoryDao.getAllHistory())
          .firstWhere((e) => e.id == id);
      expect(entry.mealName, 'skipped');
      expect(entry.entryType, MealEntryType.skipped);
    });

    test('stored rows contain no Arabic display copy', () async {
      await db.mealHistoryDao.logTakeoutMeal();
      await db.mealHistoryDao.logSkippedMeal();
      for (final e in await db.mealHistoryDao.getAllHistory()) {
        expect(e.mealName.contains('خارج'), isFalse);
        expect(e.mealName.contains('تفويت'), isFalse);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // The UI-side resolver must handle neutral keys AND legacy Arabic rows.
  // ---------------------------------------------------------------------------
  group('AppStrings.historyEntryDisplayName', () {
    test('new neutral keys resolve in both locales', () {
      expect(en.historyEntryDisplayName(mealName: 'takeout', entryType: 'takeout'), 'Takeout');
      expect(ar.historyEntryDisplayName(mealName: 'takeout', entryType: 'takeout'), 'أكل من بره');
      expect(en.historyEntryDisplayName(mealName: 'skipped', entryType: 'skipped'), 'Skipped Meal');
      expect(ar.historyEntryDisplayName(mealName: 'skipped', entryType: 'skipped'), 'تفويت الوجبة');
    });

    test('legacy Arabic rows still resolve (backward compatibility)', () {
      expect(ar.historyEntryDisplayName(mealName: 'خارج البيت', entryType: 'takeout'), 'أكل من بره');
      expect(en.historyEntryDisplayName(mealName: 'خارج البيت', entryType: 'takeout'), 'Takeout');
      expect(ar.historyEntryDisplayName(mealName: 'تفويت الوجبة', entryType: 'skipped'), 'تفويت الوجبة');
      expect(en.historyEntryDisplayName(mealName: 'تفويت الوجبة', entryType: 'skipped'), 'Skipped Meal');
    });

    test('entryType alone drives resolution even if mealName is arbitrary', () {
      expect(en.historyEntryDisplayName(mealName: 'whatever-i-stored', entryType: 'takeout'), 'Takeout');
      expect(ar.historyEntryDisplayName(mealName: 'أي حاجة', entryType: 'skipped'), 'تفويت الوجبة');
    });

    test('legacy Arabic takeout synonyms resolve by name regardless of type', () {
      expect(en.historyEntryDisplayName(mealName: 'تيك أواي', entryType: 'cooked'), 'Takeout');
      expect(ar.historyEntryDisplayName(mealName: 'أكل من بره', entryType: 'cooked'), 'أكل من بره');
    });

    test('genuine meal names pass through unchanged', () {
      expect(en.historyEntryDisplayName(mealName: 'Molokhia', entryType: 'cooked'), 'Molokhia');
      expect(ar.historyEntryDisplayName(mealName: 'ملوخية بالفراخ', entryType: 'cooked'), 'ملوخية بالفراخ');
      // Pass-through returns the raw stored value, not a trimmed one.
      expect(en.historyEntryDisplayName(mealName: '  Baked Kibda  ', entryType: 'leftover'), '  Baked Kibda  ');
    });
  });

  // ---------------------------------------------------------------------------
  // History queries + monthly stats counting.
  // ---------------------------------------------------------------------------
  group('History queries + monthly protein stats', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('getAllHistory orders newest first; within-days filters by cutoff',
        () async {
      final now = DateTime.now();
      await db.mealHistoryDao.logMeal(
        mealName: 'Old',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        cookedAt: now.subtract(const Duration(days: 10)),
      );
      await db.mealHistoryDao.logMeal(
        mealName: 'Recent',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.pasta,
        cookedAt: now,
      );

      final all = await db.mealHistoryDao.getAllHistory();
      expect(all.first.mealName, 'Recent', reason: 'descending by cookedAt');

      final within7 = await db.mealHistoryDao.getHistoryWithinDays(7);
      expect(within7.length, 1);
      expect(within7.first.mealName, 'Recent');
    });

    test('this-month stats count chicken/beef/fish/meatless; exclude last month',
        () async {
      final now = DateTime.now();
      Future<void> log(String name, ProteinType p, CarbsType c, {DateTime? at}) =>
          db.mealHistoryDao.logMeal(
            mealName: name,
            proteinType: p,
            carbsType: c,
            cookedAt: at ?? now,
          );

      await log('Chicken 1', ProteinType.chicken, CarbsType.rice);
      await log('Chicken 2', ProteinType.chicken, CarbsType.bread);
      await log('Beef 1', ProteinType.beef, CarbsType.pasta);
      await log('Fish 1', ProteinType.fish, CarbsType.rice);
      await log('Legume 1', ProteinType.legume, CarbsType.none);
      // Takeout/skip default to ProteinType.none -> counted as "meatless".
      await db.mealHistoryDao.logTakeoutMeal(cookedAt: now);
      await db.mealHistoryDao.logSkippedMeal(cookedAt: now);

      // A previous-month chicken entry must be excluded from monthly stats.
      await log('Old chicken', ProteinType.chicken, CarbsType.rice,
          at: DateTime(now.year, now.month - 1, 1));

      final stats = _computeMonthStats(await db.mealHistoryDao.getAllHistory(), now);
      expect(stats.chicken, 2, reason: 'last-month chicken excluded');
      expect(stats.beef, 1);
      expect(stats.fish, 1);
      expect(stats.meatless, 3, reason: 'legume + takeout(none) + skipped(none)');
    });

    test('takeout/skipped neutral keys render localized via the resolver', () async {
      await db.mealHistoryDao.logTakeoutMeal();
      await db.mealHistoryDao.logSkippedMeal();
      final all = await db.mealHistoryDao.getAllHistory();

      final takeout = all.firstWhere((e) => e.entryType == MealEntryType.takeout);
      final skipped = all.firstWhere((e) => e.entryType == MealEntryType.skipped);

      expect(en.historyEntryDisplayName(mealName: takeout.mealName, entryType: takeout.entryType.name), 'Takeout');
      expect(ar.historyEntryDisplayName(mealName: takeout.mealName, entryType: takeout.entryType.name), 'أكل من بره');
      expect(en.historyEntryDisplayName(mealName: skipped.mealName, entryType: skipped.entryType.name), 'Skipped Meal');
      expect(ar.historyEntryDisplayName(mealName: skipped.mealName, entryType: skipped.entryType.name), 'تفويت الوجبة');
    });
  });
}
