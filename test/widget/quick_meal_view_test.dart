import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/core/widgets/app_icons.dart';
import 'package:daily_meal/features/home/presentation/widgets/quick_actions.dart';
import 'package:daily_meal/features/meals/presentation/quick_meal_view.dart';

// ---------------------------------------------------------------------------
// QuickMealView is the shared meal presentation for every surface, so it has to
// survive the narrowest phone with the longest copy it can hold: a two-line
// name, a category overline, and three equal-width spec cells carrying the
// longest Arabic enum labels. Any of those overflowing throws in the test
// binding, which is the regression this pins.
//
// The second group pins the other half of the same promise: the home
// recommendation card is *this* widget in MealViewShape.quick (the old separate
// MealCard is gone), so the card shape has to hold the same narrow phone with
// its pills, its honour wrap, its love toggle and its footer action wired in.
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

/// A vault row with every flag on, so the quick card draws all three honour
/// pills and a filled heart at once.
Meal _cardMeal({required String name}) {
  final now = DateTime(2026, 9, 24, 12);
  return Meal(
    id: 1,
    name: name,
    nameNormalized: name,
    photoPath: null,
    proteinType: ProteinType.legume,
    carbsType: CarbsType.grains,
    category: MealCategory.egyptianTraditional,
    prepTime: 1,
    isFridaySpecial: true,
    isBudgetFriendly: true,
    isFavorite: true,
    isStarterMeal: false,
    createdAt: now,
    updatedAt: now,
  );
}

/// The exact composition the home recommendation list builds.
Widget _quickCard({
  required String name,
  required VoidCallback onCookedToday,
  required VoidCallback onToggleFavorite,
}) {
  return QuickMealView.fromMeal(
    _cardMeal(name: name),
    shape: MealViewShape.quick,
    padding: const EdgeInsets.all(10),
    photoCacheWidth: 1080,
    footer: QuickActions(onCookedToday: onCookedToday),
    onToggleFavorite: onToggleFavorite,
  );
}

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

  // -------------------------------------------------------------------------
  // The quick shape: this is the home recommendation card.
  // -------------------------------------------------------------------------

  testWidgets('the quick shape draws the whole home card in Arabic',
      (tester) async {
    const strings = AppStrings(Locale('ar'));
    await tester.pumpWidget(
      _phone(
        _quickCard(
          name: 'مكرونة بشاميل باللحمة المفرومة',
          onCookedToday: () {},
          onToggleFavorite: () {},
        ),
        const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Card surface, empty-photo stand-in and the footer action all render.
    expect(find.byKey(const Key('quick_meal_view')), findsOneWidget);
    expect(find.byKey(const Key('meal_photo_placeholder')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_cooked_today')), findsOneWidget);
    // Every honour the meal carries reads as its own pill.
    expect(find.text(strings.fridaySpecial), findsOneWidget);
    expect(find.text(strings.budgetFriendly), findsOneWidget);
    expect(find.text(strings.favorite), findsOneWidget);
    // Loved meal, so the floating heart is the filled glyph (one for the
    // toggle, one inside the loved pill).
    expect(
      find.byWidgetPredicate(
        (w) => w is AppIcon && w.glyph == AppGlyph.heartFill,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('the quick shape wires love and cook to its own callbacks',
      (tester) async {
    var cooked = 0;
    var loved = 0;
    await tester.pumpWidget(
      _phone(
        _quickCard(
          name: 'شوربة عدس',
          onCookedToday: () => cooked++,
          onToggleFavorite: () => loved++,
        ),
        const Locale('ar'),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('btn_cooked_today')));
    await tester.pump();
    expect(cooked, 1);

    // The heart floats 10px inside the hero's top-right corner, and the hero
    // sits 10px inside the card — so its centre is 40px in from each edge.
    final card = tester.getRect(find.byKey(const Key('quick_meal_view')));
    await tester.tapAt(Offset(card.right - 40, card.top + 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(loved, 1);
    // The toggle pops to the outline glyph while the write is in flight.
    expect(
      find.byWidgetPredicate(
        (w) => w is AppIcon && w.glyph == AppGlyph.heartOutline,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the quick shape survives a narrow LTR phone', (tester) async {
    await tester.pumpWidget(
      _phone(
        _quickCard(
          name: 'Spaghetti bechamel with mince meat',
          onCookedToday: () {},
          onToggleFavorite: () {},
        ),
        const Locale('en'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
