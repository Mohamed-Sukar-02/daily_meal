import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('"More" opens the cooldown details as a modal bottom sheet',
      (tester) async {
    final db = await pumpApp(tester);

    await tapNav(tester, 'settings');
    await tester.ensureVisible(find.byKey(const Key('settings_cooldown_more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_cooldown_more')));
    await tester.pumpAndSettle();

    // A real modal route — not an in-page expansion.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('cooldown_details_sheet_scroll')), findsOneWidget);

    // All four protein rules are exposed.
    for (final protein in ['chicken', 'beef', 'fish', 'meatless']) {
      expect(find.byKey(Key('cooldown_switch_$protein')), findsOneWidget,
          reason: 'missing switch for $protein');
    }

    await tearDownApp(tester, db);
  });

  testWidgets('tapping outside the sheet dismisses it', (tester) async {
    final db = await pumpApp(tester);

    await tapNav(tester, 'settings');
    await tester.ensureVisible(find.byKey(const Key('settings_cooldown_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_cooldown_more')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    // Tap the dimmed barrier, well above the sheet.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing,
        reason: 'an outside tap must cancel the sheet');
    // The settings page behind it is still there and untouched.
    expect(find.byKey(const Key('settings_scroll_view')), findsOneWidget);

    await tearDownApp(tester, db);
  });

  testWidgets('cooldown changes made in the sheet are persisted', (tester) async {
    final db = await pumpApp(tester);

    bool chickenSwitchValue() => tester
        .widget<Switch>(find.byKey(const Key('cooldown_switch_chicken')))
        .value;

    Future<void> openSheet() async {
      await tester.ensureVisible(
          find.byKey(const Key('settings_cooldown_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_cooldown_more')));
      await tester.pumpAndSettle();
    }

    await tapNav(tester, 'settings');
    await openSheet();
    expect(chickenSwitchValue(), isTrue, reason: 'chicken defaults to 7 days');

    // Turn the rule off and close the sheet the way a user would.
    await tester.tap(find.byKey(const Key('cooldown_switch_chicken')));
    await tester.pumpAndSettle();
    expect(chickenSwitchValue(), isFalse);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    // Reopening must show the persisted value, not the default.
    await openSheet();
    expect(chickenSwitchValue(), isFalse,
        reason: 'the choice must survive closing the sheet');

    // Turning it back on restores the remembered day count (> 0 days).
    await tester.tap(find.byKey(const Key('cooldown_switch_chicken')));
    await tester.pumpAndSettle();
    expect(chickenSwitchValue(), isTrue);

    await tearDownApp(tester, db);
  });

  testWidgets('meatless switch defaults to false, hides stepper on main card, and appears when enabled',
      (tester) async {
    final db = await pumpApp(tester);

    await tapNav(tester, 'settings');
    await tester.ensureVisible(find.byKey(const Key('settings_cooldown_header')));
    await tester.pumpAndSettle();

    // 1. Meatless (خضار) is NOT present on the main card by default
    expect(find.text('خضار'), findsNothing);

    // 2. Open "More" sheet
    await tester.tap(find.byKey(const Key('settings_cooldown_more')));
    await tester.pumpAndSettle();

    // 3. Meatless switch must be false by default
    final meatlessSwitchFinder = find.byKey(const Key('cooldown_switch_meatless'));
    expect(meatlessSwitchFinder, findsOneWidget);
    expect(tester.widget<Switch>(meatlessSwitchFinder).value, isFalse);

    // 4. Toggle Meatless switch to ON
    await tester.tap(meatlessSwitchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(meatlessSwitchFinder).value, isTrue);

    // 5. Close the sheet
    await tester.tap(find.byKey(const Key('cooldown_details_done')));
    await tester.pumpAndSettle();
    // 6. Meatless stepper row is now visible on the main card!
    await tester.scrollUntilVisible(
      find.byKey(const Key('cooldown_stepper_meatless')),
      100,
    );
    expect(find.byKey(const Key('cooldown_stepper_meatless')), findsOneWidget);

    // 7. Re-open sheet and turn it OFF
    await tester.tap(find.byKey(const Key('settings_cooldown_more')));
    await tester.pumpAndSettle();
    await tester.tap(meatlessSwitchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(meatlessSwitchFinder).value, isFalse);

    // 8. Close sheet -> Meatless stepper disappears from main card
    await tester.tap(find.byKey(const Key('cooldown_details_done')));
    await tester.pumpAndSettle();
    expect(find.text('خضار'), findsNothing);

    await tearDownApp(tester, db);
  });
}
