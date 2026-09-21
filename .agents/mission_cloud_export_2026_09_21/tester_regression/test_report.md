# tester_regression — regression map & verdict

## Touched-file → existing-test matrix
| Touched file | Existing tests exercising it | Impact analysis | Verdict |
|---|---|---|---|
| meal_vault_screen.dart (RepaintBoundary ×2 itemBuilders) | vault_controls_test, vault_fab_test, vault_header_clip_test | RepaintBoundary is finder-transparent (byKey/byType/descendant unaffected); NO `find.ancestor` anywhere in test/ (grep-verified); header clip test measures SliverAppBar/title/sync-button rects — all OUTSIDE the item builders | SAFE |
| meal_details_sheet.dart (vault section → Column[legacy Row, new Row]) | none reference MealDetailsSheet or meal_details_* keys (grep-verified) | legacy edit/delete Row preserved byte-identically incl. keys/styles; history & explore branches untouched; new widget test pins the contract going forward | SAFE |
| app_router.dart (+ /meal/:id root route) | navbar_icons_test, widget_test (boot DailyMealApp) | additive route only; redirect logic untouched (/meal/* passes through: isFirstRun users still gated to /welcome — route added AFTER welcome gate semantics unchanged); no test asserts route counts | SAFE |
| app_icons.dart (+cloudUp enum & case) | navbar_icons_test (nav glyphs only) | exhaustive switch extended in lockstep (enum+case); audit check #3 proves no missing case (would be a compile error) | SAFE |
| app_strings.dart (+12 getters) | tests using strings.* getters | purely additive; no existing getter renamed/changed | SAFE |
| main.dart (imageCache budget) | widget_test & pumpApp harness | harness pumps DailyMealApp directly, never main() → change unreachable from tests; runtime effect bounded (cache sizing only) | SAFE |
| storage.rules (+staging block) | none (rules not unit-tested in repo) | additive match block BEFORE the deny-all catch-all (order matters — verified); meal_images admin block untouched; BOM stripped (parser-friendly, no semantic change) | SAFE |
| cooldown_engine / recommendation_provider / vault header | recommendation_variety_test, vault_header_clip_test | NOT MODIFIED this mission (recon proved plan items already shipped) — included for completeness | SAFE |

## Key-contract audit (new keys cannot collide)
Static audit check #6 confirms meal_screen_*, meal_details_propose_button,
meal_details_fullscreen_button, quick_meal_view are unique across lib/.

## Behavioural traps checked by reading (not just grep)
- Favourite toggle from MealScreen goes through vaultControllerProvider (same
  notifier the vault cards use) → drift stream → pinned recommendation key is
  field-blind → home cards do NOT re-rank (the plan's core bug stays fixed even
  from the new surface).
- Delete from MealScreen → vaultController.deleteMeal → stream updates →
  screen pops (canPop-guarded) → eligibility key changes (mealIds) → home
  re-ranks correctly.
- Sheet fullscreen link captures GoRouter BEFORE popping (no deactivated-context
  navigation).
- Proposal flow in FLUTTER_TEST deterministically ends at the offline gate
  (ReachabilityService returns false under FLUTTER_TEST) → existing widget tests
  that might tap it can never hang on Firebase.

## VERDICT: CLEAN — no existing test requires modification; no finder, key, rect
measurement or pump entry point is disturbed by this mission's diff.
