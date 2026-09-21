# BRIEFING — tester_unit
## Mission
Hold the Cloud Staging Export contract: the staging payload must satisfy
`firestore.rules::isValidStagingMeal` byte-for-byte, vocabularies must be total,
the 500KB gate and duplicate guard must be deterministic — all WITHOUT Firebase
(pure layers + mocked prefs + temp files). Sandbox has no Flutter SDK: tests are
committed for CI/local execution and must be green by construction.
