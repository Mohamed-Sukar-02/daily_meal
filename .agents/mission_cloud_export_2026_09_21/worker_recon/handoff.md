# handoff — worker_recon → manager
VERDICT: plan items 1–3 (engine lottery, pinned notifier, vault Row header) + PopScope note
are DONE with test coverage; remaining scope = Cloud Staging Export (service, 2 new screens,
sheet entry point, storage rule, auth), ISSUES.md creation.
RISK FLAGS for worker_cloud:
- staging payload must exclude `shortName` (rules allow-list) and force `isStarterMeal:false`,
  `status:'pending'`, createdAt as ISO string (10..40 chars).
- name clamp 2..100 (local column allows 1..120), prepTime clamp 5..720, notes ≤ 500.
- storage: users may only write `staging_meal_images/{own uid}/…` <500KB.
- do not rename existing keys: meal_details_edit_button / meal_details_delete_button /
  vault_* keys — regression suite depends on the current set.
