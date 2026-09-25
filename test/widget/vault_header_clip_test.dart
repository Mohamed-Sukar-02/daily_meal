import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/vault/data/models/cloud_meal.dart';
import 'package:daily_meal/features/vault/presentation/widgets/meal_vault_card.dart';
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
///
/// The cards are held to the same rule now. Nothing here ignores a layout error
/// any more: an overflowing discovery tile or vault card fails this file — see
/// the "cards" cases and, for the one case that has to tolerate other screens'
/// bugs, [_tallyOverflows].
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
    await tester.binding.setSurfaceSize(_narrowPhone);
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

    // Since the tiles below the header stopped overflowing, nothing is echoed
    // and dropped any more: this now also covers the Explore grid itself.
    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  // -------------------------------------------------------------------------
  // The cards that live under that header. These three sites used to overflow
  // while this file only printed their messages:
  //   * the cloud tile's footer Column  — 1.7px at 800x600, 86px at 360x640
  //   * its badge/time/bookmark Row     — 52px on the right at 360x640
  //   * the local vault card's Column   — 4.1px on the bottom at 360x640
  // Asserted for real now: no layout error may be attributed to a card, and the
  // painted geometry of every label and control has to sit inside the tile that
  // is supposed to contain it.
  // -------------------------------------------------------------------------

  testWidgets('Explore cloud tiles keep every label and control inside the card '
      'on a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(_narrowPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = await _openVault(
      tester: tester,
      overrides: [publicMealsProvider.overrideWith((ref) async => _cloudVault(6))],
    );
    await _switchToExplore(tester);

    final strings = AppStrings(const Locale('ar'));
    final card = _cloudCard(tester, 0);

    // The photo band keeps the mockup's 1.42 ratio: the fix grew the tile
    // instead of squeezing the picture or the text.
    final photo = tester.getRect(find
        .descendant(of: card.finder, matching: find.byType(AspectRatio))
        .first);
    expect(photo.width / photo.height, closeTo(1.42, 0.02),
        reason: 'the Explore photo band is drawn at its designed ratio');
    expect(photo.top, closeTo(card.rect.top, 0.5));

    // Measured here at 360x640 / Arabic / text scale 1.0: the tile is
    // 157.0 x 258.6 and its footer needs 146.0 of that, so nothing hangs past
    // the bottom any more (it used to overflow it by 86px).
    expect(card.rect.width, closeTo(157.0, 0.5));
    expect(card.rect.height, greaterThanOrEqualTo(photo.height + 146.0 - 0.5),
        reason: 'the tile must be tall enough for the footer it carries');

    final name = tester.getRect(find.descendant(
        of: card.finder, matching: find.text(_cloudMealName(0))));
    final meta = tester.getRect(find.descendant(
        of: card.finder,
        matching: find.textContaining(strings.discoveryAddedBy('1.2'))));
    final button = tester.getRect(
        find.descendant(of: card.finder, matching: find.byType(FilledButton)).first);
    final bookmark =
        tester.getRect(find.byKey(const ValueKey('cloud_bookmark_cloud_0')));
    final badgeRow = tester.getRect(find
        .ancestor(of: find.byKey(const ValueKey('cloud_bookmark_cloud_0')),
            matching: find.byType(Row))
        .first);

    _expectInside(card.rect, name, 'the meal name');
    _expectInside(card.rect, meta, 'the added-by line');
    _expectInside(card.rect, button, 'the download button');
    // The 52px overflow: the row now fits its card.
    _expectInside(card.rect, badgeRow, 'the badge/time/bookmark row');
    // ...without shrinking the fixed members of it.
    expect(bookmark.width, closeTo(34, 0.5),
        reason: 'the bookmark keeps its 34px tap target');
    expect(bookmark.height, closeTo(34, 0.5));
    expect(find.descendant(of: card.finder, matching: find.text('🐔')),
        findsOneWidget,
        reason: 'the protein badge stays in the tree, it is not dropped to fit');
    expect(
        tester
            .getRect(find.descendant(
                of: card.finder, matching: find.text(strings.minutes(30))))
            .width,
        greaterThan(20),
        reason: 'the time pill scales down to fit, it must not collapse');
    // Nothing is painted outside the card's rounded box either.
    expect(button.bottom, lessThanOrEqualTo(card.rect.bottom + 0.5),
        reason: 'the action row is the last line of the tile');

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('A wide surface still shows the whole cloud tile at its designed '
      'sizes', (tester) async {
    final db = await _openVault(
      tester: tester,
      overrides: [publicMealsProvider.overrideWith((ref) async => _cloudVault(6))],
    );
    await _switchToExplore(tester);

    final strings = AppStrings(const Locale('ar'));
    final card = _cloudCard(tester, 0);

    // 800x600 is the surface the design was measured on: every line of the
    // footer is painted at its natural size (no shrink-to-fit engaged), which is
    // what the 1.7px overflow used to eat.
    expect(
        tester
            .getRect(find.descendant(
                of: card.finder, matching: find.text(_cloudMealName(0))))
            .height,
        closeTo(20, 0.5),
        reason: 'the name line must not be scaled down on a wide card');
    expect(
        tester.getRect(find.byKey(const ValueKey('cloud_bookmark_cloud_0'))).height,
        closeTo(34, 0.5));
    final button = tester.getRect(
        find.descendant(of: card.finder, matching: find.byType(FilledButton)).first);
    _expectInside(card.rect, button, 'the download button');
    expect(button.width, closeTo(card.rect.width - 20, 0.5),
        reason: 'the action row still stretches across the card');
    expect(button.height, closeTo(48, 0.5));
    // Tile 0 is cloud-linked in this harness, so its action reads "update" —
    // the label the 1.7px overflow used to shave the bottom off of.
    expect(
        find.descendant(of: card.finder, matching: find.text(strings.discoveryUpdate)),
        findsOneWidget);

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('The local vault card keeps its badge row inside the tile on a '
      'narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(_narrowPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = await _openVault(tester: tester);

    final cardFinder = find.byType(MealVaultCard).first;
    final card = tester.getRect(cardFinder);
    final photo = tester.getRect(
        find.descendant(of: cardFinder, matching: find.byType(AspectRatio)).first);
    expect(photo.width / photo.height, closeTo(MealVaultCard.photoAspectRatio, 0.02),
        reason: 'the vault photo keeps the ratio measured from the mockup');

    // Before the fix the heart row hung 4.1px past this line and the card's own
    // Clip.antiAlias ate the bottom of it.
    final love = tester.getRect(_loveButtonIn(cardFinder));
    _expectInside(card, love, 'the loved toggle');
    expect(love.bottom, lessThanOrEqualTo(card.bottom + 0.5),
        reason: 'the heart used to sit 4.1px below the card edge, clipped away');
    _expectInside(
        card,
        tester.getRect(
            find.descendant(of: cardFinder, matching: find.textContaining('دقيقة'))),
        'the time pill');
    expect(
        tester
            .getRect(find.descendant(
                of: cardFinder, matching: find.textContaining('دقيقة')))
            .width,
        greaterThan(20),
        reason: 'the time pill shrinks, it must not collapse to nothing');

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  testWidgets('Both card grids lay out clean at 360x640 in English too',
      (tester) async {
    await tester.binding.setSurfaceSize(_narrowPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = await _openVault(
      tester: tester,
      language: AppLanguagePreference.en,
      overrides: [publicMealsProvider.overrideWith((ref) async => _cloudVault(6))],
    );
    await _switchToExplore(tester);

    final strings = AppStrings(const Locale('en'));
    final card = _cloudCard(tester, 0);
    _expectInside(
        card.rect,
        tester.getRect(find.descendant(
            of: card.finder, matching: find.text(_cloudMealName(0)))),
        'the meal name');
    _expectInside(card.rect,
        tester.getRect(find.byKey(const ValueKey('cloud_bookmark_cloud_0'))),
        'the bookmark button');
    _expectInside(
        card.rect,
        tester.getRect(
            find.descendant(of: card.finder, matching: find.byType(FilledButton)).first),
        'the download button');
    expect(
        tester
            .getRect(find.descendant(
                of: card.finder, matching: find.text(strings.minutes(30))))
            .width,
        greaterThan(20),
        reason: 'the English "30 minutes" pill stays readable at 360px');

    await _switchToMyVault(tester);
    final local = tester.getRect(find.byType(MealVaultCard).first);
    _expectInside(local, tester.getRect(_loveButtonIn(find.byType(MealVaultCard).first)), 'the loved toggle');

    expect(tester.takeException(), isNull);
    await _close(tester, db);
  });

  // At a large text scale these cases cannot use a bare `takeException()`: the
  // shell (bottom nav) and the vault header already overflow at 1.5x on a 360px
  // phone, and those two files belong to another session. Card overflows still
  // fail hard — see [_tallyOverflows] — everything else is echoed.
  testWidgets('Cards survive a large system text scale in Arabic',
      (tester) async {
    await _expectCardsCleanAtLargeTextScale(tester, AppLanguagePreference.ar);
  });

  testWidgets('Cards survive a large system text scale in English',
      (tester) async {
    await _expectCardsCleanAtLargeTextScale(tester, AppLanguagePreference.en);
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

const _localRowKey = ValueKey('vault_local_count_row');
const _localChipKey = ValueKey('vault_local_count');
const _exploreRowKey = ValueKey('vault_explore_count_row');
const _syncButtonKey = ValueKey('vault_sync_defaults_button');

/// The header's clip line. `SliverAppBar.toolbarHeight` in
/// `meal_vault_screen.dart` and `discovery_screen.dart` both say 85.
const _toolbarHeight = 85.0;

/// The narrow phone the mockups were never measured against.
const _narrowPhone = Size(360, 640);

/// The heart of a specific vault card (the grid renders three of them here).
Finder _loveButtonIn(Finder card) => find.descendant(
      of: card,
      matching: find.byWidgetPredicate((widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('meal_love_button_')),
    ).first;

/// A deliberately long meal name — the worst case a tile can be handed. Both
/// locales get the same data; only the surrounding UI strings differ.
String _cloudMealName(int index) =>
    'مكرونة بشاميل باللحمة المفرومة بالصلصة $index';

/// A cloud tile: its key-based finder plus the painted card rect that has to
/// contain everything the tile draws.
class _CloudCard {
  _CloudCard(this.finder, this.rect);

  final Finder finder;
  final Rect rect;
}

_CloudCard _cloudCard(WidgetTester tester, int index) {
  final finder = find.byKey(ValueKey('cloud_meal_card_cloud_$index'));
  expect(finder, findsOneWidget,
      reason: 'the Explore grid must render tile $index in grid view');
  return _CloudCard(finder, tester.getRect(finder));
}

void _expectInside(Rect outer, Rect inner, String what) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.5),
      reason: '$what starts outside the card on the left');
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.5),
      reason: '$what runs past the card edge on the right');
  expect(inner.top, greaterThanOrEqualTo(outer.top - 0.5),
      reason: '$what is pushed above the card');
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.5),
      reason: '$what hangs below the card, so the card clips it away');
}

/// Routes layout errors by owner. Used only by the large-text-scale case, which
/// cannot let every error through: the bottom nav and the vault header already
/// overflow at 1.5x text on a 360px phone, and both live in files this one does
/// not own. Nothing is silently dropped — foreign errors are echoed with the
/// widget that caused them, and a card error is kept for a hard expect.
class _OverflowTally {
  _OverflowTally(this._previous);

  final void Function(FlutterErrorDetails details)? _previous;

  /// Overflow errors inside a `cloud_meal_card_*` / `meal_card_*` subtree. Must
  /// stay empty.
  final List<String> cards = <String>[];

  /// Everything else, kept and printed so out-of-scope bugs stay visible.
  final List<String> notMine = <String>[];

  void restore() => FlutterError.onError = _previous;
}

_OverflowTally _tallyOverflows() {
  final previous = FlutterError.onError;
  final tally = _OverflowTally(previous);
  FlutterError.onError = (details) {
    final message = details.exception.toString();
    if (_isCardError(details)) {
      final entry = '${_culpritKey(details)} — $message';
      if (!tally.cards.contains(entry)) tally.cards.add(entry);
      return;
    }
    if (!tally.notMine.contains(message)) {
      final culprit = _culprit(details);
      tally.notMine.add('$culprit :: $message');
      debugPrint('out of scope (not a vault/discovery card): $culprit — $message');
    }
  };
  addTearDown(tally.restore);
  return tally;
}

/// Walks from the widget that owns the failing render object — the rendering
/// library parks a [DebugCreator] in `informationCollector`, which is where the
/// "relevant error-causing widget was:" line comes from — up to the card that
/// wraps it (`cloud_meal_card_*` / `meal_card_*`).
bool _isCardError(FlutterErrorDetails details) => _culpritKey(details) != null;

String? _culpritKey(FlutterErrorDetails details) {
  for (final node
      in details.informationCollector?.call() ?? const <DiagnosticsNode>[]) {
    final creator = node.value;
    if (creator is! DebugCreator || !creator.element.mounted) continue;
    String? hit;
    creator.element.visitAncestorElements((ancestor) {
      final key = ancestor.widget.key;
      if (key is ValueKey<String> &&
          (key.value.startsWith('cloud_meal_card_') ||
              key.value.startsWith('meal_card_'))) {
        hit = key.value;
        return false;
      }
      return true;
    });
    if (hit != null) return hit;
  }
  return null;
}

String _culprit(FlutterErrorDetails details) {
  for (final node
      in details.informationCollector?.call() ?? const <DiagnosticsNode>[]) {
    if (node.value is DebugCreator) return node.value.toString();
  }
  return 'unknown widget';
}

void _expectNoCardOverflow(_OverflowTally tally) {
  expect(tally.cards, isEmpty,
      reason: 'a discovery/vault card overflowed its own tile: ${tally.cards}');
}

/// Narrow phone + a large system text scale, in one locale. Arabic gives the
/// longer strings, English the wider glyphs, so both are run.
Future<void> _expectCardsCleanAtLargeTextScale(
    WidgetTester tester, AppLanguagePreference language) async {
  await tester.binding.setSurfaceSize(_narrowPhone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final tally = _tallyOverflows();
  final cloudCardKey = const ValueKey('cloud_meal_card_cloud_0');
  Rect cloudRect = Rect.zero, nameRect = Rect.zero, bookmarkRect = Rect.zero,
      buttonRect = Rect.zero, localRect = Rect.zero, loveRect = Rect.zero;
  final db = await _openVault(
    tester: tester,
    language: language,
    overrides: [publicMealsProvider.overrideWith((ref) async => _cloudVault(6))],
  );

  // Geometry is captured while the errors are still being routed; every expect
  // runs after the handler is restored, so nothing can be lost with it.
  try {
    await _switchToExplore(tester);
    cloudRect = tester.getRect(find.byKey(cloudCardKey));
    nameRect = tester.getRect(find.descendant(
        of: find.byKey(cloudCardKey), matching: find.text(_cloudMealName(0))));
    bookmarkRect = tester.getRect(find.byKey(const ValueKey('cloud_bookmark_cloud_0')));
    buttonRect = tester.getRect(find.descendant(
        of: find.byKey(cloudCardKey), matching: find.byType(FilledButton)).first);

    await _switchToMyVault(tester);
    localRect = tester.getRect(find.byType(MealVaultCard).first);
    loveRect = tester.getRect(_loveButtonIn(find.byType(MealVaultCard).first));
  } finally {
    tally.restore();
    await _close(tester, db);
  }

  _expectNoCardOverflow(tally);
  // The shrink-to-fit guards may shrink a footer, never drop its content: name,
  // bookmark, action button and heart are all still painted inside their tile.
  _expectInside(cloudRect, nameRect, 'the scaled meal name');
  _expectInside(cloudRect, bookmarkRect, 'the scaled bookmark button');
  _expectInside(cloudRect, buttonRect, 'the scaled download button');
  _expectInside(localRect, loveRect, 'the scaled loved toggle');
}

Future<void> _switchToMyVault(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('vault_tab_my_vault')).hitTestable().first);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Boots the app, completes onboarding and opens the Meal Vault. The vault grid
/// is wiped and replaced with three cloud-linked meals, so the Explore badges
/// have a known shared/new split instead of whatever `onCreate` seeded.
Future<AppDatabase> _openVault({
  required WidgetTester tester,
  List<Override> overrides = const [],
  AppLanguagePreference language = AppLanguagePreference.ar,
}) async {
  SharedPreferences.setMockInitialValues({});
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
          name: _cloudMealName(i),
          proteinType: 'chicken',
          carbsType: 'rice',
          category: 'tabeekh',
          prepTimeMinutes: 30,
          createdAt: DateTime(2025, 1, 1),
        ),
    ];
