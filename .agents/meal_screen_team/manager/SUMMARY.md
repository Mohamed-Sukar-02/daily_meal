# Meal Screen Team — Delivery Summary

## Understanding confirmed (gradient / scrim)
User asked to confirm the name-overlay behaviour. Implemented as:

1. Soft veil under the full name — **white** in light mode, **near-black** in dark mode.
2. Alpha is light so the photo still shows through.
3. **Top edge** of the veil fades into the photo (vertical gradient).
4. **Trailing edge** of the text dissolves into the photo:
   - Arabic RTL → left edge fades
   - English LTR → right edge fades
5. Dual-axis paint via `CustomPaint` (`MealNameScrim`) — no hard rectangle cut.

## Deliverables
| File | Role |
|------|------|
| `lib/features/meals/presentation/meal_screen.dart` | Full screen rewrite (Stateful for dish tabs) |
| `lib/features/meals/presentation/widgets/meal_name_scrim.dart` | Theme + direction aware name overlay |
| `lib/features/meals/presentation/widgets/meal_dish_section.dart` | Main / Side1 / Side2 tabs + panel shell |
| `test/widget/meal_screen_test.dart` | Widget regression suite |
| `.agents/meal_screen_team/**` | Manager plan, perf review, this summary |

## Outer chrome locked (exact)
- Short name (top, bold)
- Hero 260h / 20r with full-name scrim
- Info rectangle (protein · carbs · prep · budget · friday)
- Hairline separator
- Dish tabs + selected panel
- Empty circular placeholder (no content yet)
- Notes / Edit / Delete

## Intentionally deferred
- Backend dish composition payloads (panel is a UI shell)
- Interior of any "more favorites" block
- Real side-dish visibility gating (always show 3 tabs for mockup parity)

## Merge
Branch `arena/01a0c71b-daily-meal` → PR into `main`.
