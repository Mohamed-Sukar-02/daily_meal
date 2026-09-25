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

/// Two pieces of chrome are clipped to a fixed height and so cannot grow with
/// the system text scale:
///
///  * the 54px bottom navigation strip — `ScaffoldWithNavBar` / `_NavBarItem` in
///    `lib/core/router/app_router.dart`
///  * the meal-vault header inside its 85px `toolbarHeight` bar —
///    `_buildVaultHeaderWidget` in
///    `lib/features/vault/presentation/meal_vault_screen.dart`
///
/// Both stacked fixed heights under a tight box, so at 360x640 with text at 1.5x
/// they overflowed their box by 2.1px (27.6 icon + 1.5 + 23.0 label + 1.5 + 2.5
/// underline = 56.1px in the 54px strip) and 19px (50.0 title line + 4 + 28.0
/// subtitle = 82.0px in the 63px the 85px bar leaves after its 16/6 gutters). A
/// RenderFlex overflow paints past the clip line, and that is what was eaten:
/// the nav underline measured 2.1px below the strip's bottom edge and the vault
/// subtitle's line ended 13.0px below the bar's. These cases measure the painted
/// rect of every icon, label, chip and underline against the box that clips it.
///
/// Both surfaces now shrink their content with `FittedBox(fit: BoxFit.scaleDown)`
/// instead of letting it hang out, and scaleDown never enlarges — so the 1.0x
/// cases pin the designed geometry (`_navLabelHeight`, the 2.5px underline, the
/// 34px/19px header lines) to prove the guards stay inert at a normal text
/// scale, on the narrow phone and on a wide surface alike.
void main() {
  // -------------------------------------------------------------------------
  // Bug 1 — the bottom navigation strip (2.1px over at 360x640 / 1.5x).
  // -------------------------------------------------------------------------

  testWidgets('Bottom nav keeps all four labels inside the 54px strip at 1.5x '
      'text on a narrow phone', (tester) async {
    final db = await _openShell(tester, surface: _narrowPhone, textScale: 1.5);
    final strings = AppStrings(const Locale('ar'));
    final strip = _strip(tester);
    expect(strip.height, closeTo(_navStripHeight, 0.5),
        reason: 'the strip keeps its designed ${_navStripHeight}px height — the '
            'fix shrinks content, never the bar');

    double? tallestIconScale;
    for (final destination in _navDestinations(strings)) {
      final item = find.byKey(ValueKey(destination.key));
      expect(item, findsOneWidget, reason: destination.label);
      expect(
          find.descendant(
              of: item, matching: find.text(destination.label)),
          findsOneWidget,
          reason: '${destination.label} is still in the tree and still reads '
              'its own string at 1.5x text');

      final box = tester.getRect(item);
      final icon = tester.getRect(_iconIn(item));
      final label = tester.getRect(
          find.descendant(of: item, matching: find.text(destination.label)));
      final underline = tester.getRect(
          find.descendant(of: item, matching: find.byType(Container)).first);

      expect(box.height, closeTo(_navStripHeight, 0.5),
          reason: '${destination.label} keeps the whole ${_navStripHeight}px '
              'strip as its ink splash and tap target at 1.5x text — the guard '
              'shrinks the content inside it, never the hit area');
      _expectInsideStrip(strip, icon, '${destination.label} icon');
      _expectInsideStrip(strip, label, '${destination.label} label');
      _expectInsideStrip(strip, underline, '${destination.label} underline');

      // Everything inside one item scales by one factor: the icon is the ruler,
      // because an icon's box never follows the text scale.
      final scale = icon.height / destination.iconSize;
      expect(scale, inInclusiveRange(0.9, 1.0 + 1e-9),
          reason: '${destination.label} shrinks to fit, it is never crushed');
      expect(label.height, closeTo(_navLabelHeight15 * scale, 0.6),
          reason: '${destination.label} must scale with its icon, as one unit');
      expect(underline.height, closeTo(2.5 * scale, 0.3));
      expect(label.width, lessThanOrEqualTo(_navItemWidth + 0.5),
          reason: 'the label still respects the item width and ellipsizes at it');
      if (destination.iconSize == 27.6) tallestIconScale = scale;
      debugPrint('nav 1.5x/360 ${destination.label}: scale ${scale.toStringAsFixed(4)} '
          'icon ${icon.height.toStringAsFixed(2)} label ${label.height.toStringAsFixed(2)} '
          'underline ${underline.height.toStringAsFixed(2)}');
    }

    expect(tallestIconScale, lessThan(1.0),
        reason: 'the 27.6px-icon items are the ones that used to overflow by '
            '2.1px; they must be the ones that shrank');
    expect(tester.takeException(), isNull,
        reason: 'the nav Column must not overflow its 54px strip at 1.5x text');

    await _close(tester, db);
  });

  testWidgets('Bottom nav still draws every item at its designed sizes at 1.0x '
      'text on a narrow phone', (tester) async {
    final db = await _openShell(tester, surface: _narrowPhone, textScale: 1.0);
    final strings = AppStrings(const Locale('ar'));
    final strip = _strip(tester);
    expect(strip.height, closeTo(_navStripHeight, 0.5));

    for (final destination in _navDestinations(strings)) {
      final item = find.byKey(ValueKey(destination.key));
      final box = tester.getRect(item);
      final icon = tester.getRect(_iconIn(item));
      final label = tester.getRect(
          find.descendant(of: item, matching: find.text(destination.label)));
      final underline = tester.getRect(
          find.descendant(of: item, matching: find.byType(Container)).first);

      // The item's box is the ink splash and the tap target, and it is the strip
      // height at any text scale: the guard shrinks the content inside it, never
      // the hit area.
      expect(box.height, closeTo(_navStripHeight, 0.5),
          reason: '${destination.label} must keep the whole ${_navStripHeight}px '
              'strip as its tap target');
      expect(icon.width, closeTo(destination.iconSize, 0.5),
          reason: '${destination.label} icon must not be scaled at 1.0x text');
      expect(icon.height, closeTo(destination.iconSize, 0.5));
      expect(label.height, closeTo(_navLabelHeight, 0.5),
          reason: '${destination.label} text must not be scaled at 1.0x text');
      expect(underline.width, closeTo(22, 0.5),
          reason: 'the underline indicator is a fixed 22x2.5 design mark');
      expect(underline.height, closeTo(2.5, 0.5));
      _expectInsideStrip(box, icon, '${destination.label} icon');
      _expectInsideStrip(box, label, '${destination.label} label');
      _expectInsideStrip(box, underline, '${destination.label} underline');
    }

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('Bottom nav geometry on a wide surface follows the text scale, '
      'never the width', (tester) async {
    // 1.0x on a wide surface: the designed geometry, exactly as the mockups were
    // measured, with nothing ellipsized.
    var db = await _openShell(tester, surface: _wideSurface, textScale: 1.0);
    final strings = AppStrings(const Locale('ar'));
    for (final destination in _navDestinations(strings)) {
      final item = find.byKey(ValueKey(destination.key));
      final icon = tester.getRect(_iconIn(item));
      final label = tester.getRect(
          find.descendant(of: item, matching: find.text(destination.label)));
      expect(icon.height, closeTo(destination.iconSize, 0.5),
          reason: 'a wide surface at 1.0x may not trigger the shrink-to-fit');
      expect(label.height, closeTo(_navLabelHeight, 0.5));
      expect(label.width, lessThan(tester.getRect(item).width - 1),
          reason: 'the label has room on a wide surface, so it is not even '
              'ellipsized');
      _expectInsideStrip(_strip(tester), label, '${destination.label} label');
    }
    expect(tester.takeException(), isNull);
    await _close(tester, db);

    // 1.5x on the same surface: the overflow was vertical, so it is the same
    // 2.1px of pressure and the same shrink — proof the guard answers the text
    // scale and not the width of the phone.
    db = await _openShell(tester, surface: _wideSurface, textScale: 1.5);
    final strip = _strip(tester);
    expect(strip.height, closeTo(_navStripHeight, 0.5));
    double? tallScale;
    for (final destination in _navDestinations(strings)) {
      final item = find.byKey(ValueKey(destination.key));
      final icon = tester.getRect(_iconIn(item));
      final label = tester.getRect(
          find.descendant(of: item, matching: find.text(destination.label)));
      _expectInsideStrip(strip, icon, '${destination.label} icon');
      _expectInsideStrip(strip, label, '${destination.label} label');
      final scale = icon.height / destination.iconSize;
      expect(scale, inInclusiveRange(0.9, 1.0 + 1e-9));
      expect(label.height, closeTo(_navLabelHeight15 * scale, 0.6));
      if (destination.iconSize == 27.6) tallScale = scale;
      debugPrint('nav 1.5x/wide ${destination.label}: scale ${scale.toStringAsFixed(4)} '
          'label ${label.height.toStringAsFixed(2)}');
    }
    expect(tallScale, lessThan(1.0),
        reason: 'the pressure was vertical, so the same items shrink here as on '
            'the narrow phone: ${tallScale?.toStringAsFixed(4)}');
    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  // -------------------------------------------------------------------------
  // Bug 2 — the vault header inside the 85px bar (19px over at 360x640 / 1.5x).
  // Same family as the vault-header counter work: the bar clips whatever hangs
  // below `toolbarHeight`, so an overflowing header is invisible while still in
  // the widget tree.
  // -------------------------------------------------------------------------

  testWidgets('My Vault header keeps title, counters and subtitle inside the '
      '85px bar at 1.5x text on a narrow phone', (tester) async {
    final db = await _openShell(
      tester,
      surface: _narrowPhone,
      textScale: 1.5,
      tab: _VaultTab.myVault,
    );
    final strings = AppStrings(const Locale('ar'));

    final row = find.byKey(_localRowKey);
    expect(row, findsOneWidget, reason: 'the local counter row is still mounted');
    final bar = _barAround(tester, row);
    expect(bar.height, closeTo(_toolbarHeight, 0.5),
        reason: 'toolbarHeight stays the pinned 85px design constant');
    final padded = _paddedBar(bar);

    final rowRect = tester.getRect(row);
    final title = tester.getRect(_headerText(strings.vaultTitle));
    final subtitle = tester.getRect(_headerText(strings.vaultSubtitle));
    final chip = tester.getRect(find.byKey(_localChipKey));
    final sync = tester.getRect(find.byKey(_syncButtonKey));

    _expectInsideBar(padded, title, 'the header title');
    _expectInsideBar(padded, subtitle, 'the subtitle line');
    _expectInsideBar(padded, rowRect, 'the counter row');
    _expectInsideBar(padded, chip, 'the meals chip');
    _expectInsideBar(padded, sync, 'the sync icon');
    expect(title.top, closeTo(bar.top + 16, 0.5),
        reason: 'the header still starts on its 16px top gutter');
    // The subtitle is the line the 19px overflow used to shave away: it has to
    // stay under the counters, inside the bar, and be worth reading.
    expect(subtitle.top, greaterThan(rowRect.bottom),
        reason: 'the subtitle must stay the line under the counters, never '
            'stacked over them to fit');
    expect(subtitle.bottom, lessThanOrEqualTo(bar.bottom - 6 + 0.5),
        reason: 'the 19px overflow: the subtitle used to hang past the bar and '
            'its own 6px bottom gutter');
    expect(subtitle.height, greaterThan(8),
        reason: 'the header scales down to fit, it must not be squeezed away');
    expect(_overlap(chip, sync), isTrue,
        reason: 'the sync icon and the meals chip share one line at any text scale');
    expect(
        find.descendant(of: row, matching: find.text(strings.mealsCount(3))),
        findsOneWidget,
        reason: 'the counter still reads the real number');

    // One unit, one factor: the two lines keep the proportion they have at a
    // normal text scale, so the header shrinks as a whole instead of losing a
    // line. Measured here: title 38.41px, subtitle 21.51px, ratio 1.79 against
    // the 34.0/19.0 = 1.79 pair at 1.0x.
    expect(title.height / subtitle.height,
        closeTo(_vaultTitleHeight / _vaultSubtitleHeight, 0.02),
        reason: 'title and subtitle must scale by the same factor');
    expect(title.height, lessThan(_vaultTitleHeight * 1.5),
        reason: 'the guard has to engage, not let the 50px line overflow');
    expect(title.height, greaterThan(_vaultTitleHeight),
        reason: 'shrinking must still leave the title the bigger line');
    debugPrint('header 1.5x/360 my-vault: title ${title.height.toStringAsFixed(2)} '
        'row ${rowRect.height.toStringAsFixed(2)} subtitle '
        '${subtitle.height.toStringAsFixed(2)} spare under the gutter '
        '${(bar.bottom - 6 - subtitle.bottom).toStringAsFixed(2)}');

    expect(tester.takeException(), isNull,
        reason: 'the header Column must not overflow the 85px bar at 1.5x text');

    await _close(tester, db);
  });

  testWidgets('Explore header keeps both counter badges and the subtitle inside '
      'the 85px bar at 1.5x text', (tester) async {
    final db = await _openShell(
      tester,
      surface: _narrowPhone,
      textScale: 1.5,
      tab: _VaultTab.explore,
      overrides: [
        publicMealsProvider.overrideWith((ref) async => _cloudVault(1234)),
      ],
    );
    final strings = AppStrings(const Locale('ar'));

    final row = find.byKey(_exploreRowKey);
    expect(row, findsOneWidget, reason: 'the cloud counter row is still mounted');
    final bar = _barAround(tester, row);
    expect(bar.height, closeTo(_toolbarHeight, 0.5));
    final padded = _paddedBar(bar);

    _expectInsideBar(padded, tester.getRect(row), 'the two-badge cloud row');
    _expectInsideBar(padded, tester.getRect(find.byKey(_exploreChipKey)),
        'the cloud counter chip');
    final subtitle = tester.getRect(_headerText(strings.vaultSubtitleExplore));
    _expectInsideBar(padded, subtitle, 'the Explore subtitle line');
    // 1234 cloud meals, 3 of them already in the vault -> "1231 جديدة" +
    // "1234 أكلة". Shrinking to fit must keep both counters, never drop one.
    expect(
        find.descendant(of: row, matching: find.text(strings.vaultNewCount(1231))),
        findsOneWidget);
    expect(
        find.descendant(of: row, matching: find.text(strings.vaultCloudCount(1234))),
        findsOneWidget);

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('My Vault header keeps its designed geometry at 1.0x text on a '
      'narrow phone', (tester) async {
    final db = await _openShell(
      tester,
      surface: _narrowPhone,
      textScale: 1.0,
      tab: _VaultTab.myVault,
    );
    final strings = AppStrings(const Locale('ar'));

    final row = find.byKey(_localRowKey);
    final bar = _barAround(tester, row);
    expect(bar.height, closeTo(_toolbarHeight, 0.5));
    final padded = _paddedBar(bar);

    final title = tester.getRect(_headerText(strings.vaultTitle));
    final subtitle = tester.getRect(_headerText(strings.vaultSubtitle));
    // 28px Cairo on height: 1.2 paints a 34.0px line, the 13px subtitle a
    // 19.0px one, both unscaled: like the nav guard, the header must be
    // untouched at a normal text scale.
    expect(title.height, closeTo(_vaultTitleHeight, 0.5),
        reason: 'the header title keeps its designed line at 1.0x text');
    expect(subtitle.height, closeTo(_vaultSubtitleHeight, 0.5),
        reason: 'the subtitle keeps its designed line at 1.0x text');
    expect(title.top, closeTo(bar.top + 16, 0.5),
        reason: 'the header still starts on the bar\'s 16px top gutter');
    expect(subtitle.bottom, lessThanOrEqualTo(bar.bottom - 6 + 0.5),
        reason: 'and ends above its 6px bottom gutter');
    _expectInsideBar(padded, subtitle, 'the subtitle line');
    _expectInsideBar(padded, tester.getRect(row), 'the counter row');

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('Both chrome strips survive a large text scale in English too',
      (tester) async {
    final db = await _openShell(
      tester,
      surface: _narrowPhone,
      textScale: 1.5,
      language: AppLanguagePreference.en,
      tab: _VaultTab.myVault,
    );
    final strings = AppStrings(const Locale('en'));
    final strip = _strip(tester);

    for (final destination in _navDestinations(strings)) {
      final item = find.byKey(ValueKey(destination.key));
      _expectInsideStrip(
          strip,
          tester.getRect(
              find.descendant(of: item, matching: find.text(destination.label))),
          '${destination.label} label (en)');
    }

    final row = find.byKey(_localRowKey);
    final subtitle = tester.getRect(_headerText(strings.vaultSubtitle));
    _expectInsideBar(
        _paddedBar(_barAround(tester, row)), subtitle, 'the subtitle line (en)');

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// The narrow phone the mockups were never measured against, and a surface wide
/// enough that nothing may be scaled down on it.
const _narrowPhone = Size(360, 640);
const _wideSurface = Size(800, 1200);

/// `ScaffoldWithNavBar`'s `SizedBox(height: 54)` and the vault bar's pinned
/// `toolbarHeight: 85`.
const _navStripHeight = 54.0;
const _toolbarHeight = 85.0;

/// Four destinations across 360px.
const _navItemWidth = 90.0;

/// The lines these strips paint, measured on this harness with the bundled
/// Cairo font at a 1.0 text scale: the 10.5px nav label 15.0px tall, the 28px
/// vault title (height: 1.2) 34.0px, the 13px vault subtitle 19.0px. At a 1.5
/// text scale the nav label line is 23.0px and the header lines are 50.0px and
/// 28.0px, so the item needs 27.6 + 1.5 + 23.0 + 1.5 + 2.5 = 56.1px of nav in a
/// 54px strip and the header needs 50.0 + 4 + 28.0 = 82.0px in the 63px the bar
/// leaves after its gutters: the 2.1px and 19px of the two bug reports.
const _navLabelHeight = 15.0;
const _navLabelHeight15 = 23.0;
const _vaultTitleHeight = 34.0;
const _vaultSubtitleHeight = 19.0;

const _localRowKey = ValueKey('vault_local_count_row');
const _localChipKey = ValueKey('vault_local_count');
const _exploreRowKey = ValueKey('vault_explore_count_row');
const _exploreChipKey = ValueKey('vault_explore_count');
const _syncButtonKey = ValueKey('vault_sync_defaults_button');

/// One bottom-nav destination: its key, the label it is handed, and its designed
/// icon box.
class _Destination {
  const _Destination(this.key, this.label, this.iconSize);

  final String key;
  final String label;
  final double iconSize;
}

/// The four destinations of `ScaffoldWithNavBar`, labels straight out of
/// [AppStrings] so these cases track the real strings — and the Arabic pair,
/// which is the longer one.
List<_Destination> _navDestinations(AppStrings strings) => <_Destination>[
      _Destination('nav_destination_home', strings.navHome, 27.6),
      _Destination('nav_destination_vault', strings.navVault, 23.4),
      _Destination('nav_destination_history', strings.navHistory, 27.6),
      _Destination('nav_destination_settings', strings.navSettings, 27.6),
    ];

enum _VaultTab { myVault, explore }

/// The strip the bottom nav paints into: the `Row` the four items are Expanded
/// into, i.e. the box the 2.1px overflow hung out of.
Rect _strip(WidgetTester tester) => tester.getRect(find
    .ancestor(
        of: find.byKey(const ValueKey('nav_destination_home')),
        matching: find.byType(Row))
    .first);

/// The nav item's icon, whichever of the three icon kinds it renders. [Icon] and
/// [ImageIcon] lay out at their `size`, which never follows the text scale, so
/// the icon is the ruler these cases measure the shrink against.
Finder _iconIn(Finder item) => find
    .descendant(
      of: item,
      matching: find.byWidgetPredicate(
          (widget) => widget is Icon || widget is ImageIcon),
    )
    .first;

/// A header line, scoped to the bar: the vault title and the nav vault label are
/// the same Arabic string, so an unscoped `find.text` would match both.
Finder _headerText(String text) =>
    find.descendant(of: find.byType(FlexibleSpaceBar), matching: find.text(text)).first;

/// Boots the shell at [surface] / [textScale], and when [tab] is given opens the
/// Meal Vault (switching it to Explore for that tab).
Future<AppDatabase> _openShell(
  WidgetTester tester, {
  required Size surface,
  required double textScale,
  AppLanguagePreference language = AppLanguagePreference.ar,
  _VaultTab? tab,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final db = AppDatabase(NativeDatabase.memory());
  await db.appSettingsDao.ensureSettings();
  await db.appSettingsDao.updateSettings(
    AppSettingsCompanion(
      isFirstRun: const drift.Value(false),
      language: drift.Value(language),
    ),
  );
  await db.mealsDao.deleteAllMeals();
  for (var i = 0; i < 3; i++) {
    await db.mealsDao.insertMeal(MealsCompanion(
      name: drift.Value(language == AppLanguagePreference.en
          ? 'Beshamel macaroni with minced meat $i'
          : 'أكلة محفوظة $i'),
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

  if (tab != null) {
    await tester.tap(find.byKey(const ValueKey('nav_destination_vault')));
    await tester.pumpAndSettle();
    if (tab == _VaultTab.explore) await _switchToExplore(tester);
  }
  return db;
}

Future<void> _switchToExplore(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('vault_tab_explore')).hitTestable().first);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// The header is clipped by `FlexibleSpaceBar`, so that is the box everything
/// has to stay inside.
Rect _barAround(WidgetTester tester, Finder row) => tester
    .getRect(find.ancestor(of: row, matching: find.byType(FlexibleSpaceBar)).first);

/// The header's `Padding(16, 16, 16, 6)` gutters inside the bar.
Rect _paddedBar(Rect bar) =>
    Rect.fromLTRB(bar.left + 16, bar.top, bar.right - 16, bar.bottom);

void _expectInsideBar(Rect bar, Rect rect, String what) {
  expect(rect.top, greaterThanOrEqualTo(bar.top - 0.5),
      reason: '$what is pushed above the app bar');
  expect(rect.bottom, lessThanOrEqualTo(bar.bottom + 0.5),
      reason: '$what hangs below the ${_toolbarHeight}px toolbar, so the header '
          'clips it away');
  expect(rect.left, greaterThanOrEqualTo(bar.left - 0.5),
      reason: '$what starts outside the app bar on the left');
  expect(rect.right, lessThanOrEqualTo(bar.right + 0.5),
      reason: '$what runs past the right edge of the app bar');
}

void _expectInsideStrip(Rect strip, Rect rect, String what) {
  expect(rect.left, greaterThanOrEqualTo(strip.left - 0.5),
      reason: '$what starts outside the strip on the left');
  expect(rect.right, lessThanOrEqualTo(strip.right + 0.5),
      reason: '$what runs past the right edge of the strip');
  expect(rect.top, greaterThanOrEqualTo(strip.top - 0.5),
      reason: '$what is pushed above the ${_navStripHeight}px strip');
  expect(rect.bottom, lessThanOrEqualTo(strip.bottom + 0.5),
      reason: '$what hangs below the ${_navStripHeight}px strip, so the strip '
          'clips it away');
}

/// True when the two rects share a line rather than sitting one under another.
bool _overlap(Rect a, Rect b) => a.top < b.bottom && b.top < a.bottom;

Future<void> _close(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await db.close();
}

/// A cloud vault of [count] meals with long Arabic names — the worst case the
/// header badges can be handed.
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
