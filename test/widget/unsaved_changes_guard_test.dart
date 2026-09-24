import 'package:daily_meal/features/welcome/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

/// Unsaved-changes guard on every editable surface (ISSUES.md
/// "Unsaved Changes Confirmation Dialog / PopScope").
///
/// Two opposite directions are pinned down here:
///  * a *committed* edit (Save) closes its surface with no confirmation at all,
///  * an *abandoned* edit — including one that only ever lived inside a text
///    field — is never dropped silently: the shared prompt asks first.
///
/// The abandon cases are driven through [pressSystemBack], which is the exact
/// path Android back and a scrim tap take (`Navigator.maybePop`): that is the
/// only path `PopScope.canPop` gates. An imperative `Navigator.pop()` is never
/// gated by `canPop`, so a surface that closes itself (after saving) has to say
/// so with a flag instead of relying on the route staying poppable.
void main() {
  const discardDialog = Key('discard_changes_dialog');
  const discardButton = Key('discard_changes_discard_button');
  const keepEditingButton = Key('discard_changes_keep_editing_button');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // -------------------------------------------------------------------------
  // Edit profile dialog (Settings)
  // -------------------------------------------------------------------------

  Future<void> openProfileDialog(WidgetTester tester) async {
    await tapNav(tester, 'settings');
    await tester.ensureVisible(find.byKey(const Key('settings_profile_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_profile_card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_save_button')), findsOneWidget);
  }

  testWidgets('profile: a typed-only change is not thrown away by back',
      (tester) async {
    final db = await pumpApp(tester);

    await openProfileDialog(tester);
    await tester.enterText(find.byKey(const Key('profile_name_field')), 'سارة');
    await tester.pumpAndSettle();

    await pressSystemBack(tester, const Key('profile_name_field'));

    expect(
      find.byKey(discardDialog),
      findsOneWidget,
      reason: 'typing alone must make the form dirty (no setState on a '
          'TextEditingController — canPop has to be recomputed)',
    );

    await tester.tap(find.byKey(discardButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_save_button')), findsNothing);
    final settings = await db.appSettingsDao.getSettings();
    expect(settings.userName, isNot('سارة'), reason: 'discarding saves nothing');

    await tearDownApp(tester, db);
  });

  testWidgets('profile: "Keep editing" leaves the dialog open with the text',
      (tester) async {
    final db = await pumpApp(tester);

    await openProfileDialog(tester);
    await tester.enterText(find.byKey(const Key('profile_name_field')), 'منى');
    await tester.pumpAndSettle();
    await pressSystemBack(tester, const Key('profile_name_field'));
    expect(find.byKey(discardDialog), findsOneWidget);

    await tester.tap(find.byKey(keepEditingButton));
    await tester.pumpAndSettle();

    expect(find.byKey(discardDialog), findsNothing);
    expect(find.byKey(const Key('profile_save_button')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('profile_name_field')))
          .controller!
          .text,
      'منى',
    );

    await tearDownApp(tester, db);
  });

  testWidgets('profile: saving closes the dialog without any prompt',
      (tester) async {
    final db = await pumpApp(tester);

    await openProfileDialog(tester);
    await tester.enterText(find.byKey(const Key('profile_name_field')), 'يوسف');
    // Gender is required, so the save button needs it before it enables.
    await tester.tap(find.byKey(const Key('profile_gender_male')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_gender_male')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile_save_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(discardDialog), findsNothing,
        reason: 'the save already committed — asking now is the bug');
    expect(find.byKey(const Key('profile_save_button')), findsNothing,
        reason: 'the dialog must close on its own after a successful save');
    final settings = await db.appSettingsDao.getSettings();
    expect(settings.userName, 'يوسف');

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  // -------------------------------------------------------------------------
  // Quick add meal sheet (Vault)
  // -------------------------------------------------------------------------

  Future<void> openQuickAdd(WidgetTester tester) async {
    await tapNav(tester, 'vault');
    await tester.tap(find.byKey(const Key('vault_add_fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_form_save_button')), findsOneWidget);
  }

  testWidgets('quick add: back after typing asks before discarding',
      (tester) async {
    final db = await pumpApp(tester);

    await openQuickAdd(tester);
    await tester.enterText(
        find.byKey(const Key('meal_form_name_field')), 'كشرى');
    await tester.pumpAndSettle();

    await pressSystemBack(tester, const Key('meal_form_name_field'));

    expect(find.byKey(discardDialog), findsOneWidget);
    await tester.tap(find.byKey(keepEditingButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_form_save_button')), findsOneWidget);

    final meals = await db.select(db.meals).get();
    expect(meals.map((m) => m.name), isNot(contains('كشرى')),
        reason: 'the draft was abandoned, nothing was written');

    await tearDownApp(tester, db);
  });

  testWidgets('quick add: the X button asks, discarding closes the sheet',
      (tester) async {
    final db = await pumpApp(tester);

    await openQuickAdd(tester);
    await tester.enterText(
        find.byKey(const Key('meal_form_name_field')), 'ملوخية');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.byKey(discardDialog), findsOneWidget);

    await tester.tap(find.byKey(discardButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal_form_save_button')), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);

    await tearDownApp(tester, db);
  });

  testWidgets('quick add: a swipe down never destroys a typed meal silently',
      (tester) async {
    final db = await pumpApp(tester);

    await openQuickAdd(tester);
    await tester.enterText(
        find.byKey(const Key('meal_form_name_field')), 'رز بالحليب');
    await tester.pumpAndSettle();

    // Drag from the sheet's own header strip: the region the drag-to-close
    // gesture owns (everything below belongs to the form's scroll view).
    final sheetTop = tester.getTopLeft(find.byType(BottomSheet));
    await tester.dragFrom(sheetTop + const Offset(200, 6), const Offset(0, 340));
    await tester.pumpAndSettle();

    final sheetGone = find.byType(BottomSheet).evaluate().isEmpty;
    final asked = find.byKey(discardDialog).evaluate().isNotEmpty;
    expect(sheetGone && !asked, isFalse,
        reason: 'either the sheet survived the swipe or the user was asked — '
            'a silent close loses the typed meal');

    final meals = await db.select(db.meals).get();
    expect(meals.map((m) => m.name), isNot(contains('رز بالحليب')));

    await tearDownApp(tester, db);
  });

  testWidgets('quick add: saving closes the sheet without any prompt',
      (tester) async {
    final db = await pumpApp(tester);

    await openQuickAdd(tester);
    await tester.enterText(
        find.byKey(const Key('meal_form_name_field')), 'أكلة محفوظه');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('meal_form_save_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meal_form_save_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(discardDialog), findsNothing,
        reason: 'the meal is already written — asking now is the bug');
    expect(find.byKey(const Key('meal_form_save_button')), findsNothing,
        reason: 'a committed save must close the sheet');
    final meals = await db.select(db.meals).get();
    expect(meals.map((m) => m.name), contains('أكلة محفوظه'));

    // Let the success toast finish so no timer is left pending.
    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });

  // -------------------------------------------------------------------------
  // Welcome / onboarding
  // -------------------------------------------------------------------------

  Future<void> pumpWelcome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const WelcomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToStep2(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('welcome_start_now_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome_name_field')), findsOneWidget);
  }

  testWidgets('welcome: back on step 2 returns to step 1 and keeps the name',
      (tester) async {
    await pumpWelcome(tester);
    await goToStep2(tester);

    await tester.enterText(find.byKey(const Key('welcome_name_field')), 'هدى');
    await tester.pumpAndSettle();

    await pressSystemBack(tester, const Key('welcome_name_field'));

    expect(find.byKey(discardDialog), findsNothing,
        reason: 'step 2 has a step 1 to go back to — nothing is lost, so no '
            'prompt belongs here');
    expect(find.byKey(const Key('welcome_start_now_button')), findsOneWidget);

    await goToStep2(tester);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('welcome_name_field')))
          .controller!
          .text,
      'هدى',
      reason: 'going back must not destroy the typed name',
    );

    // Now leaving the whole screen asks instead of dropping the draft.
    await tester.tap(find.byKey(const Key('welcome_back_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome_start_now_button')), findsOneWidget);

    await pressSystemBack(tester, const Key('welcome_start_now_button'));
    expect(find.byKey(discardDialog), findsOneWidget);
  });

  testWidgets('welcome: an untouched form never shows the prompt',
      (tester) async {
    await pumpWelcome(tester);
    await goToStep2(tester);

    await pressSystemBack(tester, const Key('welcome_name_field'));

    expect(find.byKey(discardDialog), findsNothing);
    // Clean step 2 behaves as before: plain back navigation to step 1.
    expect(find.byKey(const Key('welcome_start_now_button')), findsOneWidget);
  });

  testWidgets('welcome: discarding a filled form leaves no prompt behind',
      (tester) async {
    await pumpWelcome(tester);
    await goToStep2(tester);
    await tester.enterText(find.byKey(const Key('welcome_name_field')), 'ريم');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome_back_button')));
    await tester.pumpAndSettle();

    await pressSystemBack(tester, const Key('welcome_start_now_button'));
    expect(find.byKey(discardDialog), findsOneWidget);

    await tester.tap(find.byKey(keepEditingButton));
    await tester.pumpAndSettle();
    expect(find.byKey(discardDialog), findsNothing);
    expect(find.byKey(const Key('welcome_start_now_button')), findsOneWidget);

    await goToStep2(tester);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('welcome_name_field')))
          .controller!
          .text,
      'ريم',
    );
  });
}

/// The key that sits inside the surface about to be popped, so the lookup lands
/// on the Navigator that owns its route (dialogs and modal sheets use the root
/// one).
///
/// `maybePop` is what Android back and a modal barrier tap dispatch, and it is
/// the only pop flavour that consults `PopScope.canPop`.
Future<void> pressSystemBack(WidgetTester tester, Key insideSurface) async {
  final context = tester.element(find.byKey(insideSurface));
  await Navigator.of(context).maybePop();
  await tester.pumpAndSettle();
}

/// A successful save leaves a 1.5 s toast timer behind, which
/// [AutomatedTestWidgetsFlutterBinding] refuses to see pending at teardown.
Future<void> runOutToasts(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 2));
