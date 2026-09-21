# MANAGER PLAN — Cloud Staging Export & Drive-Plan Execution

## Work breakdown (dispatch order)

### W1. worker_recon — verify the "already done" plan items
Evidence required for:
1. `cooldown_engine.dart::_rankAndSelectDiversity` — seeded lottery inside a 5.0 interchangeable
   score band (favourites no longer monopolise; stable per day+seed).
2. `recommendation_provider.dart` — `todayRecommendationsProvider` is a stateful
   `NotifierProvider` pinning `mealIds` (`_pinnedIds`) behind `_eligibilityKey`.
3. `meal_vault_screen.dart::_buildVaultCounter` — horizontal `Row` layout, `toolbarHeight: 85`.
4. PopScope / unsaved-changes dialog present in `profile_edit_dialog.dart` + `quick_add_sheet.dart`.
Output: `changes.md` (findings w/ line refs), `handoff.md`.

### W2. worker_cloud — the missing feature work (core of the mission)
1. [NEW] `lib/features/vault/application/meal_proposal_service.dart`
   - Pure, testable payload builder `buildStagingPayload(Meal, {uid, now})` producing ONLY the
     keys allowed by `firestore.rules::isValidStagingMeal` (note: `shortName` is NOT allowed).
   - Enum bridges local→cloud: ProteinType→{chicken,beef,fish,meatless,other},
     CarbsType→{rice,pasta,bread,none}, MealCategory→{tabeekh,casserole,dry_sandwich,popular,seafood}.
   - Clamps: name 2..100 (local allows 1..120), prepTime 5..720, notes ≤ 500.
   - Image: reuse `image_picker`-compressed photo on disk; upload ONLY if file ≤ 500 KB
     (native enforcement, no new deps — mirrors the plan's <500KB rule); path
     `staging_meal_images/{uid}/{ts}.jpg`; download URL goes to `imageUrl`.
   - Auth: `firebase_auth` (already a dependency, currently unused) → anonymous sign-in when
     `currentUser == null` so Firestore `isAuthenticated()` passes.
   - Duplicate guard via `shared_preferences`: remember `mealId → updatedAtMs` at submit time;
     re-proposal allowed only after the meal is edited (updatedAt newer).
   - Injectable deps (`firestore/storage/auth/prefs`) so unit tests never touch Firebase.
2. [NEW] `lib/features/meals/presentation/quick_meal_view.dart`
   - `QuickMealView`: reusable entry-point view (hero photo, name, badge wrap) normalised from
     `Meal` via `QuickMealView.fromMeal`; used by MealScreen (keeps one visual vocabulary).
3. [NEW] `lib/features/meals/presentation/meal_screen.dart`
   - Full meal screen at root route `/meal/:id` (`parentNavigatorKey: rootNavigatorKey`),
     resolving the meal from `allMealsProvider` (deep-link safe) — QuickMealView + notes +
     actions: Edit (QuickAddSheet), Delete (DeleteMealDialog), Propose-to-cloud.
4. [MODIFY] `lib/features/vault/presentation/widgets/meal_details_sheet.dart`
   - Vault section gains the Cloud Staging Export entry point: propose button (spinner while
     in-flight, key `meal_details_propose_button`) + full-details link (key
     `meal_details_fullscreen_button`) → `/meal/:id`. Existing Edit/Delete row, keys and
     layout untouched (regression-safe).
5. [MODIFY] `lib/core/router/app_router.dart` — register `/meal/:id`.
6. [MODIFY] `lib/core/widgets/app_icons.dart` — new `AppGlyph.cloudUp` (mirror of cloudDown).
7. [MODIFY] `lib/core/localization/app_strings.dart` — proposal/full-details strings (ar+en).
8. [MODIFY] `storage.rules` — scoped `staging_meal_images/{uid}/{file}` write: same uid,
   `< 500 KB`, `image/*` only. Admin `meal_images` block unchanged.

### W3. worker_perf — performance pass (zero-risk budget)
1. `main.dart`: raise `imageCache` budget (1000 images / 200 MB) — photo-heavy app, default
   100 MB cache causes re-decodes when scrolling the vault.
2. `RepaintBoundary` isolation for the vault card grid items and home card stack (cheap, safe).
3. const-correctness in all new widgets; no rebuild-on-favourite (already pinned upstream).
4. Report: what was measured/reasoned, what was deliberately NOT done and why (runtime font
   fetching, asset bundling) — no speculative micro-edits without a test runner.

### W4. worker_backlog — ISSUES.md
Create `ISSUES.md` (repo root) as the backlog of record: plan items with `[x]` states,
including "Unsaved Changes Confirmation Dialog / PopScope" `[x]` per the plan's IMPORTANT note,
plus the open-question resolution and verification checklist.

### T1. tester_unit — new tests (committed, run by CI/local Flutter)
`test/unit/meal_proposal_payload_test.dart`:
- payload key-set parity with firestore rules (required ⊆ keys ⊆ allowed; no `shortName`)
- every ProteinType/CarbsType/MealCategory maps into the cloud vocabularies
- clamps (name <2 → failure; name >100 → truncated; prepTime bounds; notes ≤500)
- createdAt ISO-8601 string 10..40 chars; status == 'pending'; isStarterMeal == false
- duplicate guard semantics with mocked SharedPreferences (propose → blocked; edit → allowed)
- image-size gate: >500KB skips upload (pure helper, no Firebase)

### T2. tester_static — analyze-substitute audit (sandbox has no Flutter SDK)
Scripted + manual: import resolution for every touched file, symbol existence
(AppGlyph.cloudUp, all new AppStrings getters, route name), brace/paren balance,
rules-vs-payload field-by-field parity, key uniqueness (`meal_details_*`).

### T3. tester_regression — protect the existing suite
Map all 16 existing test files to touched files; assert no test-referenced Key/finder/string
is removed or renamed; confirm sheet edit/delete buttons and vault header keys survive.

## Integration & gate
Manager reviews each handoff before the next dispatch; final gate = all three tester reports
GREEN → commit → push `arena/01a0c2e2-daily-meal` → PR → merge into `main` (user request).
