# BRIEFING — Mission Manager (identity: manager)

## Mission
Execute the Google Drive implementation plan (`.agents/DRIVE_PLAN.md`, fetched 2026-09-21)
against this repository: resolve the recommendation-engine state bug, the Vault header clip,
implement the Cloud Staging Export (service + meal views + sheet entry point), and update the
backlog — with best-in-class performance, verified by a dedicated tester squad.

## 🔒 My Identity
- Archetype: manager (orchestrator)
- Working directory: `.agents/mission_cloud_export_2026_09_21/manager`
- Branch: `arena/01a0c2e2-daily-meal` (merge target: `main` via PR at mission end)
- Integrity mode: development

## 🔑 Path reconciliation (plan → this repo)
The Drive plan was written against an `app_v2/` workspace that does not exist here.
This repo keeps the app at the root, so every planned path maps as:
- `app_v2/lib/...` → `lib/...`
- `ISSUES.md` → does not exist yet → **create** at repo root (backlog of record).
- `meal_details_sheet.dart` is marked [NEW] in the plan but **already exists** →
  becomes [MODIFY]: keep the sheet, extend it to act as the Cloud Staging Export entry point.

## 🔑 Plan "Open Question" — resolution (recorded for the user)
> Is it acceptable if the recommendations only refresh at midnight or when explicitly requested?

Current pinned implementation (`TodayRecommendationsNotifier._eligibilityKey`) already answers
this conservatively: recommendations re-rank at **midnight** (dayEpoch in key), on **explicit
refresh** (refreshSeed), on **meal add/delete** (sorted meal-id list in key), on **history
change** and on **cooldown-settings change** — but NOT on favourite/photo/name edits.
Liking a meal therefore never moves the cards. No further change required.

## Team roster
| Role | Identity | Scope |
|------|----------|-------|
| Manager | `manager` | Plan, dispatch, integration, gate reviews, PR + merge |
| Worker | `worker_recon` | Audit which plan items are already implemented; produce evidence |
| Worker | `worker_cloud` | Cloud Staging Export: service, quick meal view, meal screen, sheet entry point, router, strings, icon glyph, storage rules |
| Worker | `worker_perf` | Performance pass: image cache budget, repaint isolation, const/wrapper hygiene, report |
| Worker | `worker_backlog` | Create/update `ISSUES.md` per plan (PopScope `[x]` etc.) |
| Tester | `tester_unit` | New unit tests: staging payload vs Firestore rules mirror, enum mappings, clamps, duplicate guard |
| Tester | `tester_static` | Static verification: imports, symbol cross-references, brace balance, rules-vs-payload parity (no Flutter SDK in sandbox) |
| Tester | `tester_regression` | Map every touched file to the existing test suite; protect widget-test keys & behaviours |

## Environment constraint (accepted risk)
The sandbox has **no Flutter/Dart SDK** and package hosts are unreachable, so
`flutter analyze` / `flutter test` cannot run here. Testers compensate with:
1. Real Dart test files committed for CI/local runs (`test/unit/meal_proposal_payload_test.dart`).
2. A deterministic static cross-reference audit (scripted, reproducible).
3. Regression mapping of the existing 16-file suite against every touched file.
Every code change is kept surgical; no existing widget keys or layouts are altered.

## Victory conditions
- [ ] All plan items implemented or evidenced-already-done (worker_recon report)
- [ ] `flutter analyze`-clean by construction (static audit passes)
- [ ] New unit tests committed and self-consistent
- [ ] ISSUES.md updated, PopScope marked `[x]`
- [ ] Branch pushed, PR opened, merged into `main`
