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
}
