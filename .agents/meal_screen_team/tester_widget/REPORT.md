# Widget Tester Report

## Suite
`test/widget/meal_screen_test.dart`

## Cases
1. Full mockup chrome keys present for a known meal
2. shortName falls back to full name when empty
3. Not-found state for missing id
4. Side1 / Side2 / Main tab switching keeps panel mounted
5. Info card shows protein, carbs, prep, budget
6. Dark-mode scrim paints without throw
7. LTR English exposes localised dish tabs
8. MealDishSection can hide side tabs via flags

## Runtime note
Flutter SDK is not installed in this sandbox, so the suite was **statically validated**
(bracket balance, key contract, constructor signatures against `app_database.g.dart`).
Run on a machine with the SDK:

```bash
flutter test test/widget/meal_screen_test.dart
```

## Static gate
- No escaped-quote regressions (`\'`) from the prior incomplete rewrite
- All 12 stable keys present in `meal_screen.dart`
- Bracket balance PASS on all 4 touched sources
