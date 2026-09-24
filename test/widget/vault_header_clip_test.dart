import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/providers/discovery_providers.dart';
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

  // -------------------------------------------------------------------------
  // The two counter rows `_buildVaultCounter` builds. The case above measures
  // the subtitle and the sync chip inside the My-Vault row; these pin the row
  // keys themselves (nothing asserted before that either `ValueKey` resolves),
  // the Explore two-badge row that never had a test at all, and the fact that
  // both rows stay inside the 85px bar that clips them.
  // -------------------------------------------------------------------------

  testWidgets('My Vault exposes its counter row key inside the 85px bar',
      (tester) async {
    final db = await _openVault(tester: tester);

    final row = find.byKey(_localRowKey);
    expect(row, findsOneWidget,
        reason: 'ISSUES.md names vault_local_count_row; nothing checked it before');

    final bar = _barAround(tester, row);
    final padded = _paddedBar(bar);
    final rowRect = tester.getRect(row);
    expect(bar.height, closeTo(_toolbarHeight, 0.5),
        reason: 'the header is measured against the 85px toolbar it is clipped to');
    _expectInsideBar(padded, rowRect, 'the meals-chip row');
    // The badge and the sync icon are side by side, never stacked: stacking
    // them is what pushed the subtitle out of the bar in the first place.
    final chip = tester.getRect(find.byKey(_localChipKey));
    final sync = tester.getRect(find.byKey(_syncButtonKey));
    _expectInsideBar(padded, chip, 'the meals chip');
    _expectInsideBar(padded, sync, 'the sync icon');
    expect(_overlap(chip, sync), isTrue,
        reason: 'the sync icon and the meals chip must share one horizontal line');
    expect(
      tester.getRect(find.text(const AppStrings(Locale('ar')).vaultSubtitle).first).bottom,
      greaterThan(rowRect.bottom),
      reason: 'the subtitle is the line under the counters; if it were above them '
          'the row would be pushing it out of the bar',
    );

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('Explore header keeps both counter badges inside the 85px bar',
      (tester) async {
    final db = await _openVault(
      tester: tester,
      overrides: [publicMealsProvider.overrideWith((ref) async => _cloudVault(1234))],
    );
    await _switchToExplore(tester);

    final row = find.byKey(_exploreRowKey);
    expect(row, findsOneWidget,
        reason: 'ISSUES.md names vault_explore_count_row; nothing checked it before');
    expect(find.byKey(_localRowKey), findsNothing,
        reason: 'AnimatedSwitcher swapped the local row out for the cloud row');

    final bar = _barAround(tester, row);
    expect(bar.height, closeTo(_toolbarHeight, 0.5));
    final padded = _paddedBar(bar);
    _expectInsideBar(padded, tester.getRect(row), 'the two-badge cloud row');

    // 1234 cloud meals, 3 of them already in the vault -> "1231 جديدة" + "1234 أكلة".
    final strings = AppStrings(const Locale('ar'));
    final newBadgeFinder = find.descendant(
        of: row, matching: find.text(strings.vaultNewCount(1231)));
    final cloudBadgeFinder = find.descendant(
        of: row, matching: find.text(strings.vaultCloudCount(1234)));
    expect(newBadgeFinder, findsOneWidget);
    expect(cloudBadgeFinder, findsOneWidget);

    final newBadge = tester.getRect(newBadgeFinder);
    final cloudBadge = tester.getRect(cloudBadgeFinder);
    _expectInsideBar(padded, newBadge, 'the "new" badge');
    _expectInsideBar(padded, cloudBadge, 'the cloud counter chip');
    expect(_overlap(newBadge, cloudBadge), isTrue,
        reason: 'the badges sit on one line — the old vertical Column is what clipped');

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('Explore counters shrink instead of overflowing on a narrow phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = await _openVault(
      tester: tester,
      overrides: [publicMealsProvider.overrideWith((ref) async => _cloudVault(100003))],
    );
    await _switchToExplore(tester);

    final bar = _barAround(tester, find.byKey(_exploreRowKey));
    final rowRect = tester.getRect(find.byKey(_exploreRowKey));
    expect(bar.height, closeTo(_toolbarHeight, 0.5));
    // Six-digit counters next to a six-word title on a 360px phone: measured
    // 160.0 x 12.9 here, i.e. FittedBox scaled the row down instead of letting
    // the Row blow past the header's gutters.
    _expectInsideBar(_paddedBar(bar), rowRect, 'the crowded cloud row');
    expect(rowRect.height, lessThanOrEqualTo(40),
        reason: 'the row must not eat the bar\'s whole 85px of height');

    final strings = AppStrings(const Locale('ar'));
    expect(find.text(strings.vaultCloudCount(100003)), findsOneWidget,
        reason: 'shrinking must still show both counters, not drop one');
    expect(find.text(strings.vaultNewCount(100000)), findsOneWidget);

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

const _localRowKey = ValueKey('vault_local_count_row');
const _localChipKey = ValueKey('vault_local_count');
const _exploreRowKey = ValueKey('vault_explore_count_row');
const _exploreChipKey = ValueKey('vault_explore_count');
const _syncButtonKey = ValueKey('vault_sync_defaults_button');

/// The header's clip line. `SliverAppBar.toolbarHeight` in
/// `meal_vault_screen.dart` and `discovery_screen.dart` both say 85.
const _toolbarHeight = 85.0;

/// Errors raised by widgets the header does not contain are echoed and dropped
/// instead of failing these tests.
///
/// They are real and they are reported (see the note at the bottom of this
/// file): opening the Explore tab lays out cloud tiles whose `Column`/`Row`
/// overflow, and that is a discovery-grid bug, not the counter-row bug this
/// file pins. Anything thrown inside the header keeps going to the normal
/// handler, so a header overflow still fails the test with its own message.
void _onlyReportHeaderErrors(WidgetTester tester) {
  final previous = FlutterError.onError;
  final echoed = <String>{};
  FlutterError.onError = (details) {
    if (_isHeaderError(details)) {
      previous?.call(details);
      return;
    }
    final message = details.exception.toString();
    if (echoed.add(message)) {
      debugPrint('ignored (outside the vault header): $message');
    }
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Finds the widget that owns the failing render object — the rendering library
/// parks a [DebugCreator] in `informationCollector`, which is where the
/// "relevant error-causing widget was:" line comes from — and walks up to see
/// whether it is part of the vault header.
bool _isHeaderError(FlutterErrorDetails details) {
  for (final node in details.informationCollector?.call() ?? const <DiagnosticsNode>[]) {
    final creator = node.value;
    if (creator is! DebugCreator || !creator.element.mounted) continue;
    if (_isHeaderWidget(creator.element.widget)) return true;
    var found = false;
    creator.element.visitAncestorElements((ancestor) {
      found = _isHeaderWidget(ancestor.widget);
      return !found;
    });
    if (found) return true;
  }
  return false;
}

bool _isHeaderWidget(Widget widget) =>
    widget is FlexibleSpaceBar ||
    widget.key == _localRowKey ||
    widget.key == _exploreRowKey ||
    widget.key == _localChipKey ||
    widget.key == _exploreChipKey ||
    widget.key == _syncButtonKey;

/// Boots the app, completes onboarding and opens the Meal Vault. The vault grid
/// is wiped and replaced with three cloud-linked meals, so the Explore badges
/// have a known shared/new split instead of whatever `onCreate` seeded.
Future<AppDatabase> _openVault({
  required WidgetTester tester,
  List<Override> overrides = const [],
}) async {
  _onlyReportHeaderErrors(tester);
  SharedPreferences.setMockInitialValues({});
  final db = AppDatabase(NativeDatabase.memory());
  await db.appSettingsDao.ensureSettings();
  await db.appSettingsDao.updateSettings(
    const AppSettingsCompanion(
      isFirstRun: drift.Value(false),
      language: drift.Value(AppLanguagePreference.ar),
    ),
  );
  await db.mealsDao.deleteAllMeals();
  for (var i = 0; i < 3; i++) {
    await db.mealsDao.insertMeal(MealsCompanion(
      name: drift.Value('أكلة محفوظة $i'),
      proteinType: const drift.Value(ProteinType.chicken),
      carbsType: const drift.Value(CarbsType.rice),
      category: const drift.Value(MealCategory.egyptianTraditional),
      prepTime: const drift.Value(30),
      cloudId: drift.Value('cloud_$i'),
    ));
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db), ...overrides],
      child: const DailyMealApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('nav_destination_vault')));
  await tester.pumpAndSettle();
  return db;
}

/// The counter row lives inside `FlexibleSpaceBar(background:)`, which is the
/// widget that gets clipped to `toolbarHeight` — measuring against its ancestor
/// is measuring against the real clip line.
Rect _barAround(WidgetTester tester, Finder row) =>
    tester.getRect(find.ancestor(of: row, matching: find.byType(FlexibleSpaceBar)).first);

/// The header's `Padding(16, 16, 16, 6)` box: the counter row has to stay inside
/// the bar *and* inside these gutters, otherwise the Row overflowed and only the
/// FittedBox saved it — which is what the narrow-phone case checks.
Rect _paddedBar(Rect bar) =>
    Rect.fromLTRB(bar.left + 16, bar.top, bar.right - 16, bar.bottom);

void _expectInsideBar(Rect bar, Rect rect, String what) {
  expect(rect.top, greaterThanOrEqualTo(bar.top - 0.5),
      reason: '$what is pushed above the app bar');
  expect(rect.bottom, lessThanOrEqualTo(bar.bottom + 0.5),
      reason: '$what hangs below the 85px toolbar, so the header clips it away');
  expect(rect.left, greaterThanOrEqualTo(bar.left - 0.5),
      reason: '$what starts outside the app bar on the left');
  expect(rect.right, lessThanOrEqualTo(bar.right + 0.5),
      reason: '$what runs past the right edge of the app bar');
}

/// True when the two rects share a line (the Row layout) rather than sitting one
/// under the other (the Column layout that caused the original clip).
bool _overlap(Rect a, Rect b) => a.top < b.bottom && b.top < a.bottom;

Future<void> _switchToExplore(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('vault_tab_explore')).hitTestable().first);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await db.close();
}

/// A cloud vault of [count] meals with long Arabic names — the worst case the
/// header badges and the grid title line can be handed.
List<CloudMeal> _cloudVault(int count) => [
      for (var i = 0; i < count; i++)
        CloudMeal(
          id: 'cloud_$i',
          name: 'مكرونة بشاميل باللحمة المفرومة بالصلصة $i',
          proteinType: 'chicken',
          carbsType: 'rice',
          category: 'tabeekh',
          prepTimeMinutes: 30,
          createdAt: DateTime(2025, 1, 1),
        ),
    ];

// ---------------------------------------------------------------------------
// Reported, deliberately not asserted here: opening the Explore tab overflows
// the cloud tiles underneath the header, which is a discovery-grid bug and not
// the counter-row clip this file pins.
//   * discovery_screen.dart:809 (`Column` under `Expanded > Padding`)
//       - 1.7 px on the bottom at the default 800x600 test surface
//       - 86 px on the bottom at 360x640
//   * discovery_screen.dart:819 (`Row` of protein badge + time pill + bookmark)
//       - 52 px on the right at 360x640
//   * widgets/meal_vault_card.dart:67 (`Column` of the local grid card)
//       - 4.1 px on the bottom at 360x640
// ---------------------------------------------------------------------------

