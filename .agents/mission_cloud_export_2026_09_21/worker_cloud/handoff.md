# handoff — worker_cloud → manager
STATUS: complete. All 8 file operations done per plan (3 NEW incl. service, 5 MODIFY).
Design notes for testers:
- Rules parity is the contract: allowedKeys WITHOUT shortName; requiredKeys all produced.
- Deterministic testability: pure builders/guard/vocabulary + FLUTTER_TEST-offline gate.
- Regression safety: zero pre-existing keys/layouts renamed; sheet legacy row byte-identical.
OPEN (moved to ISSUES.md): deploy rules; admin triage surface for staging_meals.
