import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/features/vault/presentation/widgets/meal_details_sheet.dart';

// ---------------------------------------------------------------------------
// MealDetailsSheet (vault context) action-row regression guard.
//
// Build-only by design: tapping "propose" runs the cloud gate (connectivity
// plugin + AppToast timers) which needs the full app harness; the flow logic
// itself is covered by test/unit/meal_proposal_payload_test.dart. This test
// pins the CONTRACT the mission added:
//   • the pre-existing Edit / Delete buttons and keys survive unchanged,
//   • the new Cloud Staging Export + full-details entry points render beside
//     them (sheet is the export entry point per the implementation plan).
// ---------------------------------------------------------------------------

Meal _vaultMeal() {
  final now = DateTime(2026, 9, 21, 12);
  return Meal(
    id: 42,
    name: 'ملوخية بالفراخ',
    nameNormalized: 'ملوخيه بالفراخ',
    photoPath: null,
    proteinType: ProteinType.chicken,
    carbsType: CarbsType.rice,
    category: MealCategory.egyptianTraditional,
    prepTime: 60,
    isFridaySpecial: true,
    isBudgetFriendly: false,
    isFavorite: true,
    isStarterMeal: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealDetailsSheet(
              detailsContext: MealDetailsContext.vault,
              meal: _vaultMeal(),
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('vault sheet keeps the legacy edit/delete action keys', (tester) async {
    await _pumpSheet(tester);

    expect(find.byKey(const Key('meal_details_sheet')), findsOneWidget);
    expect(find.byKey(const Key('meal_details_edit_button')), findsOneWidget);
    expect(find.byKey(const Key('meal_details_delete_button')), findsOneWidget);
  });

  testWidgets('vault sheet exposes cloud-export and full-details entry points',
      (tester) async {
    await _pumpSheet(tester);

    expect(find.byKey(const Key('meal_details_propose_button')), findsOneWidget);
    expect(
      find.byKey(const Key('meal_details_fullscreen_button')),
      findsOneWidget,
    );
    // Both new buttons are enabled for a resolvable vault meal.
    final propose = tester.widget<OutlinedButton>(
      find.byKey(const Key('meal_details_propose_button')),
    );
    expect(propose.onPressed, isNotNull);
    final fullscreen = tester.widget<OutlinedButton>(
      find.byKey(const Key('meal_details_fullscreen_button')),
    );
    expect(fullscreen.onPressed, isNotNull);
  });

  testWidgets('history context stays read-only (no action buttons leak in)',
      (tester) async {
    final now = DateTime(2026, 9, 21, 12);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealDetailsSheet(
                detailsContext: MealDetailsContext.history,
                meal: _vaultMeal(),
                historyEntry: MealHistoryData(
                  id: 1,
                  mealId: 42,
                  mealName: 'ملوخية بالفراخ',
                  proteinType: ProteinType.chicken,
                  carbsType: CarbsType.rice,
                  cookedAt: now,
                  createdAt: now,
                  entryType: MealEntryType.cooked,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('meal_details_propose_button')), findsNothing);
    expect(find.byKey(const Key('meal_details_edit_button')), findsNothing);
  });
}
