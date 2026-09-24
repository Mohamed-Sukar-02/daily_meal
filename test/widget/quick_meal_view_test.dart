import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/features/meals/presentation/quick_meal_view.dart';

// ---------------------------------------------------------------------------
// QuickMealView is the shared meal presentation for every surface, so it has to
// survive the narrowest phone with the longest copy it can hold: a two-line
// name, a category overline, and three equal-width spec cells carrying the
// longest Arabic enum labels. Any of those overflowing throws in the test
// binding, which is the regression this pins.
// ---------------------------------------------------------------------------

Widget _phone(Widget child, Locale locale) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SizedBox(width: 360, child: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

/// Every slot populated at once.
const _maximal = QuickMealView(
  name: 'مكرونة بشاميل باللحمة المفرومة',
  proteinType: ProteinType.legume,
  carbsType: CarbsType.grains,
  category: MealCategory.egyptianTraditional,
  prepTimeMinutes: 1,
  isBudgetFriendly: true,
  isFridaySpecial: true,
);

void main() {
  testWidgets('renders every slot on a narrow RTL phone without overflowing',
      (tester) async {
    await tester.pumpWidget(_phone(_maximal, const Locale('ar')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('quick_meal_view')), findsOneWidget);
  });

  testWidgets('renders every slot on a narrow LTR phone without overflowing',
      (tester) async {
    await tester.pumpWidget(
      _phone(
        const QuickMealView(
          name: 'Spaghetti bechamel with mince meat',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.grains,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 120,
          isBudgetFriendly: true,
          isFridaySpecial: true,
        ),
        Locale('en'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('drops the spec strip when there is nothing to show',
      (tester) async {
    await tester.pumpWidget(
      _phone(
        const QuickMealView(
          name: 'شوربة',
          proteinType: ProteinType.none,
          carbsType: CarbsType.none,
        ),
        Locale('ar'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // No protein, no carbs, no time -> no separator line drawn.
    expect(find.text('شوربة'), findsOneWidget);
  });
}
