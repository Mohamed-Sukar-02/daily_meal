import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

/// Third `PopScope` escape in `QuickAddSheet` (ISSUES.md
/// "ثغرتا مغادرة تتجاوزان PopScope في QuickAddSheet", item 2).
///
/// The sheet used to be presented with `showModalBottomSheet`'s default
/// `useRootNavigator: false`, which pushed it onto the *vault branch's*
/// navigator. That navigator's Overlay is the shell `Scaffold`'s body, so the
/// modal barrier stopped above the bottom navigation bar and the tabs stayed
/// live: tapping one with a half-typed meal switched branch and threw the sheet
/// route away without ever asking (measured before the fix, at 400x900: every
/// destination hit-testable and, after the tap, `sheet=false dialog=false
/// histSel=true` — the draft was destroyed in silence).
///
/// Presenting on the root navigator makes the barrier span the whole screen, so
/// no tab is reachable while the sheet is up, and a dismissal that does happen
/// runs through `Navigator.maybePop` — the one pop flavour `PopScope.canPop`
/// gates.
void main() {
  const discardDialog = Key('discard_changes_dialog');
  const keepEditingButton = Key('discard_changes_keep_editing_button');
  const nameField = Key('meal_form_name_field');

  const destinations = ['home', 'vault', 'history', 'settings'];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The nav bar marks the selected tab by weight, and every label is in the
  /// tree at all times (the shell keeps all four branches alive), so this is
  /// the only honest reading of "which tab is on screen".
  bool tabSelected(WidgetTester tester, String destination) {
    final widget = tester.widget<Text>(find.descendant(
      of: find.byKey(ValueKey('nav_destination_$destination')),
      matching: find.byType(Text),
    ));
    return widget.style?.fontWeight == FontWeight.w700;
  }

  Future<void> openQuickAdd(WidgetTester tester) async {
    await tapNav(tester, 'vault');
    await tester.tap(find.byKey(const Key('vault_add_fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_form_save_button')), findsOneWidget);
  }

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('a dirty quick-add sheet cannot be walked away from by the tabs',
      (tester) async {
    await setSize(tester, const Size(400, 900));
    final db = await pumpApp(tester);
    await openQuickAdd(tester);

    // 1. The whole navigation strip is out of reach while the sheet is up.
    for (final destination in destinations) {
      expect(
        find.byKey(ValueKey('nav_destination_$destination')).hitTestable(),
        findsNothing,
        reason: '$destination must sit behind the sheet or its barrier',
      );
    }

    // 2. A typed draft, then an attempt to leave through a tab.
    await tester.enterText(find.byKey(nameField), 'كشرى');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_destination_history')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tabSelected(tester, 'history'), isFalse,
        reason: 'the tab must not change underneath a sheet with unsaved text');
    expect(tabSelected(tester, 'vault'), isTrue);
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'the sheet must not be hidden away by a branch switch');
    expect(
      tester.widget<TextFormField>(find.byKey(nameField)).controller!.text,
      'كشرى',
      reason: 'the draft survives the attempt',
    );
    final meals = await db.select(db.meals).get();
    expect(meals.map((m) => m.name), isNot(contains('كشرى')),
        reason: 'an abandoned draft writes nothing');

    // 3. Leaving through the scrim is the guarded path: it asks first.
    final sheetTop = tester.getTopLeft(find.byType(BottomSheet));
    await tester.tapAt(Offset(20, sheetTop.dy - 10));
    await tester.pumpAndSettle();
    expect(find.byKey(discardDialog), findsOneWidget,
        reason: 'a barrier dismissal runs Navigator.maybePop, which '
            'PopScope.canPop gates — the reason the sheet is hosted on the '
            'root navigator');

    await tester.tap(find.byKey(keepEditingButton));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byKey(nameField)).controller!.text,
      'كشرى',
    );

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  testWidgets('a clean sheet still leaves through the scrim without asking, '
      'and still without moving the tab', (tester) async {
    await setSize(tester, const Size(400, 900));
    final db = await pumpApp(tester);
    await openQuickAdd(tester);

    final sheetTop = tester.getTopLeft(find.byType(BottomSheet));
    await tester.tapAt(Offset(20, sheetTop.dy - 10));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(discardDialog), findsNothing,
        reason: 'nothing was typed, so asking would be the old bug in reverse');
    expect(tabSelected(tester, 'vault'), isTrue,
        reason: 'closing the sheet must not be a tab switch');

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  testWidgets('hosting the sheet on the root navigator does not restyle it on a '
      'tablet', (tester) async {
    await setSize(tester, const Size(1280, 900));
    final db = await pumpApp(tester);
    await openQuickAdd(tester);

    final material = tester.getRect(find
        .descendant(
            of: find.byType(BottomSheet), matching: find.byType(Material))
        .first);

    // Material 3 caps a modal sheet at 640dp and centres it. That comes from
    // the theme (`_BottomSheetDefaultsM3.constraints`), not from the host
    // navigator, so covering the nav bar must not have moved it.
    expect(material.width, 640);
    expect(material.center.dx, 640,
        reason: 'still centred on a 1280dp screen');
    expect(material.bottom, 900,
        reason: 'flush with the bottom edge — the nav strip it used to stop '
            'above now sits behind it');
    for (final destination in destinations) {
      expect(
        find.byKey(ValueKey('nav_destination_$destination')).hitTestable(),
        findsNothing,
      );
    }

    // Copy and theme still resolve above the barrier: Localizations and the
    // app-level RTL Directionality are installed by MaterialApp *above* its
    // router navigator, and the single ProviderScope sits over the whole app.
    // Read through the sheet's own context, so this pins "Localizations is
    // reachable from a root-navigator route" rather than one language.
    final sheetContext =
        tester.element(find.byKey(const Key('meal_form_save_button')));
    final strings = AppStrings.of(sheetContext);
    expect(find.text(strings.quickAddMealTitle), findsOneWidget);
    expect(find.text(strings.mealNameLabel), findsOneWidget);
    expect(
      Directionality.of(
          tester.element(find.byKey(const Key('meal_form_save_button')))),
      TextDirection.ltr,
      reason: 'the sheet wraps itself in LTR on purpose; the host navigator '
          'must not change that',
    );

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });
}

/// Toast timers left running make [AutomatedTestWidgetsFlutterBinding] fail at
/// teardown.
Future<void> runOutToasts(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));
