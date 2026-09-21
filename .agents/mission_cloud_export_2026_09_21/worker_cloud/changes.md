# worker_cloud — changes

## NEW lib/features/vault/application/meal_proposal_service.dart
- `MealCloudVocabulary`: total mappings local→cloud for ProteinType/CarbsType/MealCategory
  (every enum value lands inside the rules' allowed sets; round-trip identities preserved
  against DiscoveryNotifier's download mappings: chicken/beef/fish identity, legume↔meatless,
  tabeekh/casserole/dry_sandwich/seafood identity; dairy→other, potato/grains→none,
  soupStew→tabeekh, vegetarian→popular documented as lossy folds).
- `MealProposalPayload.build(...)`: PURE payload builder; key-set exactly the rules allow-list
  (never `shortName`, never `id`); clamps name→100 / prepTime→5..720 / notes→500; forces
  `status:'pending'`, `isStarterMeal:false`, `createdAt` = UTC ISO-8601 (24 chars ∈ 10..40);
  returns null for names <2 chars (fail-fast, no rejected round-trip).
- `MealProposalPayload.eligibleImageFile(...)`: PURE ≤500KB disk gate (image_picker already
  compresses at capture: maxWidth 1080 / quality 85 → no flutter_image_compress, per plan).
- `ProposalGuard`: SharedPreferences ledger mealId→updatedAt-ms; blocks accidental re-sends,
  re-opens after edits; corrupt ledger degrades to empty (never throws).
- `MealProposalService.proposeMeal`: guard → anonymous sign-in (firebase_auth was an unused
  dependency; rules require request.auth for staging creates) → remote photo passthrough
  (≤2048 chars) or ≤500KB upload to `staging_meal_images/{uid}/{ts}.jpg` → Firestore
  `staging_meals.add(payload)` → mark ledger. Photo failures degrade to text-only proposal;
  hard failures return `ProposalOutcome.failed(cause)` — errors never escape as exceptions.
- Riverpod: `mealProposalServiceProvider`, `activeProposalMealIdProvider` (one spinner,
  shared across surfaces), `runProposalFlow(context, ref, meal)` = Wi-Fi-only/offline gate via
  `cloudAccessStatusFutureProvider` (same policy as discovery, real reachability probe; in
  FLUTTER_TEST it deterministically reports offline → Firebase is never touched in tests) +
  localised toasts via `showProposalOutcomeToast` (copy from AppStrings only).

## NEW lib/features/meals/presentation/quick_meal_view.dart
- `QuickMealView` entry-point view: hero photo (MealImage + cacheWidth), name, badge wrap
  (protein/carbs/prep/budget/category/friday) — one visual vocabulary; `QuickMealView.fromMeal`
  normalises a drift `Meal`. Pure presentation (no providers, no Firebase, no literals).
- Pill/protein-style helpers deliberately mirror MealDetailsSheet's private builders instead
  of refactoring the sheet (existing widget tests exercise the sheet → zero-risk choice).

## NEW lib/features/meals/presentation/meal_screen.dart
- Full meal screen keyed `meal_screen`; resolves meal reactively by id from `allMealsProvider`
  (deep-link + edit/delete elsewhere safe); states: loading / error / not-found (`meal_screen_not_found`).
- Body: QuickMealView (260h hero, cacheWidth 900) → notes card → PROPOSE button
  (`meal_screen_propose_button`, spinner via activeProposalMealIdProvider) → Edit
  (QuickAddSheet) / Delete (DeleteMealDialog → pop on success) row. AppBar favourite heart
  (`meal_screen_favorite_button`) writes via vaultControllerProvider.toggleFavorite — the
  pinned eligibility key is blind to the favourite flag, so home cards never re-rank.

## MODIFY lib/features/vault/presentation/widgets/meal_details_sheet.dart
- Vault section = Column[ legacy Row(edit, delete) UNCHANGED incl. keys,
  new Row(`meal_details_propose_button` [cloudUp glyph, green outline, spinner while
  proposing], `meal_details_fullscreen_button` [pop sheet → router.push('/meal/{id}') —
  router captured BEFORE pop so navigation never uses a deactivated context]) ].
- History/explore contexts untouched. New imports: go_router, meal_proposal_service.

## MODIFY lib/core/router/app_router.dart
- Root-level `GoRoute /meal/:id` (name 'meal', parentNavigatorKey: rootNavigatorKey →
  renders above the tab shell), int.tryParse-safe param (bad ids → not-found state).

## MODIFY lib/core/widgets/app_icons.dart
- `AppGlyph.cloudUp` + painter case: same cloud outline as cloudDown, arrow flipped up.

## MODIFY lib/core/localization/app_strings.dart
- Added: mealDetailsTitle, mealNotFound, fullDetails, notesLabel, proposalCta,
  proposalInProgress, proposalSuccess, proposalAlready, proposalInvalidName,
  proposalOffline, proposalWifiOnly, proposalFailed (ar + en, no literals in widgets).

## MODIFY storage.rules
- NEW scoped block `staging_meal_images/{uid}/{fileName}`: read public, write requires
  auth.uid == uid && size < 500*1024 && contentType image/* (mirrors the client gate).
  Admin `meal_images` block untouched.
