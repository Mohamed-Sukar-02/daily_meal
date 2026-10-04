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
// MealCard is gone), so the tile shape has to hold the same narrow phone with
// its photo bleed, its tinted panel, its love toggle and its swap control.
// ---------------------------------------------------------------------------

/// Finds the app's own glyph widget. `find.byIcon` is typed to `IconData`, so
/// [AppIcon] — which carries an `AppGlyph` — has to be matched structurally.
Finder _glyph(AppGlyph glyph) =>
    find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph);

Widget _phone(
  Widget child,
  Locale locale, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: child),
          ),
        ),
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
  isFridaySpecial: true,
);

/// A vault row with every flag on, so the quick card draws all its honour marks
/// and a filled heart at once. `photoPath` is null, which is also the only way
/// to exercise the empty-photo stand-in.
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
  MealCardVariant variant = MealCardVariant.photoWide,
}) {
  return QuickMealView.fromMeal(
    _cardMeal(name: name),
    shape: MealViewShape.quick,
    cardVariant: variant,
    photoCacheWidth: 1080,
    footer: QuickActions(onCookedToday: onCookedToday, stretch: true),
    onToggleFavorite: onToggleFavorite,
  );
}

void main() {
  testWidgets('renders every slot on a narrow RTL phone without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(_phone(_maximal, const Locale('ar')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('quick_meal_view')), findsOneWidget);
  });

  testWidgets('renders every slot on a narrow LTR phone without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _phone(
        const QuickMealView(
          name: 'Spaghetti bechamel with mince meat',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.grains,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 120,
          isFridaySpecial: true,
        ),
        Locale('en'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('drops the spec strip when there is nothing to show', (
    tester,
  ) async {
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

  testWidgets('the quick shape draws the whole home card in Arabic', (
    tester,
  ) async {
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
    // Photo bleed, empty-photo stand-in and both actions all render.
    expect(find.byKey(const Key('quick_meal_view')), findsOneWidget);
    expect(find.byKey(const Key('meal_photo_placeholder')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_cooked_today')), findsOneWidget);
    // The protein reads as a pill and the Friday honour as a second one; the
    // loved state is the filled heart itself, not a third pill.
    expect(find.text(strings.fridaySpecial), findsOneWidget);
    expect(_glyph(AppGlyph.heartFill), findsOneWidget);
    // Category is shown without any icon, prep time is removed, and CTA is 'هطبخها'.
    expect(
      find.text(MealCategory.egyptianTraditional.label(strings)),
      findsOneWidget,
    );
    expect(_glyph(AppGlyph.clock), findsNothing);
    expect(_glyph(AppGlyph.oven), findsNothing);
    expect(find.text(strings.cookThis), findsOneWidget);
    expect(strings.cookThis, 'هطبخها');
  });

  testWidgets('the quick shape wires love and cook to its own callbacks', (
    tester,
  ) async {
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

    // The heart floats on a corner the variant chooses, so the tap finds it by
    // key — the offset arithmetic this test used to do was only ever correct
    // for the one corner the old stacked card could draw.
    await tester.tap(find.byKey(const Key('quick_love_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(loved, 1);
    // The toggle pops to the outline glyph while the write is in flight.
    expect(_glyph(AppGlyph.heartOutline), findsOneWidget);
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

  // -------------------------------------------------------------------------
  // The card is dealt one of three cuts. Every cut has to hold the same
  // information in the same fixed-height tile — that height is what buys the
  // list back its third card, so a variant that overflows is worse than a
  // variant that looks plain.
  // -------------------------------------------------------------------------

  for (final variant in MealCardVariant.values) {
    testWidgets('the $variant cut draws the whole card without overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _phone(
          _quickCard(
            name: 'مكرونة بشاميل باللحمة المفرومة بالفرن',
            onCookedToday: () {},
            onToggleFavorite: () {},
            variant: variant,
          ),
          const Locale('ar'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('quick_love_button')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('quick_meal_view'))).height,
        192,
        reason: '$variant changed the tile height',
      );
    });
  }

  testWidgets('the quick card survives a large system font', (tester) async {
    await tester.pumpWidget(
      _phone(
        _quickCard(
          name: 'مكرونة بشاميل باللحمة المفرومة',
          onCookedToday: () {},
          onToggleFavorite: () {},
          variant: MealCardVariant.panelWide,
        ),
        const Locale('ar'),
        textScaler: const TextScaler.linear(2.0),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'balances medium dish names across <= 3 lines to avoid dead space on narrow screens',
    (tester) async {
      await tester.pumpWidget(
        _phone(
          _quickCard(
            name: 'كشري مصري بالصلصة والدقة',
            onCookedToday: () {},
            onToggleFavorite: () {},
            variant: MealCardVariant.photoWideSoft,
          ),
          const Locale('ar'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final textFinder = find.text('كشري مصري بالصلصة والدقة');
      expect(textFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.maxLines, 3);
    },
  );
}
