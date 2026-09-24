import 'package:daily_meal/core/providers/network_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

/// The Settings → Network & Cloud switch is the only UI for
/// `wifiOnlyCloudProvider`, the gate that blocks cloud meal proposals on mobile
/// data. Nothing used to exercise it, so a broken `onChanged` (or a switch bound
/// to the wrong value) would have shipped unnoticed.
void main() {
  const switchKey = Key('settings_wifi_only_switch');
  const prefsKey = 'wifi_only_cloud_access';

  /// `settings_scroll_view` is the `ListView` *widget*, which is not a
  /// `Scrollable`; scrollUntilVisible needs the real one inside it.
  final listScrollable = find
      .descendant(
        of: find.byKey(const Key('settings_scroll_view')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> revealSwitch(WidgetTester tester) => tester.scrollUntilVisible(
        find.byKey(switchKey),
        200,
        scrollable: listScrollable,
      );

  testWidgets('the switch mirrors the notifier and toggling it writes through',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await pumpApp(tester);

    await tapNav(tester, 'settings');
    await revealSwitch(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(switchKey), findsOneWidget);

    // Read the very same container the app runs on, through the switch's own
    // element, so this asserts the provider behind the UI and not a copy.
    final container = ProviderScope.containerOf(tester.element(find.byKey(switchKey)));
    expect(container.read(wifiOnlyCloudProvider), isFalse,
        reason: 'the shipped default is off (see kWifiOnlyCloudDefault)');
    expect(tester.widget<Switch>(find.byKey(switchKey)).value, isFalse);

    await tester.tap(find.byKey(switchKey));
    await tester.pumpAndSettle();

    expect(container.read(wifiOnlyCloudProvider), isTrue,
        reason: 'the notifier must follow the tap');
    expect(tester.widget<Switch>(find.byKey(switchKey)).value, isTrue,
        reason: 'and the switch must reflect the notifier, not local state');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(prefsKey), isTrue,
        reason: 'the choice has to survive a restart');

    // Turning it back off writes the same key — no sticky "Wi-Fi only".
    await tester.tap(find.byKey(switchKey));
    await tester.pumpAndSettle();
    expect(container.read(wifiOnlyCloudProvider), isFalse);
    expect(prefs.getBool(prefsKey), isFalse);

    await tearDownApp(tester, db);
  });

  testWidgets('a persisted Wi-Fi-only choice shows up on the switch',
      (tester) async {
    SharedPreferences.setMockInitialValues({prefsKey: true});
    final db = await pumpApp(tester);

    await tapNav(tester, 'settings');
    await revealSwitch(tester);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byKey(switchKey)));
    expect(container.read(wifiOnlyCloudProvider), isTrue,
        reason: 'the notifier loads from SharedPreferences on start');
    expect(tester.widget<Switch>(find.byKey(switchKey)).value, isTrue,
        reason: 'and the switch renders it');

    await tearDownApp(tester, db);
  });
}
