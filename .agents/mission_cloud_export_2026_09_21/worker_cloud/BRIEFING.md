# BRIEFING — worker_cloud
## Mission
Implement the Cloud Staging Export end-to-end + meal view navigation, exactly per
`.agents/DRIVE_PLAN.md` (paths reconciled by manager: repo root `lib/`, sheet exists → MODIFY).
Constraints: no new dependencies; no display text outside AppStrings; payloads must satisfy
`firestore.rules::isValidStagingMeal`; do not touch existing widget keys/layouts (regression suite).
