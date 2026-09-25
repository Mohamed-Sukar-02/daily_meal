import 'package:daily_meal/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

/// The two free-text fields `QuickAddSheet` carries per meal: `shortName` is the
/// name the meal screen prints in its app bar, `notes` is the recipe body under
/// the dish panel. Both survive a save and come back on the next edit, which is
/// the three directions pinned here:
///  * opening the sheet on a row that *has* values shows them in the field the
///    user will read, not just in the database,
///  * a change that only ever lived inside one of those two fields still counts
///    as unsaved work, through every exit the sheet offers,
///  * saving writes both columns on the existing row and leaves the rest of the
///    row alone.
///
/// The editor is reached the way the app reaches it: a real row in a real
/// in-memory database, `/meal/:id` pushed on the app's own router, and that
/// screen's overflow → Edit — the same `QuickAddSheet.show(mealToEdit:)` the
/// vault cards call.
void main() {
  const nameField = Key('meal_form_name_field');
  const notesField = Key('meal_form_notes_field');
  const shortNameField = Key('meal_form_short_name_field');
  const saveButton = Key('meal_form_save_button');
  const cancelButton = Key('meal_form_cancel_button');
  const mealScreen = Key('meal_screen');
  const actionsButton = Key('meal_screen_actions_button');
  const editAction = Key('meal_screen_edit_action');
  const discardDialog = Key('discard_changes_dialog');
  const discardButton = Key('discard_changes_discard_button');
  const keepEditingButton = Key('discard_changes_keep_editing_button');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // A Dart local function cannot be referenced before its declaration, so the
  // shared primitives come before [openEditorOn], which leans on them.

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<TextFormField>(find.byKey(key)).controller!.text;

  /// The two fields sit far down a scroll view and have to be brought on screen
  /// first: `enterText` and `tap` both dispatch a tap, and a tap that would miss
  /// its target is a test failure rather than a no-op.
  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Types [extra] after whatever the field already holds.
  Future<void> appendTo(WidgetTester tester, Key key, String extra) async {
    await reveal(tester, key);
    await tester.enterText(find.byKey(key), '${textOf(tester, key)} $extra');
    await tester.pumpAndSettle();
  }

  /// Replaces the whole content of a field.
  Future<void> setField(WidgetTester tester, Key key, String value) async {
    await reveal(tester, key);
    await tester.enterText(find.byKey(key), value);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Key key) async {
    await reveal(tester, key);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Leaves the sheet through the scrim: the one exit that is not routed through
  /// the sheet's own close request, and so the one that only `PopScope.canPop`
  /// can gate.
  Future<void> tapBarrier(WidgetTester tester) async {
    final sheetTop = tester.getTopLeft(find.byType(BottomSheet));
    await tester.tapAt(Offset(20, sheetTop.dy - 10));
    await tester.pumpAndSettle();
  }

  /// Opens the sheet in edit mode on a row the app itself holds: a real row in a
  /// real in-memory database, `/meal/:id` pushed on the app's own router, and the
  /// screen's overflow → Edit — the same `QuickAddSheet.show(mealToEdit:)` the
  /// vault cards call.
  ///
  /// The default 800x600 test surface is left alone on purpose: it is what
  /// `meal_screen_edit_delete_test.dart` renders this screen at, and the sheet
  /// still leaves the scrim above its own top edge reachable for a barrier tap
  /// (see `quick_add_sheet_nav_barrier_test.dart`).
  Future<(AppDatabase, int)> openEditorOn(
    WidgetTester tester, {
    required String name,
    String? shortName,
    String? notes,
  }) async {
    final db = await pumpApp(tester);
    final id = await db.mealsDao.insertMeal(
      MealsCompanion(
        name: drift.Value(name),
        shortName: drift.Value(shortName),
        notes: drift.Value(notes),
        proteinType: const drift.Value(ProteinType.chicken),
        carbsType: const drift.Value(CarbsType.rice),
        category: const drift.Value(MealCategory.egyptianTraditional),
        prepTime: const drift.Value(45),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.byKey(const ValueKey('nav_destination_home'))),
    ).push('/meal/$id');
    await tester.pumpAndSettle();
    expect(find.byKey(mealScreen), findsOneWidget,
        reason: 'the meal under edit must be the one on screen');

    await tapVisible(tester, actionsButton);
    await tapVisible(tester, editAction);
    expect(
      find.byKey(saveButton),
      findsOneWidget,
      reason: 'Edit must open the shared quick-add sheet in edit mode',
    );
    return (db, id);
  }

  // -------------------------------------------------------------------------

  testWidgets('editing a meal prefills the notes and short-name fields',
      (tester) async {
    const name = 'ملوخية بالفراخ';
    const shortName = 'ملوخية';
    const notes = 'يُشوّح الثوم والكزبرة قبل الإضافة للمرقة';
    final (db, id) = await openEditorOn(
      tester,
      name: name,
      shortName: shortName,
      notes: notes,
    );

    expect(
      textOf(tester, shortNameField),
      shortName,
      reason: 'the app-bar name is edited in the short-name field',
    );
    expect(
      textOf(tester, notesField),
      notes,
      reason: 'a stored recipe must not open as an empty box',
    );
    expect(textOf(tester, nameField), name,
        reason: 'the two new fields did not displace the existing prefill');

    // The fields read the row, not a guess: what is stored is what is shown.
    final stored = await db.mealsDao.getMealById(id);
    expect(stored?.notes, textOf(tester, notesField));
    expect(stored?.shortName, textOf(tester, shortNameField));

    await tearDownApp(tester, db);
  });

  testWidgets('typing only into notes or short name flags unsaved changes',
      (tester) async {
    const notes = 'ملاحظة محفوظة مسبقا';
    final (db, id) = await openEditorOn(
      tester,
      name: 'فتة الناعم',
      shortName: 'فتة',
      notes: notes,
    );

    // 1. Notes, abandoned through Cancel.
    await appendTo(tester, notesField, 'مضافة');
    await tapVisible(tester, cancelButton);
    expect(
      find.byKey(discardDialog),
      findsOneWidget,
      reason: 'an edit that only reached the notes box is still unsaved work',
    );
    await tapVisible(tester, keepEditingButton);
    expect(find.byKey(discardDialog), findsNothing);
    expect(find.byKey(saveButton), findsOneWidget,
        reason: '"keep editing" leaves the sheet where it was');

    // 2. Put the notes back, so what follows is dirty *only* through the short
    // name: a guard that forgot that column would let this exit through in
    // silence and fail the expectation below.
    await setField(tester, notesField, notes);
    await appendTo(tester, shortNameField, 'بالخل');
    await tapBarrier(tester);
    expect(find.byKey(discardDialog), findsOneWidget,
        reason: 'a barrier dismissal runs Navigator.maybePop, which '
            'PopScope.canPop has to gate on the live field values');
    await tapVisible(tester, keepEditingButton);

    // 3. Still only the short name pending: back, then a real discard, which is
    // the one path that must write nothing.
    await pressSystemBack(tester, notesField);
    expect(find.byKey(discardDialog), findsOneWidget);
    await tapVisible(tester, discardButton);
    await tester.pumpAndSettle();
    expect(find.byKey(saveButton), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);

    final row = await db.mealsDao.getMealById(id);
    expect(row?.notes, notes, reason: 'a discarded draft writes nothing');
    expect(row?.shortName, 'فتة');

    await tearDownApp(tester, db);
  });

  testWidgets('saving writes the new notes and short name to the row',
      (tester) async {
    const name = 'كشري بالجبن';
    const editedShortName = 'كشري بالجبنة';
    const editedNotes = 'أرز وشعرية وعدس، والجبن فوقه في الفرن';
    final (db, id) = await openEditorOn(
      tester,
      name: name,
      shortName: 'كشري',
      notes: 'الوصفة القديمة',
    );

    await setField(tester, shortNameField, editedShortName);
    await setField(tester, notesField, editedNotes);

    await tapVisible(tester, saveButton);

    expect(find.byKey(discardDialog), findsNothing,
        reason: 'the row is already written — asking now is the bug');
    expect(find.byKey(saveButton), findsNothing,
        reason: 'a committed save closes the sheet');

    final row = await db.mealsDao.getMealById(id);
    expect(row?.shortName, editedShortName);
    expect(row?.notes, editedNotes);
    expect(row?.name, name,
        reason: 'editing the two text fields must not touch the rest of the '
            'row');
    expect(row?.prepTime, 45);

    await runOutToasts(tester);
    await tearDownApp(tester, db);
  });
}

/// The exact path Android back and a modal barrier tap take
/// (`Navigator.maybePop`) — the only pop flavour `PopScope.canPop` gates.
/// [insideSurface] keys the lookup to the navigator that owns the sheet's route
/// (the root one).
Future<void> pressSystemBack(WidgetTester tester, Key insideSurface) async {
  final context = tester.element(find.byKey(insideSurface));
  await Navigator.of(context).maybePop();
  await tester.pumpAndSettle();
}

/// A successful save leaves a 1.5 s toast timer behind, which
/// [AutomatedTestWidgetsFlutterBinding] refuses to see pending at teardown.
Future<void> runOutToasts(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 2));
