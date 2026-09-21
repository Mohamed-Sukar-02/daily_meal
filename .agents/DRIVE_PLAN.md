# Implementation Plan: Daily Meal Issues Resolution
> Source: https://drive.google.com/file/d/1Fn3MrCMkXDY9fFmcKSB-or9hs-fd31Lh/view
> Fetched verbatim: 2026-09-21

## Goal Description
Resolve all open bugs and pending features listed in `ISSUES.md`. The focus is on fixing the recommendation engine state, fixing the Vault UI header, correctly implementing the Cloud Staging Export, and updating the backlog.

## User Review Required
> [!IMPORTANT]
> The original `ISSUES.md` states that the `Unsaved Changes Dialog / PopScope` is not implemented. Our investigation confirms it **is already implemented** in `profile_edit_dialog.dart` and `quick_add_sheet.dart`. We will mark this as complete without making code changes.
>
> Additionally, we will **not** add the `flutter_image_compress` package as previously suggested in older plans. The application already handles image compression efficiently using the native `image_picker` parameters (`maxWidth: 1080`, `imageQuality: 85`).

## Open Questions
- **Re-ranking State Management**: To solve the issue where clicking "Like" changes the recommended meals, we will cache the daily meal IDs in `todayRecommendationsProvider`. Is it acceptable if the recommendations only refresh at midnight or when explicitly requested, even if a meal is deleted from the global list?

## Proposed Changes

### Recommendation Engine Fixes
Fix the jitter math so favorites don't monopolize the top slots, and stop recommendations from shifting upon liking a meal.

#### [MODIFY] `app_v2/lib/features/home/domain/cooldown_engine.dart`
- Update `_rankAndSelectDiversity` to sort meals not just strictly by score, but by introducing a shuffle/randomization layer for meals with close scores.

#### [MODIFY] `app_v2/lib/features/home/providers/recommendation_provider.dart`
- Convert `todayRecommendationsProvider` from a simple mapped provider to a stateful `Notifier`. It will cache the list of selected `mealIds` so that subsequent updates from `allMealsProvider` (like adding a favorite) do not trigger a full `engine.compute()` recalculation.

---

### UI and Layout Fixes
Fix Vault header clipping.

#### [MODIFY] `app_v2/lib/features/vault/presentation/meal_vault_screen.dart`
- Refactor `_buildVaultCounter`. Change the vertical `Column` holding the local vault counter and sync icon into a horizontal `Row`.
- This ensures consistency with `newCount` and `cloudCount` and prevents UI clipping while keeping `toolbarHeight` at 85.

---

### Cloud Staging & View Navigation
Implement missing screens and the cloud upload service.

#### [NEW] `app_v2/lib/features/meals/presentation/quick_meal_view.dart`
- Create entry point view for meals.

#### [NEW] `app_v2/lib/features/meals/presentation/meal_screen.dart`
- Create the full meal screen UI.

#### [NEW] `app_v2/lib/features/vault/presentation/widgets/meal_details_sheet.dart`
- Create the bottom sheet that acts as the entry point for the Cloud Staging Export.

#### [NEW] `app_v2/lib/features/vault/application/meal_proposal_service.dart`
- Implement the service to handle cloud exporting.
- Re-use the `image_picker` logic to natively enforce `< 500KB` image uploads, avoiding new dependencies.

---

### Backlog Management
#### [MODIFY] `ISSUES.md`
- Mark "Unsaved Changes Confirmation Dialog / PopScope" as `[x]`.

## Verification Plan

### Automated Tests
- Run `flutter analyze` in `app_v2` to ensure no linting errors.

### Manual Verification
- **Recommendations**: Like a recommended meal and verify the cards do not shift or regenerate.
- **Vault UI**: Open Vault screen and verify the header counters do not overflow.
- **Cloud Export**: Trigger an export from `MealDetailsSheet` and verify the compressed payload size.
