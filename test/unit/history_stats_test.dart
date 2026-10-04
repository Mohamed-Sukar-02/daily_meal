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
      .where(
        (e) => e.cookedAt.year == now.year && e.cookedAt.month == now.month,
      )
      .toList();
  return _MonthStats(
    month.where((e) => e.proteinType == ProteinType.chicken).length,
    month.where((e) => e.proteinType == ProteinType.beef).length,
    month.where((e) => e.proteinType == ProteinType.fish).length,
    month
        .where(
          (e) =>
              e.proteinType == ProteinType.legume ||
              e.proteinType == ProteinType.none ||
              e.proteinType == ProteinType.dairy,
        )
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

    test(
      'logTakeoutMeal stores "takeout" (not Arabic) with takeout type',
      () async {
        final id = await db.mealHistoryDao.logTakeoutMeal();
        final entry = (await db.mealHistoryDao.getAllHistory()).firstWhere(
          (e) => e.id == id,
        );
        expect(entry.mealName, 'takeout');
        expect(entry.entryType, MealEntryType.takeout);
        expect(entry.proteinType, ProteinType.none);
      },
    );

    test(
      'logSkippedMeal stores "skipped" (not Arabic) with skipped type',
      () async {
        final id = await db.mealHistoryDao.logSkippedMeal();
        final entry = (await db.mealHistoryDao.getAllHistory()).firstWhere(
          (e) => e.id == id,
        );
        expect(entry.mealName, 'skipped');
        expect(entry.entryType, MealEntryType.skipped);
      },
    );

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
      expect(
        en.historyEntryDisplayName(mealName: 'takeout', entryType: 'takeout'),
        'Takeout',
      );
      expect(
        ar.historyEntryDisplayName(mealName: 'takeout', entryType: 'takeout'),
        'أكل من بره',
      );
      expect(
        en.historyEntryDisplayName(mealName: 'skipped', entryType: 'skipped'),
        'Skipped Meal',
      );
      expect(
        ar.historyEntryDisplayName(mealName: 'skipped', entryType: 'skipped'),
        'تفويت الوجبة',
      );
    });

    test('legacy Arabic rows still resolve (backward compatibility)', () {
      expect(
        ar.historyEntryDisplayName(
          mealName: 'خارج البيت',
          entryType: 'takeout',
        ),
        'أكل من بره',
      );
      expect(
        en.historyEntryDisplayName(
          mealName: 'خارج البيت',
          entryType: 'takeout',
        ),
        'Takeout',
      );
      expect(
        ar.historyEntryDisplayName(
          mealName: 'تفويت الوجبة',
          entryType: 'skipped',
        ),
        'تفويت الوجبة',
      );
      expect(
        en.historyEntryDisplayName(
          mealName: 'تفويت الوجبة',
          entryType: 'skipped',
        ),
        'Skipped Meal',
      );
    });

    test('entryType alone drives resolution even if mealName is arbitrary', () {
      expect(
        en.historyEntryDisplayName(
          mealName: 'whatever-i-stored',
          entryType: 'takeout',
        ),
        'Takeout',
      );
      expect(
        ar.historyEntryDisplayName(mealName: 'أي حاجة', entryType: 'skipped'),
        'تفويت الوجبة',
      );
    });

    test(
      'legacy Arabic takeout synonyms resolve by name regardless of type',
      () {
        expect(
          en.historyEntryDisplayName(mealName: 'تيك أواي', entryType: 'cooked'),
          'Takeout',
        );
        expect(
          ar.historyEntryDisplayName(
            mealName: 'أكل من بره',
            entryType: 'cooked',
          ),
          'أكل من بره',
        );
      },
    );

    test('genuine cooked names pass through unchanged', () {
      expect(
        en.historyEntryDisplayName(mealName: 'Molokhia', entryType: 'cooked'),
        'Molokhia',
      );
      expect(
        ar.historyEntryDisplayName(
          mealName: 'ملوخية بالفراخ',
          entryType: 'cooked',
        ),
        'ملوخية بالفراخ',
      );
      // Pass-through returns the raw stored value, not a trimmed one.
      expect(
        en.historyEntryDisplayName(
          mealName: '  Baked Kibda  ',
          entryType: 'cooked',
        ),
        '  Baked Kibda  ',
      );
    });

    // A leftovers row stores the *plain* name of the dish being reheated plus the
    // `leftover` kind; the label is composed at render time, so it follows the
    // language the user reads in rather than the language they tapped in.
    test('leftover rows are decorated from the stored kind', () {
      expect(
        en.historyEntryDisplayName(mealName: 'كشري', entryType: 'leftover'),
        'Leftovers of كشري',
      );
      expect(
        ar.historyEntryDisplayName(mealName: 'كشري', entryType: 'leftover'),
        'بواقي كشري',
      );
    });

    test(
      'legacy leftover rows with a baked-in label are normalised, not doubled',
      () {
        expect(
          ar.historyEntryDisplayName(
            mealName: '(بقايا امبارح) كشري',
            entryType: 'leftover',
          ),
          'بواقي كشري',
        );
        expect(
          en.historyEntryDisplayName(
            mealName: '(Leftovers) Molokhia',
            entryType: 'leftover',
          ),
          'Leftovers of Molokhia',
        );
        expect(
          ar.historyEntryDisplayName(
            mealName: 'بقايا امبارح',
            entryType: 'leftover',
          ),
          'بواقي أكل',
        );
      },
    );

    test('a leftovers row with no source dish reads as plain leftovers', () {
      expect(
        ar.historyEntryDisplayName(mealName: 'leftover', entryType: 'leftover'),
        'بواقي أكل',
      );
      expect(
        en.historyEntryDisplayName(mealName: 'leftover', entryType: 'leftover'),
        'Leftover',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // The reheat button used to ask for "the latest cooked row, whenever that was".
  // ---------------------------------------------------------------------------
  group('MealHistoryDao.getRecentLeftoverSource', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Future<void> logCooked(String name, DateTime at) =>
        db.mealHistoryDao.logMeal(
          mealName: name,
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedAt: at,
        );

    // The reference day is a Friday in Oct 2026; the day math is calendar-based,
    // so only the local-day boundaries below should matter.
    final reference = DateTime(2026, 10, 2, 20, 0);

    test('a meal cooked weeks ago is not offered as leftovers', () async {
      await logCooked('Molokhia from last month', DateTime(2026, 9, 5, 14));
      final source = await db.mealHistoryDao.getRecentLeftoverSource(
        withinDays: 2,
        referenceDate: reference,
      );
      expect(source, isNull);
    });

    test('the most recent eligible day wins inside the window', () async {
      await logCooked('Two days ago', DateTime(2026, 9, 30, 13));
      await logCooked('Yesterday lunch', DateTime(2026, 10, 1, 13));
      final source = await db.mealHistoryDao.getRecentLeftoverSource(
        withinDays: 2,
        referenceDate: reference,
      );
      expect(source?.mealName, 'Yesterday lunch');
    });

    test('what was cooked today is never returned as leftovers', () async {
      await logCooked('Today breakfast', DateTime(2026, 10, 2, 8));
      await logCooked('Yesterday lunch', DateTime(2026, 10, 1, 13));
      final source = await db.mealHistoryDao.getRecentLeftoverSource(
        withinDays: 2,
        referenceDate: reference,
      );
      expect(source?.mealName, 'Yesterday lunch');
    });

    test(
      'a row logged at exactly midnight of today is still not leftovers',
      () async {
        await logCooked('Today at midnight', DateTime(2026, 10, 2, 0, 0));
        final source = await db.mealHistoryDao.getRecentLeftoverSource(
          withinDays: 2,
          referenceDate: reference,
        );
        expect(source, isNull);
      },
    );

    test(
      'only cooked rows qualify — a leftovers log is not reheated again',
      () async {
        await db.mealHistoryDao.logMeal(
          mealName: 'Old reheat',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedAt: DateTime(2026, 10, 1, 13),
          entryType: MealEntryType.leftover,
        );
        final source = await db.mealHistoryDao.getRecentLeftoverSource(
          withinDays: 2,
          referenceDate: reference,
        );
        expect(source, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // History queries + monthly stats counting.
  // ---------------------------------------------------------------------------
  group('History queries + monthly protein stats', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test(
      'getAllHistory orders newest first; within-days filters by cutoff',
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
      },
    );

    test(
      'this-month stats count chicken/beef/fish/meatless; exclude last month',
      () async {
        final now = DateTime.now();
        Future<void> log(
          String name,
          ProteinType p,
          CarbsType c, {
          DateTime? at,
        }) => db.mealHistoryDao.logMeal(
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
        await log(
          'Old chicken',
          ProteinType.chicken,
          CarbsType.rice,
          at: DateTime(now.year, now.month - 1, 1),
        );

        final stats = _computeMonthStats(
          await db.mealHistoryDao.getAllHistory(),
          now,
        );
        expect(stats.chicken, 2, reason: 'last-month chicken excluded');
        expect(stats.beef, 1);
        expect(stats.fish, 1);
        expect(
          stats.meatless,
          3,
          reason: 'legume + takeout(none) + skipped(none)',
        );
      },
    );

    test(
      'takeout/skipped neutral keys render localized via the resolver',
      () async {
        await db.mealHistoryDao.logTakeoutMeal();
        await db.mealHistoryDao.logSkippedMeal();
        final all = await db.mealHistoryDao.getAllHistory();

        final takeout = all.firstWhere(
          (e) => e.entryType == MealEntryType.takeout,
        );
        final skipped = all.firstWhere(
          (e) => e.entryType == MealEntryType.skipped,
        );

        expect(
          en.historyEntryDisplayName(
            mealName: takeout.mealName,
            entryType: takeout.entryType.name,
          ),
          'Takeout',
        );
        expect(
          ar.historyEntryDisplayName(
            mealName: takeout.mealName,
            entryType: takeout.entryType.name,
          ),
          'أكل من بره',
        );
        expect(
          en.historyEntryDisplayName(
            mealName: skipped.mealName,
            entryType: skipped.entryType.name,
          ),
          'Skipped Meal',
        );
        expect(
          ar.historyEntryDisplayName(
            mealName: skipped.mealName,
            entryType: skipped.entryType.name,
          ),
          'تفويت الوجبة',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // The per-row delete the History screen now offers, and the undo beside it.
  // The assertions are at the DAO level because that is all either half of the
  // pair does; what they pin is that a row can leave without taking the log with
  // it, and that the snapshot the undo re-inserts is not re-timestamped.
  // ---------------------------------------------------------------------------

  group('per-row delete and the undo that re-inserts', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('one row can be removed while the rest of the log stays', () async {
      final kept = await db.mealHistoryDao.logTakeoutMeal();
      final removed = await db.mealHistoryDao.logSkippedMeal();

      expect(await db.mealHistoryDao.deleteHistoryEntry(removed), 1);
      final all = await db.mealHistoryDao.getAllHistory();
      expect(all.map((e) => e.id), [kept]);
    });

    test('deleting a row that is not there removes nothing', () async {
      await db.mealHistoryDao.logTakeoutMeal();

      expect(await db.mealHistoryDao.deleteHistoryEntry(9999), 0);
      expect(await db.mealHistoryDao.getAllHistory(), hasLength(1));
    });

    test(
      'the snapshot the undo re-inserts keeps the day it was cooked',
      () async {
        final cookedAt = DateTime(2026, 10, 2, 21, 15);
        final id = await db.mealHistoryDao.logMeal(
          mealId: null,
          mealName: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedAt: cookedAt,
          entryType: MealEntryType.cooked,
          notes: 'بالسرسمة',
        );
        final row = (await db.mealHistoryDao.getAllHistory()).firstWhere(
          (e) => e.id == id,
        );

        await db.mealHistoryDao.deleteHistoryEntry(id);
        expect(await db.mealHistoryDao.getAllHistory(), isEmpty);

        // Exactly what `HistoryController.restoreHistoryEntry` passes back in.
        final restored = await db.mealHistoryDao.logMeal(
          mealId: row.mealId,
          mealName: row.mealName,
          proteinType: row.proteinType,
          carbsType: row.carbsType,
          cookedAt: row.cookedAt,
          entryType: row.entryType,
          notes: row.notes,
        );
        final back = (await db.mealHistoryDao.getAllHistory()).single;

        expect(restored, back.id);
        expect(
          back.id,
          isNot(id),
          reason:
              'a re-inserted row is a new row — nothing reads a history id '
              'except another delete, and the row it targeted is gone',
        );
        expect(
          back.cookedAt,
          cookedAt,
          reason:
              'the whole point of capturing the snapshot: undo must not date '
              'the meal to the moment the toast was tapped',
        );
        expect(back.mealName, 'كشري');
        expect(back.proteinType, ProteinType.legume);
        expect(back.carbsType, CarbsType.rice);
        expect(back.entryType, MealEntryType.cooked);
        expect(back.notes, 'بالسرسمة');
      },
    );
  });

  // Bounds for the "has today been answered?" test the reminder relies on. The
  // day edges are the whole risk: a window that leaks into yesterday silences a
  // morning reminder that was earned, and one that leaks into tomorrow answers a
  // day that has not happened.

  group('MealHistoryDao.hasAnyEntryToday', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    final today = DateTime(2026, 10, 2, 22, 5);

    test('an empty log answers nothing', () async {
      expect(
        await db.mealHistoryDao.hasAnyEntryToday(referenceDate: today),
        isFalse,
      );
    });

    test('a row one minute before midnight is not today', () async {
      await db.mealHistoryDao.logSkippedMeal(
        cookedAt: DateTime(2026, 10, 1, 23, 59),
      );

      expect(
        await db.mealHistoryDao.hasAnyEntryToday(referenceDate: today),
        isFalse,
      );
    });

    test('a row dated tomorrow does not answer today either', () async {
      await db.mealHistoryDao.logTakeoutMeal(
        cookedAt: DateTime(2026, 10, 3, 0, 1),
      );

      expect(
        await db.mealHistoryDao.hasAnyEntryToday(referenceDate: today),
        isFalse,
        reason:
            'a future row must not swallow the reminder for a day nobody has '
            'lived yet',
      );
    });

    test(
      'midnight itself belongs to its own day, and takeout counts',
      () async {
        await db.mealHistoryDao.logSkippedMeal(
          cookedAt: DateTime(2026, 10, 2, 0, 0),
        );

        expect(
          await db.mealHistoryDao.hasAnyEntryToday(referenceDate: today),
          isTrue,
          reason:
              'a skip is an answer: the question was "what are you cooking '
              'today", and "nothing" settles it',
        );
      },
    );
  });
}
