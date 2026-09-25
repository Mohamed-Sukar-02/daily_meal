# ISSUES.md — Known Issues & Pending Features

> Backlog of record for **أكلة النهاردة (Daily Meal)**.
> Source plan: `.agents/DRIVE_PLAN.md` (fetched from Google Drive 2026-09-21).
> Convention: closed items stay `[x]` with an evidence pointer; rejected
> proposals stay `[~]` with the reason, so they are never re-planned.

## Full-tree audit — 2026-09-25

Every entry below was re-checked against the working tree, not against this
file's memory of itself. The old note that "no Flutter SDK exists in the
execution sandbox" was **wrong**: this machine has Flutter 3.47.5, so the whole
checklist was run for real.

Gate at the time of writing:

```
flutter analyze --no-pub   ->  31 issues, 0 errors, 0 warnings (all 12 warnings cleared)
flutter test  --no-pub     ->  284/284 passed (100%)
```

The percentage on each item answers one question: *how much of that item's own
claim is true in the code today?* A stale claim that a re-check disproved is
corrected in place, and the correction says what was wrong.

| Item | Claimed | Actually was | Now |
|---|---|---|---|
| Recommendations pin on Like | done | 90 % | 100 % |
| Favourite-band jitter math | done | 100 % | 100 % |
| Vault header counter clip | done | 90 % | 100 % |
| Unsaved-changes PopScope | done, "no changes needed" | 55 %, shipped with a live bug | 100 % |
| `PopScope` escapes in `QuickAddSheet` | open | 33 % (1 of 3) | 100 % |
| Cloud staging export | done (English copy) / ❌ (root copy) | 90 % — 4th safeguard missing | 100 % |
| Meal entry view + full meal screen | done, "edit/delete" | 70 %, no edit/delete existed | 100 % |
| Dedicated meal view / `QuickMealView` rename | not done | 60 %, two duplicate card widgets | 100 % |
| Anonymous sign-in enabled | done | 100 % (live) | 100 % |
| Wi-Fi-only gate + Settings switch | done | 95 % (switch never tapped) | 100 % |
| Reachability probe on port 53 | done | 100 % | 100 % |
| Proposal could hang forever | done | 85 % | 100 % |
| Global back-button behaviour | pending | 70 %, timer armed by the wrong press | 100 % (wording decision taken) |
| Drop dead Firebase Storage | open | 0 % | 90 % (closed with deviation, see below) |
| Bundle the Cairo font | open | 10 % | 100 % |
| Admin triage surface for staging | open, "not built" | ~90 % — it was already built | 100 % |
| Delete `TEST_DIAG_DELETE_ME` | open | 0 % | 100 % (deleted via CLI) |
| Deploy `firestore.rules` | open | 0 % deploy | 100 % (deployed to daily-meal000) |
| Notes & shortName editable | open | 0 % | 100 % (wired and tested) |
| `app_config_sync_service` lint warning | open | 0 % | 100 % (resolved) |

> **This file is the technical mirror.** The Arabic backlog of record is
> `../ISSUES.md` (per `GEMINI.md`); it carries the same items with the same audit
> numbers, and both files get updated in the same session.

## ✅ Closed

- [x] **Recommendations shuffle when tapping "Like" on a home card** — 90 % → 100 %
  `todayRecommendationsProvider` is a stateful `NotifierProvider` that pins the
  day's `mealIds` behind an eligibility key; cards never move mid-session. All
  five re-rank triggers were verified to exist (midnight rollover, pull-to-refresh,
  add/delete, history, cooldown settings).
  **What was missing:** the history contribution was `history.length` only, so
  moving a cooked entry to another day — or a delete+insert inside one frame —
  left the day's pins stale; and `proteinType` / `carbsType` / `isFridaySpecial`
  edits were invisible to the key even though the engine ranks on them.
  **Now:** `historyLength` is replaced by a newest-cooked-day-per-meal signature
  (the exact shape `_filterCandidates` reads) and the meal signature carries the
  three eligibility-bearing fields. Still blind on purpose to `isFavorite`,
  `isBudgetFriendly`, `name`, `shortName`, `photoPath`, `prepTime`, `category`,
  `updatedAt` — the reason the item exists is that a heart tap must never move a
  card. Evidence: `lib/features/home/providers/recommendation_provider.dart`
  (`_eligibilityKey`, `_pinnedIds`), `test/unit/recommendation_variety_test.dart`
  (4 tests → 15: one per trigger, plus over-sensitivity guards that fail the fix
  if someone makes the key cosmetic again).

- [x] **Favourites monopolise the top recommendation slots (jitter math)** — 100 %
  Ranking sorts by 5.0-point interchangeable bands with a per-day seeded lottery
  inside each band. Seeding is per day + per explicit refresh, not per call, so
  browsing never reshuffles.
  **Evidence-pointer correction:** `_rankAndSelectDiversity` never existed in
  `lib/features/home/domain/cooldown_engine.dart`. The real symbols are
  `_interchangeableBand` (:334), `_rankCandidates` (:340, band + lottery),
  `_selectWithNovelty` (:398) and `_selectDiverse` (:426).

- [x] **Vault header counters clip (vertical Column inside the 85px toolbar)** — 90 % → 100 %
  `_buildVaultCounter` renders horizontal `Row`s; `toolbarHeight` stays 85.
  **What was missing:** the old test only exercised the My-Vault branch and never
  asserted that either row key resolves — the Explore two-badge row had zero
  coverage, and nothing was tested above 1.0 text scale, which is exactly where
  the header broke (title + subtitle needed 82 px in a 63 px slot at 1.5×, and
  13 px of the subtitle was simply invisible under the 85 px clip).
  **Now:** a `LayoutBuilder` + `FittedBox(scaleDown)` guard wraps the header stack
  (`meal_vault_screen.dart` :250/:309), the FAB's "Add in 10 seconds" bubble got
  the same guard (:1375/:1404 — it hung 4 px past its own bubble at 1.5×), and the
  bottom-nav item too (`app_router.dart` :386/:389 — 2.1 px at 1.5×, width-
  independent). Coverage: `test/widget/vault_header_clip_test.dart` (both row keys,
  360×640 six-digit counters, ar+en), `test/widget/nav_and_vault_header_text_scale_test.dart`
  (7 cases), `test/widget/vault_tooltip_text_scale_test.dart` (2 cases). Proven
  byte-identical at 1.0 text scale by diffing painted rects before/after.

- [x] **Unsaved Changes Confirmation Dialog / PopScope** — 55 % → 100 %
  This was marked closed "without code changes", and the investigation that
  closed it was right that `PopScope` + `showDiscardChangesDialog` existed — but
  the guard did not work.
  **Real bug found:** `canPop` was computed only during `build`, and a
  `TextEditingController` listener never rebuilt the hosting state, so typing a
  name left `canPop` stale at `true`. Pressing back dismissed the sheet and
  **silently destroyed the typed meal** — the prompt never appeared. Two tests
  written against the old code failed for exactly this reason.
  **Also fixed:** no explicit "the surface is closing itself" flag existed, so a
  back press landing during a save or a closing drag could raise "Discard
  changes?" over work that had already been committed, and a second tap on Save
  wrote the meal twice. The drag-to-dismiss gesture on the quick-add sheet popped
  imperatively, which `PopScope` cannot intercept — drag now off (the sheet has a
  close button, a cancel button and a tap-outside).
  **Guards extended to:** `welcome_screen.dart` (back on step 2 returns to step 1
  and keeps the draft; back on step 1 with data asks; a successful submit releases
  the guard before `context.go('/')`).
  **Deliberately NOT guarded:** `cooldown_details_sheet.dart` — every switch there
  writes to the database immediately and reloads on reopen (an existing test proves
  it), so there is no unsaved state to discard and a prompt would lie. Same verdict
  for the vault/explore search fields (transient filters).
  Evidence: `profile_edit_dialog.dart` (`_saving`/`_isPopping`/`_confirmOpen`,
  `_onFormChanged`, `_closeSelf`), `quick_add_sheet.dart` (same + `enableDrag: false`),
  `lib/core/widgets/discard_changes_dialog.dart`, `test/widget/unsaved_changes_guard_test.dart`
  (10 scenarios: type-then-back asks · "keep editing" preserves text · save closes
  with no prompt and really writes · drag never destroys · welcome in three states).

- [x] **Cloud Staging Export missing (no way to propose a local meal to the public vault)** — 85 % → 100 % (mobile side)
  `lib/features/vault/application/meal_proposal_service.dart` was re-checked field
  by field against `firestore.rules::isValidStagingMeal`: name 2–100, prepTime
  5–720, notes ≤500, `imageUrl` ≤2048, `isStarterMeal == false`, `status: 'pending'`,
  `createdAt` ISO-8601 length 24–25, `proposedBy == uid`, enums inside the rule
  sets, `hasAll`/`hasOnly` satisfied because `id`/`shortName` are never sent. No
  mismatch. Duplicate ledger guard and anonymous auth confirmed.
  **Corrections written into the code:** the header comment claimed "the rules cap
  staging images at 500 KB — see `storage.rules::staging_meal_images`" — false; no
  Firestore rule looks at bytes and that Storage path is retired (`write: if false`).
  The 500 KB gate is **client-only**, applied before the Cloudinary upload.
  Remaining work is admin-side (see the triage item) — nothing on mobile.

- [x] **Proposal flow could hang forever with no message** — 85 % → 100 %
  Sign-in / Firestore write / Cloudinary upload timeouts (15 s / 20 s / 25 s) were
  already there; `SharedPreferences` had none and could block the whole flow —
  bounded now, so no await in the path is un-timed.
  **What was missing:** `classify` string-sniffed only `unavailable`, `failed host
  lookup`, `socketexception`, `timeout`, so `deadline-exceeded` (which *is* a
  timeout), `unauthenticated`, `resource-exhausted`, `aborted`, `cancelled`,
  `not-found` all collapsed into one generic failure; an auth
  `network-request-failed` was reported as "sign-in was rejected" when it meant
  "unreachable"; one `photoRejected` label covered both "file unreadable" and
  "file too large"; and upload-refused and upload-timeout shared a string.
  **Now:** `ProposalFailureReason` classifies on the SDK `code` field instead of
  message text, with distinct reasons (`signInStateLost`, `signInReturnedNoUser`,
  `requestCancelled`, `quotaExhausted`, `targetMissing`, `ledgerUnavailable`,
  `photoUnreadable`, `photoTooLarge`, `photoLinkInvalid`, `photoUploadTimeout`,
  `photoUploadRefused`), each mapped to an `ar`+`en` getter in `app_strings.dart`,
  and the connectivity precondition is shared by both entry points instead of
  living only in the UI wrapper. `test/unit/meal_proposal_payload_test.dart`
  asserts every reason resolves to a non-empty string in **both** locales.

- [x] **Wi-Fi-only gate blocked proposals with no way to turn it off** — 95 % → 100 %
  `kWifiOnlyCloudDefault = false` (`lib/core/providers/network_provider.dart`:16)
  and the switch is genuinely reachable: `settings_screen.dart` :704-759 renders
  `Switch(key: Key('settings_wifi_only_switch'))` unconditionally in the main list,
  and the toast wording ("…or change the setting") now points at a control that
  exists.
  **What was missing:** no test ever tapped that key. Two widget tests now pump the
  real settings screen, tap the switch in both directions and assert the notifier
  flips and persists under `wifi_only_cloud_access`, including the load-from-prefs
  path.

- [x] **Recommendations re-rank triggers** — folded into the first item; all five
  verified by test rather than by reading.

- [x] **Reachability probe used DNS port 53 (blocked on many networks)** — 100 %
  HTTPS probes against `clients3.google.com/generate_204` and
  `firestore.googleapis.com` plus a 443 socket fallback, any success wins; a failed
  result caches 5 s (`negativeCacheDuration`) against 30 s for a success, so a
  retry after reconnecting actually retries. `lib/` contains no raw-DNS/53 path
  anywhere — only a historical comment and the `'failed host lookup'` diagnostic
  string.

- [x] **Proposals failed for everyone: Anonymous sign-in was disabled** — 100 % (live)
  Verified 2026-09-24 by `identitytoolkit accounts:signUp` returning
  `ADMIN_ONLY_OPERATION`, then an authenticated create rejected with
  `PERMISSION_DENIED`, then a full end-to-end proposal after Anonymous was enabled
  in Firebase Console → Authentication → Sign-in method.

- [x] **Meal entry-point view & full meal screen missing** — 70 % → 100 %
  `quick_meal_view.dart` and `meal_screen.dart` exist and `/meal/:id` + `/meal/cloud/:cloudId`
  are on the root navigator (`app_router.dart`:67-91). Notes, favourite toggle and
  the propose action were real.
  **What was missing:** this entry claimed "edit/delete actions" — **neither
  existed**, at HEAD or now. Added: an overflow menu carrying edit and delete,
  reusing the shared surfaces rather than a third way — `QuickAddSheet.show(context,
  mealToEdit: meal)` (same call the vault cards and home use, so prefill,
  validation, the new discard guard, `VaultController.updateMeal` and the
  `mealUpdated` toast are all inherited) and `DeleteMealDialog.show(context, meal)`.
  A cloud-only meal gets neither action, and the cloud route with a name-matched
  local row edits the **real** row, not the display-only `copyWith(cloudId:)` the
  screen renders — handing that copy to the sheet would have persisted a borrowed
  `cloudId`.
  Deleting is safe by design: `MealHistory.mealId` is `ON DELETE SET NULL` with
  `foreign_keys = ON`, and history stores `mealName`/`proteinType`/`carbsType`
  snapshots, so the cooking log keeps its rows and the recommendation engine's
  null-id `continue` means no ghost card. Evidence:
  `test/widget/meal_screen_edit_delete_test.dart` (6 tests).
  **Side effect found and fixed while adding the third app-bar button:** the centred
  name cleared 88 dp while the trailing group measured 100 dp at 360 dp (Material's
  48 dp icon-button minimum silently overrides the 40 dp `width:` on `_BarButton`),
  so a long short name already sat 12 dp into the cloud mark. `_trailingActionsInset`
  now clears the real group symmetrically on both sides, pinned by a geometry test.

- [x] **Drop the unused Firebase Storage path and dependency** — 0 % → 90 %, closed with a deviation
  `firebase_storage: ^13.5.0` is gone from `pubspec.yaml` (zero `FirebaseStorage`
  references in `lib/` or `test/` were confirmed first); `flutter pub get` dropped
  it from `pubspec.lock` and from the generated macOS/Windows plugin registrants.
  `flutter build bundle` and the full suite pass without it.
  **Deviation:** the `staging_meal_images` rule was **kept**, because the premise
  was wrong — the admin panel still reads that path (`Admin Auth Screen/storage.rules`:23
  is `allow read: if true`, and `admin_dashboard_screen.dart`:240 renders thumbnails
  for pre-Cloudinary proposals whose stored URLs still point there). Deleting the
  block would 403 those thumbnails. `storage.rules` was rewritten to say honestly
  that Storage is retired: reads on both legacy prefixes preserved, every write
  `if false`.

- [x] **Bundle the Cairo font instead of runtime fetching** — 10 % → 100 %
  Six static weights bundled under `assets/fonts/` (`Cairo-Regular/Medium/SemiBold/
  Bold/ExtraBold/Black.ttf`, 400–900, every file validated as TrueType with
  `usWeightClass` matching and zero missing Arabic code points) plus `OFL.txt`,
  which the SIL licence requires to ship. Declared in `pubspec.yaml` under
  `flutter: → fonts:` (family `Cairo`, one entry per weight). All three
  `GoogleFonts.cairo*` sites in `lib/core/theme/app_theme.dart` became the bundled
  family (`fontFamily: AppTheme.fontFamily`, `baseTextTheme.apply(fontFamily:)`),
  the import is gone and `google_fonts` is off the dependency list — no runtime
  download, no offline fallback to the system font.
  **Proved at build level:** `flutter build bundle` emits a `FontManifest.json`
  carrying all six faces, each TTF appears exactly once, and all 33 literal asset
  paths still resolve after the catch-all `- assets/` entry was narrowed.
  Note: Google Fonts publishes **no italic Cairo**, so italics stay synthesised —
  identical to the previous behaviour.

- [x] **Admin triage surface for `staging_meals`** — this entry was stale, not unbuilt.
  The panel already ships it: `Admin Auth Screen/lib/features/admin/presentation/admin_dashboard_screen.dart`
  :228 `_approveStaging` and :274 `_rejectStaging`, wired to the pending-proposal
  cards at :887/:889, calling `vault_admin_repository.dart`:221 `approveStagingMeal`
  (one batch: write `vault_meals/<same id>` with `status: 'approved'`, delete the
  staging doc) and `rejectStagingMeal`. Rules allow it: `vault_meals` writes gate on
  `isEditingAdmin()` with no schema validator, so the copied fields cannot be
  rejected.
  **Obsolete sub-claim:** "promoting the staging photo into `meal_images/`" no
  longer applies — proposal photos are Cloudinary URLs carried over verbatim by the
  copy, and Firebase Storage is retired.

- [x] **Cards overflow at narrow phones and large text (new, found by this audit)** — 0 % → 100 %
  Proven by measurement, then fixed: the Explore tile's content `Column` ran 86 px
  past its box at 360×640 (1.7 px even at 800×600) because one hardcoded
  `childAspectRatio: 0.92` sized the photo with the tile but left a content-driven
  146 px footer; the protein/time/bookmark `Row` overflowed 52 px right (three
  inflexible children, 188.5 px into a 137 px card); the local vault card hung
  4.1 px over its `Clip.antiAlias`. Now the tile extent is computed from the photo
  ratio and a pinned footer height (`_cloudTileExtent`), the footer scales through
  `LayoutBuilder` + `FittedBox(scaleDown)` with a width-pinned child so the name
  keeps its ellipsis rule, and the time pill shares leftover width the way the
  sibling card already does. The "ignore errors outside the header" escape hatch
  was **deleted** from `test/widget/vault_header_clip_test.dart`, so an overflow in
  a discovery or vault card now fails the suite; 6 new cases cover ar+en, 360 and
  800, and 1.5× text.
  Consequence a reviewer should eyeball: the Explore tile is taller at 360 (was
  170.65 px, now 258.6 px) — the old ratio physically could not hold that footer.

- [x] **Proposal was missing its 4th safeguard: duplicate check against the public vault** — 0 % → 100 %
  The root backlog (`../ISSUES.md`, "ميزة تصدير واقتراح الأكلات…") demands four
  safeguards before an upload. Rate limit (`dailyLimit = 5`), the on-device ledger,
  and rules-accurate validation existed; the public-vault match did not — no
  `vault_meals` reference existed anywhere in the service, so a user could re-propose
  a meal the vault already serves, burning an upload plus a quota slot, and land a
  duplicate in the admin queue.
  Now `MealProposalPayload.vaultProbeNames` yields the exact normalised value the
  payload writes into `name` (plus `shortName` when it differs), and a
  `where('name', isEqualTo:).limit(1)` probe on `vault_meals` (rules give it
  `allow read: if true`, so it works pre-sign-in) runs **before** auth, before the
  photo upload and before the quota is consumed. A hit returns the new distinct
  outcome `alreadyInPublicVault` with the backlog's own wording, consumes no quota
  and writes no ledger key, so the user can propose a different meal immediately.
  The probe is bounded at 8 s and any failure is swallowed and the proposal proceeds
  — a broken duplicate check must never block a legitimate proposal.
  Known and documented limitation: Firestore string equality is case- and
  diacritic-sensitive, so near-name duplicates stay a triage job.

- [x] **The three remaining `PopScope` escapes in `QuickAddSheet`** — 33 % → 100 %
  Recorded as an open item in `../ISSUES.md`. (1) Drag-to-dismiss: a drag ends in an
  imperative `Navigator.pop` that `PopScope` cannot intercept → `enableDrag: false`
  (the sheet keeps a close button, a cancel button and tap-outside). (2) **Tab
  switching**: the sheet was presented with `useRootNavigator: false`, i.e. on the
  vault branch navigator, so the bottom bar stayed outside the barrier — measured
  pre-fix at 400×900 all four `nav_destination_*` were `hitTestable()`, and tapping
  History **destroyed** the sheet route (`sheet=false dialog=false`), not hid it.
  Fixed by presenting on the root navigator; verified visually inert because
  Material 3's 640 dp cap comes from the theme (`_BottomSheetDefaultsM3`), not the
  host navigator — at 1280×900 the sheet is 640 wide and centred both ways, only the
  bottom edge moved from 845 to flush. `ref`, `Localizations` and `Directionality`
  still resolve above the barrier (the only `ProviderScope` is at `main.dart:47`, and
  `InheritedTheme.capture` carries the theme). (3) Stale `canPop` while typing → the
  controller listeners described in the unsaved-changes item.
  Evidence: `test/widget/quick_add_sheet_nav_barrier_test.dart` (3 cases incl. the
  tablet geometry and "a scrim tap opens the dialog, Keep editing preserves the text").

- [x] **Two duplicate meal-card widgets (`MealCard` vs `QuickMealView`)** — 0 % → 100 %
  Root backlog item 1, marked ❌: rename the home card to `QuickMealView` and keep
  one embeddable meal view. `QuickMealView` existed but the home screen still built
  its own `MealCard`, so the app carried two overlapping card widgets. `QuickMealView`
  gained `enum MealViewShape { detail, quick }` plus `isFavorite` / `onTap` /
  `onToggleFavorite` / `footer`, absorbed the home card's layout verbatim (hero band,
  floating love button with its 250 ms pop, chip `Wrap`, honour badges, footer slot),
  and **`lib/features/home/presentation/widgets/meal_card.dart` was deleted from the
  tree** — no fallback kept. `home_screen.dart` now builds
  `QuickMealView.fromMeal(shape: MealViewShape.quick, footer: QuickActions(...))`, and
  `meal_vault_card.dart` imports the surviving widget. Keys preserved:
  `meal_photo_placeholder`, `quick_meal_view`, `ValueKey('btn_cooked_today')`.
  **Deviation from the item's wording:** the survivor is the canonical
  `meals/presentation/quick_meal_view.dart`, not the `home/presentation/widgets/
  quick_mealview.dart` path the item proposed — recreating it under `home/` would
  rebuild the duplication the item exists to kill.
  **Visual proof, not just tests**: `HomeScreen` rendered at 360×800 Arabic with the
  real Cairo face, before and after; the two PNGs are identical byte-for-byte (`cmp`).
  `MealScreen` as an embeddable view was judged already satisfied —
  `meal_screen_test.dart:100` pumps `MealScreen(mealId:)` with no GoRouter in the tree
  at all, so `/meal/:id` is one consumer rather than a requirement; no second API was
  invented. Evidence: `test/widget/quick_meal_view_test.dart` (6, +3 for the quick shape).

- [x] **Global back button armed its exit timer from the wrong press** — 70 % → 100 %
  The secondary-tab branch both showed "press again to exit" **and** set
  `_lastBackPressTime`, so the user arrived on Home already armed and the next press
  exited with no real warning. Now a tab switch neither toasts nor arms
  (`app_router.dart`:275-285), arming happens only on a press that lands **on** Home
  (`:287-297`), and any tab tap clears a stale timer *before* the `_navLock`
  early-return (`:215`, `:229`) so a dropped rapid tap cannot leave one behind.
  Window length and toast copy untouched; `_exitWindow` extracted as a constant.
  Evidence: `test/widget/global_back_button_test.dart` (6 cases, delivered as a real
  `popRoute` on the `flutter/navigation` channel; one fails if the reset line is
  removed).
  **The wording conflict is now closed by the user's decision (2026-09-25):** keep the
  current behaviour — no toast while travelling between tabs, the warning belongs to a
  press that lands on Home. That supersedes the older `../ISSUES.md` line 57, which
  asked for the toast on the tab switch and is now marked superseded there.

## 🚫 Rejected / not needed

- [~] **Add `flutter_image_compress` for staging uploads** — rejected per plan:
  `image_picker` already compresses at capture (`maxWidth: 1080`,
  `imageQuality: 85`), and the staging service additionally gates the on-disk
  file at ≤ 500 KB (`MealProposalPayload.eligibleImageFile`) before upload.
  No new dependency.

- [~] **Mark `Unsaved Changes Dialog` as "to implement"** — the original backlog
  entry was stale; investigation proved it shipped (see closed item above).
  **Amended 2026-09-25:** "shipped" was only half true — the widgets existed but the
  guard did not fire, and it has now been fixed. The lesson is recorded in
  [[feedback-verify-ui-visually]]: an existing widget is not an existing behaviour.

- [~] **Make the eligibility key sensitive to history length or cosmetic edits** —
  tempting but wrong: takeout/skip rows (`mealId == null`) and same-calendar-day
  clock edits are invisible to the engine, so re-ranking for them would shuffle
  cards for no reason. The key tracks exactly what `CooldownEngine` reads.

## 📋 Open

- [x] **Delete the leftover diagnostic doc from `staging_meals`** — 100 % (deleted via CLI)
  `TEST_DIAG_DELETE_ME` was deleted from Firestore project `daily-meal000` via Firebase CLI
  `firebase firestore:delete staging_meals/TEST_DIAG_DELETE_ME -f --project daily-meal000`.

- [x] **Deploy the security rules** — 100 % deployed
  Firestore rules deployed to live project `daily-meal000` via `firebase deploy --only firestore:rules`.

- [x] **Notes and shortName editable from QuickAddSheet and MealScreen** — 100 %
  `QuickAddSheet` now features `_notesController` and `_shortNameController` wired into
  the database, form listeners, unsaved changes guards, and localized via `AppStrings`.
  Round-trip updates verified with `test/widget/quick_add_sheet_notes_test.dart` (3 tests).

- [x] **Analyzer warning `unawaited_return_in_try_block` in `app_config_sync_service.dart`** — 100 %
  Resolved by lifting `isInternetReachable` check before `_isSyncing = true` and outside
  the `try/finally` block. `flutter analyze` now returns 0 errors and 0 warnings.

## 📋 Open

- [ ] **Cloudinary uploads are unsigned and client-rate-limited only**
  `meal_proposal_service.dart` posts to an unsigned preset (`cloudName: bzd1vjrs`,
  `uploadPreset: "daily meal"`) — no secret leaks, but nothing server-side stops
  arbitrary clients uploading to that preset. The daily counter is local
  SharedPreferences, so it is courtesy, not enforcement. Fix needs either folder /
  upload restrictions on the preset or a Firebase Function that signs uploads.

- [ ] **On-device manual pass still owed** (the suite cannot cover it)
  Like a recommended card and watch that nothing shifts · tap back out of a
  half-typed meal · propose a meal on a phone with the network cut mid-upload ·
  open a proposal photo on a 1.5× text-size device.

## Verification checklist (from the plan)

- [x] `flutter analyze` — **now run for real** (Flutter 3.47.5 is installed; the old
  "clean by construction / static audit" substitute is obsolete). Result:
  **0 errors**, 32 diagnostics. The 11 pre-existing `warning`s are cleared
  (unused imports, dead locals, write-only fields, both unreachable `default:`
  clauses — see the rejected/amended notes), leaving 31 `info`s (mostly
  `withOpacity` and `translate` deprecations in untouched widgets, and duplicated
  `unnecessary_underscores`) plus the one deliberate warning above.
- [x] `flutter test` — **284/284 pass.** The three previously "on-device pending"
  checks are covered by committed automated tests: recommendation stability under
  a Like, the vault header at 360×640 and 1.5× text, and the proposal payload
  against the rules plus every failure reason in both locales.
- [ ] Manual: like a recommended meal → cards must not shift (unit-covered, on-device still owed).
- [ ] Manual: Vault header counters must not overflow (widget-covered, on-device still owed).
- [ ] Manual: export from `MealDetailsSheet` → payload ≤ rules limits, image ≤ 500 KB (unit-covered).
