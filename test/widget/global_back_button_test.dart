import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

/// Global back-button state machine on `ScaffoldWithNavBar` (ISSUES.md
/// "سلوك مُضلّل في إشعار زر الرجوع العام").
///
/// Spec: back from a secondary tab walks to Home; the "press again to exit"
/// warning belongs to a press that happens *while already on Home*; a second
/// press inside the window leaves the app.
///
/// The old code showed the toast *and* set `_lastBackPressTime` in the
/// tab-switch branch, so the user was warned on the way to Home and a fast
/// second press quit outright.
///
/// What a widget test can observe here: which tab is selected (the nav bar
/// weights the selected label `w700`), whether the toast capsule is on screen,
/// and whether the framework asked the platform to close the app
/// (`SystemNavigator.pop` → a `SystemNavigator.pop` call on
/// `SystemChannels.platform`). What it cannot observe: the OS actually killing
/// the process — that call is the last thing the test can see, and it is what
/// "the app exits" means from inside one.
void main() {
  const destinations = ['home', 'vault', 'history', 'settings'];

  late TestDefaultBinaryMessenger messenger;
  late List<MethodCall> platformCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platformCalls = <MethodCall>[];
    messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Replaces the test binding's default `flutter/platform` handler for the
    // duration of the test only.
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  bool tabSelected(WidgetTester tester, String destination) {
    final widget = tester.widget<Text>(find.descendant(
      of: find.byKey(ValueKey('nav_destination_$destination')),
      matching: find.byType(Text),
    ));
    return widget.style?.fontWeight == FontWeight.w700;
  }

  /// The Android back button, dispatched the way the engine dispatches it: a
  /// `popRoute` call on `flutter/navigation` reaches the binding's
  /// `handlePopRoute` → `Router`'s observer →
  /// `GoRouterDelegate.popRoute()` → `Navigator.maybePop()` → the shell's
  /// `PopScope(canPop: false)`, which is where this state machine lives.
  ///
  /// (`SystemChannels.navigation.invokeMethod('popRoute')` looks equivalent but
  /// is dropped by the test messenger's outbound side, so the message is
  /// delivered the way a platform delivers it instead.)
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pump();
  }

  String exitToast(WidgetTester tester) =>
      AppStrings.of(tester.element(find.byType(Scaffold).first)).pressAgainToExit;

  /// A tab tap that burns as little fake time as the shell needs to switch
  /// (`_navLock` releases on a post-frame callback with a 32 ms fallback).
  /// `tapNav`'s `pumpAndSettle` would advance well past the two-second exit
  /// window on its own and the assertion below would prove nothing.
  Future<void> shallowTapNav(WidgetTester tester, String destination) async {
    await tester.tap(find.byKey(ValueKey('nav_destination_$destination')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
  }

  bool appWasAskedToExit() =>
      platformCalls.any((c) => c.method == 'SystemNavigator.pop');

  testWidgets('back on a secondary tab walks to Home without arming the exit '
      'warning, and the warning then needs its own two presses', (tester) async {
    final db = await pumpApp(tester);
    await tapNav(tester, 'vault');
    expect(tabSelected(tester, 'vault'), isTrue);

    // Press 1 — on Vault: navigate home. No exit copy, nothing armed.
    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(tabSelected(tester, 'home'), isTrue,
        reason: 'back from a secondary tab belongs to that tab: it walks to Home');
    expect(find.text(exitToast(tester)), findsNothing,
        reason: 'warning about exiting while the user is still travelling to '
            'Home is the misleading copy this item is about');

    // Press 2 — now on Home: warn, and only now start the window.
    await pressBack(tester);
    expect(find.text(exitToast(tester)), findsOneWidget,
        reason: 'the first press that happens *on* Home owns the warning');
    expect(appWasAskedToExit(), isFalse,
        reason: 'one press on Home never exits');

    // Press 3 — inside the window: leave, exactly as before.
    await pressBack(tester);
    await tester.pump();
    expect(appWasAskedToExit(), isTrue,
        reason: 'the warned-about second press does exit');
    expect(platformCalls.where((c) => c.method == 'SystemNavigator.pop').length, 1,
        reason: 'the tab-switch press must not have exited on the way');

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  testWidgets('leaving Home retires a stale exit warning instead of arming an '
      'instant quit', (tester) async {
    final db = await pumpApp(tester);
    expect(tabSelected(tester, 'home'), isTrue);

    // Warn once on Home…
    await pressBack(tester);
    expect(find.text(exitToast(tester)), findsOneWidget);

    // …then go away and come back, well inside the two-second window. The old
    // timer must not survive the trip.
    await shallowTapNav(tester, 'settings');
    await shallowTapNav(tester, 'home');
    expect(tabSelected(tester, 'home'), isTrue);

    await pressBack(tester);
    expect(appWasAskedToExit(), isFalse,
        reason: 'a press across a tab change is a first press again, however '
            'soon it follows the warning it was given');
    expect(find.text(exitToast(tester)), findsOneWidget,
        reason: 'and the user is told so again');

    // Third press of this new window exits.
    await pressBack(tester);
    await tester.pump();
    expect(appWasAskedToExit(), isTrue);

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  testWidgets('back on every secondary tab only changes the tab',
      (tester) async {
    final db = await pumpApp(tester);

    for (final destination in destinations.where((d) => d != 'home')) {
      await tapNav(tester, destination);
      expect(tabSelected(tester, destination), isTrue,
          reason: 'setup: $destination is on screen');
      platformCalls.clear();

      await pressBack(tester);
      await tester.pumpAndSettle();

      expect(tabSelected(tester, 'home'), isTrue,
          reason: 'back from $destination belongs to $destination');
      expect(find.text(exitToast(tester)), findsNothing);
      expect(appWasAskedToExit(), isFalse);
    }

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });
}

/// Toast timers left running make [AutomatedTestWidgetsFlutterBinding] fail at
/// teardown.
Future<void> runOutToasts(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));
