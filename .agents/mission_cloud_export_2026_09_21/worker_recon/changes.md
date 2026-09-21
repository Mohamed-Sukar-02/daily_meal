# worker_recon — findings (no code changes)

## Already implemented (evidence)
1. **Cooldown engine shuffle layer** — `lib/features/home/domain/cooldown_engine.dart`
   - L308 `static const double _interchangeableBand = 5.0;` (score band = favourite bonus)
   - L343 `final draw = Random(daysSinceEpoch(today) + shuffleSeed * 7919);`
   - L344–356: per-meal lottery draw; sort by band first, lottery inside band, id as last
     tie-break → deterministic per day+seed, favourites can't monopolise, browsing never
     reshuffles. Matches plan intent ("shuffle/randomization layer for meals with close scores").
2. **Stateful recommendations cache** — `lib/features/home/providers/recommendation_provider.dart`
   - L47 `NotifierProvider<TodayRecommendationsNotifier, AsyncValue<RecommendationResult<Meal>>>`
   - L53–55 `_pinnedKey/_pinnedIds/_pinnedResult`; L112–127: same eligibility key →
     rebuild pinned meals from fresh rows (photo/name/heart updates show, order frozen).
   - `_eligibilityKey` (L21–44) is blind to favourite/field edits; includes dayEpoch,
     refreshSeed, sorted mealIds, historyLength, cooldown settings.
   - Covered by `test/unit/recommendation_variety_test.dart`.
3. **Vault header Row** — `lib/features/vault/presentation/meal_vault_screen.dart`
   - L319/L360: both local & explore counters are horizontal `Row`s
     (`vault_local_count_row`, `vault_explore_count_row`); L623 `toolbarHeight: 85`.
   - Covered by `test/widget/vault_header_clip_test.dart`.
4. **PopScope / unsaved-changes dialog** (plan's IMPORTANT note) —
   - `profile_edit_dialog.dart` L163 `PopScope`, L69 `showDiscardChangesDialog`
   - `quick_add_sheet.dart` L464 `PopScope`, L99 `showDiscardChangesDialog`
   - Shared widget: `lib/core/widgets/discard_changes_dialog.dart`. ✅ mark `[x]`, no changes.

## Genuinely missing (to build)
- `lib/features/vault/application/` — directory absent → `meal_proposal_service.dart` [NEW]
- `lib/features/meals/` — directory absent → `quick_meal_view.dart`, `meal_screen.dart` [NEW]
- `meal_details_sheet.dart` EXISTS (plan says [NEW]) → becomes [MODIFY]: add the Cloud
  Staging Export entry point (vault section). No test keys reference its internals
  (`grep -rn "meal_details" test/` → empty) so extending is regression-safe.
- `ISSUES.md` — absent → create (worker_backlog).
- Backend readiness: `firestore.rules` already validates `staging_meals` creates
  (`isValidStagingMeal`, status=='pending', proposedBy==auth.uid, allowedKeys WITHOUT
  `shortName`). `storage.rules` has NO user-writable path → needs scoped
  `staging_meal_images/{uid}` block (<500KB, image/*). `firebase_auth` is in pubspec but
  unused in lib/ → anonymous sign-in is the auth vehicle for proposals.

## Plan "Open Question" — answer from code
Refresh semantics already implemented: re-rank at midnight (dayEpoch), on explicit refresh
(refreshSeed), on meal add/delete, on history/settings change; NOT on like/edit.
This satisfies "cards don't shift on Like" while avoiding a stale list after deletions.
