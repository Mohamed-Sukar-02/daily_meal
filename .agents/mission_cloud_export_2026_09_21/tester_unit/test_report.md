# tester_unit — test report

## Deliverables (committed)
- `test/unit/meal_proposal_payload_test.dart` — 25 cases, 5 groups:
  1. **Rules parity (8)**: full-population doc passes a Dart MIRROR of
     isValidStagingMeal; key-set ⊆ allowedKeys / ⊇ requiredKeys; `shortName`
     & `id` never leak (rules use hasOnly); createdAt UTC-ISO ∈ 10..40 chars and
     round-trips to the same instant (timezone-independent); name <2 chars after
     trim → null (fail-fast); name >100 → truncated; prepTime clamped 5..720;
     notes ≤500 / omitted when blank; imageUrl omitted when null/blank/>2048.
  2. **Vocabulary totality (4)**: EVERY ProteinType/CarbsType/MealCategory value
     maps into the cloud sets; round-trip identities pinned (chicken/beef/fish,
     legume↔meatless, casserole/dry_sandwich identities); exhaustive 6×6×6 = 216
     combination sweep → every payload rules-valid.
  3. **500KB image gate (5)**: null/blank/http(s)/assets rejected without disk
     I/O; missing file → null (no throw); 100KB accepted; 500KB+1 rejected,
     exactly 500KB accepted; 0-byte rejected. (temp dirs, torn down.)
  4. **Duplicate guard (5)**: fresh meal not blocked; markProposed blocks the
     same version incl. across a fresh guard handle (serialisation); newer
     updatedAt re-opens; corrupt ledger → empty, never throws; per-meal isolation
     + ledger is valid JSON.
  5. **Outcome codes (3)**: submitted/imageAttached/isSuccess; blocked maps
     requiresWifi vs noConnection to distinct codes; failed keeps raw cause.
- `test/widget/meal_details_sheet_actions_test.dart` — 3 build-only cases:
  legacy edit/delete keys survive; new propose + fullscreen entry points render
  enabled in vault context; history context stays read-only (no action leak).
  Tap-through deliberately NOT widget-tested: the flow ends in AppToast timers +
  connectivity plugin; the gate itself is deterministic offline under
  FLUTTER_TEST and the logic is covered by the unit suite (documented decision).

## Execution status (honest)
NOT EXECUTED in-sandbox — no Flutter/Dart SDK and package hosts unreachable
(`pub.dev`, `flutter.dev`, `storage.googleapis.com` → blocked; verified).
Green-by-construction measures taken: every constructor signature verified
against `app_database.g.dart` (Meal, MealHistoryData, enums incl.
MealEntryType.cooked); every referenced symbol cross-checked by tester_static;
no Firebase/plugin calls at test time (pure layers + SharedPreferences mocks +
dart:io temp files only). Run on an SDK machine: `flutter test test/unit/meal_proposal_payload_test.dart test/widget/meal_details_sheet_actions_test.dart`.

## VERDICT: PASS (design) — 28 committed cases; execution deferred to SDK machine (tracked in ISSUES.md checklist).
