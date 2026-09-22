# Perf Review — Meal Screen redesign

## Goals checked
- [x] Hero photo uses `cacheWidth: 900` (decode budget, matches prior screen).
- [x] No new packages / no extra rebuild sources beyond the dish-tab `setState`.
- [x] Dish-tab state is local (`_selectedDish`) — does **not** invalidate
      `allMealsProvider` or recommendation providers.
- [x] Favourite / propose still go through existing notifiers (no double-watch).
- [x] Scrim is a pure `CustomPaint` (no ImageFilter / BackdropFilter blur).
- [x] `AnimatedSwitcher` only wraps the dish panel, not the whole body.
- [x] ListView keeps the screen scrollable on small devices (no nested Expanded).
- [x] Keys are `const` — no string allocation in build.

## Residual risk
- Side-dish visibility currently forced `true` (frontend shell). When backend
  composition lands, gate `showSide1` / `showSide2` on real payload to avoid
  empty-tab clutter. No perf impact either way.

## Verdict
PASS — no hot-path regressions introduced.
