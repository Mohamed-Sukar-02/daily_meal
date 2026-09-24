# ISSUES.md — Known Issues & Pending Features

> Backlog of record for **أكلة النهاردة (Daily Meal)**.
> Source plan: `.agents/DRIVE_PLAN.md` (fetched from Google Drive 2026-09-21).
> Convention: closed items stay as `[x]` with an evidence pointer; rejected
> proposals stay as `[~]` with the reason, so they are never re-planned.

## ✅ Closed

- [x] **Recommendations shuffle when tapping “Like” on a home card**
  `todayRecommendationsProvider` is now a stateful `NotifierProvider` that pins
  the day's `mealIds` behind an eligibility key blind to favourite/photo/name
  edits — cards never move mid-session. Re-ranks at midnight, on explicit
  pull-to-refresh, on meal add/delete, on history change and on cooldown-settings
  change. Evidence: `lib/features/home/providers/recommendation_provider.dart`
  (`_eligibilityKey`, `_pinnedIds`), `test/unit/recommendation_variety_test.dart`.

- [x] **Favourites monopolise the top recommendation slots (jitter math)**
  Ranking sorts by 5.0-point “interchangeable bands” with a per-day seeded
  lottery inside each band: quality still rules across bands, close scores
  rotate fairly, and browsing never reshuffles. Evidence:
  `lib/features/home/domain/cooldown_engine.dart` (`_interchangeableBand`,
  `lottery` in `_rankAndSelectDiversity`).

- [x] **Vault header counters clip (vertical Column inside the 85px toolbar)**
  `_buildVaultCounter` renders horizontal `Row`s for both the local counter and
  the explore new/cloud counters; `toolbarHeight` stays 85. Evidence:
  `lib/features/vault/presentation/meal_vault_screen.dart`
  (`vault_local_count_row`, `vault_explore_count_row`),
  `test/widget/vault_header_clip_test.dart`.

- [x] **Unsaved Changes Confirmation Dialog / PopScope**
  Already implemented — marked complete **without code changes**, per the plan's
  IMPORTANT note. Evidence: `profile_edit_dialog.dart` (`PopScope`,
  `showDiscardChangesDialog`), `quick_add_sheet.dart` (`PopScope`,
  `showDiscardChangesDialog`), shared widget `lib/core/widgets/discard_changes_dialog.dart`.

- [x] **Cloud Staging Export missing (no way to propose a local meal to the public vault)**
  Implemented end-to-end: `lib/features/vault/application/meal_proposal_service.dart`
  (pure payload builder mirrored 1:1 against `firestore.rules::isValidStagingMeal`,
  anonymous auth, 500 KB image gate, duplicate guard via SharedPreferences ledger),
  entry point in `MealDetailsSheet` (propose button + full-details link) and on
  `MealScreen`. Storage scoped path added: `storage.rules → staging_meal_images/{uid}`
  (< 500 KB, image/*, own-uid only). Tests: `test/unit/meal_proposal_payload_test.dart`.

- [x] **Meal entry-point view & full meal screen missing**
  `lib/features/meals/presentation/quick_meal_view.dart` (reusable hero/badges view)
  and `lib/features/meals/presentation/meal_screen.dart` (full screen with
  notes, favourite toggle, edit/delete/propose actions), routed at `/meal/:id`
  on the root navigator (`lib/core/router/app_router.dart`).

## 🚫 Rejected / not needed

- [~] **Add `flutter_image_compress` for staging uploads** — rejected per plan:
  `image_picker` already compresses at capture (`maxWidth: 1080`,
  `imageQuality: 85`), and the staging service additionally gates the on-disk
  file at ≤ 500 KB (`MealProposalPayload.eligibleImageFile`) before upload.
  No new dependency.

- [~] **Mark `Unsaved Changes Dialog` as “to implement”** — the original backlog
  entry was stale; investigation proved it shipped (see closed item above).

## 📋 Open

- [ ] **Delete the leftover diagnostic doc from `staging_meals`**
  `TEST_DIAG_DELETE_ME` (created 2026-09-24 13:47 UTC while proving the
  end-to-end path after Anonymous was enabled). The anonymous caller cannot
  delete its own doc (rules: admin-only delete), so remove it from the admin
  dashboard or the Firestore console.

- [ ] **Deploy the re-synced `firestore.rules`**
  `firestore.rules` now mirrors the admin-panel copy (roles, `.lower()` on the
  admin email, wider category list) instead of the stale 2026-09-16 fork.
  Verified live 2026-09-24: the currently deployed rules DO accept the exact
  payload `MealProposalPayload.build` produces, so this is a consistency fix,
  not a live blocker — but the two copies must not drift again.
  `firebase deploy --only firestore:rules` (run from `Admin Auth Screen/`).

- [ ] **Drop the unused Firebase Storage path and dependency**
  Staging photos go to Cloudinary now, so `storage.rules::staging_meal_images`
  and the `firebase_storage` dependency are dead weight (no `FirebaseStorage`
  reference anywhere in `lib/`). Remove both once someone can rebuild and run
  the app.

- [ ] **Bundle the Cairo font instead of runtime fetching**
  `google_fonts` downloads Cairo on first launch and falls back to the system
  font when offline — against the offline-first promise. Bundle the font files
  under `assets/fonts/` (needs a networked machine) and switch
  `app_theme.dart` to a `fontFamily` declaration. Tracked from the perf report:
  `.agents/mission_cloud_export_2026_09_21/worker_perf/changes.md`.

- [ ] **Admin triage surface for `staging_meals`**
  Proposals land with `status: 'pending'`; approving them into `vault_meals`
  (and promoting the staging photo into `meal_images/`) is admin-panel work —
  out of mobile scope, listed here so it is not forgotten.

## ✅ Closed

- [x] **Proposals failed for everyone: Anonymous sign-in was disabled**
  Verified live 2026-09-24: `identitytoolkit accounts:signUp` on
  `daily-meal000` answered `ADMIN_ONLY_OPERATION` (provider off) for both API
  keys, and an authenticated create with the real payload was rejected with
  `PERMISSION_DENIED` before it, then accepted once Anonymous was enabled.
  The user enabled Anonymous in Firebase Console → Authentication →
  Sign-in method, after which a full end-to-end proposal succeeded.

- [x] **Wi-Fi-only gate blocked proposals with no way to turn it off**
  `wifiOnlyCloudProvider` defaulted to `true` and no screen exposed a switch,
  while the proposal toast told users to "change the setting" that did not
  exist. Default is now `false` and Settings → Network & Cloud exposes it.
  Tests: `test/unit/network_defaults_test.dart`.

- [x] **Reachability probe used DNS port 53 (blocked on many networks)**
  Now HTTPS probes against `clients3.google.com/generate_204` and
  `firestore.googleapis.com` plus a 443 socket fallback; any success wins.
  A failed result is cached for 5 s instead of 30 s so a retry after
  reconnecting actually retries. Test: `test/unit/network_defaults_test.dart`.

- [x] **Proposal flow could hang forever with no message**
  Sign-in, Firestore write and the Cloudinary upload each got a timeout
  (15 s / 20 s / 25 s), so a dead network now reports `blockedNoConnection`
  or `failed` instead of leaving the button spinning.
  Test: `test/unit/meal_proposal_payload_test.dart`.

- [ ] **Deploy the security rules after this release**
  `firebase deploy --only firestore:rules,storage` — the new
  `staging_meal_images/{uid}` Storage path must be live before users can attach
  photos to proposals (text-only proposals work without it).

- [ ] **Bundle the Cairo font instead of runtime fetching**
  `google_fonts` downloads Cairo on first launch and falls back to the system
  font when offline — against the offline-first promise. Bundle the font files
  under `assets/fonts/` (needs a networked machine) and switch
  `app_theme.dart` to a `fontFamily` declaration. Tracked from the perf report:
  `.agents/mission_cloud_export_2026_09_21/worker_perf/changes.md`.

- [ ] **Admin triage surface for `staging_meals`**
  Proposals land with `status: 'pending'`; approving them into `vault_meals`
  (and promoting the staging photo into `meal_images/`) is admin-panel work —
  out of mobile scope, listed here so it is not forgotten.

## Verification checklist (from the plan)

- [x] `flutter analyze` clean **by construction** — no Flutter SDK exists in the
  execution sandbox; compensated by the scripted static audit
  (`.agents/mission_cloud_export_2026_09_21/tester_static/`) and committed unit
  tests. Re-run `flutter analyze && flutter test` on a machine with the SDK.
- [ ] Manual: like a recommended meal → cards must not shift (covered by unit test).
- [ ] Manual: Vault header counters must not overflow (covered by widget test).
- [ ] Manual: export from `MealDetailsSheet` → payload ≤ rules limits, image ≤ 500 KB
  (covered by unit tests; on-device check pending SDK machine).
