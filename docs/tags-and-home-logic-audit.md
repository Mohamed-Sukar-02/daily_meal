# Tags & home-page logic — audit

Scope: the meal classification model (`proteinType` / `carbsType` / `category` / "meal
options") and the home page's "3 suggestions → tap one" flow. Everything below is read
off `origin/main` at `b53d09d`; file:line references are given so each claim can be
checked.

> **P0 is landed** on `arena/01a0f883-daily-meal` — `617b483` (i18n + leftovers),
> `d6b7074` (sync diff), `0c9e87a` (determinism), `12ef7ed` (reachability),
> `1a490fe` + `3d1446f` (dead code, test placement). §2.4, §3.3, §3.4 and §3.5
> describe the pre-fix state and are annotated where the fix changed the reading;
> §5's P0 list carries the commit for each item. One caveat: nothing here has been
> through `flutter analyze` / `flutter test` — the sandbox it was written in has no Dart
> SDK and no network to fetch one — so the verification behind each change is the tests it
> added, which still have to be run once on a machine that can run them.
>
> **Decision recorded here at the owner's request (2026-10-02):** `meatlessCooldownDays`
> defaults to **3**, not 0, for new installs (`app_database.dart` `onCreate`,
> `AppSettingsDao.defaultSettings`, the column default, `_fallbackSettings`, and
> `SystemDefaults` — including the two `?? 0` fallbacks, because a remote config that
> omits the key must not undo the local default), and the Settings row is **always
> drawn**, never hidden at 0. Existing databases are left alone: the `from < 8`
> migration still writes 0, because a window nobody ever saw is not permission to
> start excluding dishes. 0 remains a legal, visible value = "no exclusion".
>
> Two findings from the first draft are **now landed upstream**: `e8820c9` routes `legume`
> and `dairy` into `meatlessCooldownDays` (the behavioural axis is wider than the old
> `none`-only rule) and loosens the carb-diversity gate. §2.3 and §4.1 are updated for
> that — what still diverges about `meatless` is the *name in the UI* and the *cloud
> definition*, not the engine.

---

## 1. Verdict

Two separate problems are being conflated, and they need different fixes.

1. **The tags are not wrong as data — they are wrong as a *system*.** There is no rule
   about who owns a fact, so the same fact is written in three places (protein, category,
   cloud token) that can disagree and two of which cannot hold all the values. Only
   `proteinType` changes behaviour; `category` is consumed by the display and the cloud but
   by no filter and no ranking rule; `carbsType` is a tie-breaker; and the one field that
   would let a user correct the engine (`customCooldownDays`) is never read. Every
   decorative-but-mandatory tag still costs the user a decision on every meal they add.
2. **The home page has no concept of a *decision*.** `Cook This` is simultaneously the
   "I pick this" button, the "I cooked this" log line and the input to tomorrow's
   cooldown — one tap, three meanings, no confirmation, and no visible state on Home
   afterwards. That is exactly the "أول ما أختار أي option خلاص" feeling.

---

## 2. What exists today, and what each tag actually drives

| Field | Where | Values | Drives |
|---|---|---|---|
| `proteinType` | `meals_table.dart:6` | 6 | **cooldown window** (chicken/beef/fish/none only), **variety rule**, badge/emoji, history stat cards |
| `carbsType` | `meals_table.dart:15` | 6 | fallback axis of `_selectDiverse` (`cooldown_engine.dart:416`), vault filter chip |
| `category` | `meals_table.dart:24` | 6 | display pills (`quick_meal_view.dart:284`, `meal_info_banner.dart:111`) + cloud mapping + sync diff — **no** engine role, **no** UI filter |
| `isFridaySpecial` | `meals_table.dart:42` | bool | ±15/−5 score in `calculateMealScore` |
| `isFavorite` | `meals_table.dart:43` | bool | +5 score, heart UI |
| `isStarterMeal` | `meals_table.dart:44` | bool | provenance (seeded row) — used by sync/dedup sorting, **not editable** |
| `customCooldownDays` | `meals_table.dart:48` | int? | **nothing** — never read by the engine |
| `prepTime` | `meals_table.dart:41` | int | "Quick 30m" filter chip |

So the honest sentence is: *"protein is a behavioural tag, carbs is a tie-breaker,
category and per-meal cooldown are UI."*

### 2.1 The four vocabularies

One meal's classification is written down in four independent places:

```
local enum  →  MealCloudVocabulary.proteinToCloud/carbsToCloud/categoryToCloud
               (meal_proposal_service.dart:445-505)
cloud token →  Firestore rules whitelist (firestore.rules:62-67)
cloud token →  cloudProteinType / cloudCarbsType / cloudCategory
               (discovery_providers.dart:119-148)
cloud token →  AppConfigSyncService._mapProtein/_mapCarbs/_mapCategory
               (app_config_sync_service.dart:366-395)
enum        →  AppStrings.proteinLabel/carbsLabel/categoryLabel (display)
```

The upload side is **narrower** than the local enums and the loss is silent. `chicken`,
`beef`, `fish` and `legume` round-trip intact (`legume ↔ meatless` is a rename, not a loss);
what does not survive is:

* protein `dairy` / `none` → `other` → on download → `none` (a protein the user chose is gone)
* carbs `potato` / `grains` → `none` → on download → `CarbsType.none`
* cloud `popular` → `egyptianTraditional` (an invented category for every admin catch-all)

Consequences:

* **A synced meal can never be both correct and "in sync".** `mealCloudDiffs`
  (`meal_sync_diff.dart:44-62`) compares the *local* label with `cloudCarbsType(cloud)`.
  A row with `carbsType: potato` and a `cloudId` reports a permanent phantom diff
  ("بطاطس" → "بدون نشويات"), so the sync mark stays orange forever, and "update from
  cloud" answers by destroying the local value. `isProposableAgainstCloud`
  (`meal_proposal_service.dart:1188-1199`) is fed by the same function, so such a meal
  looks worth re-proposing to the admin forever, and burns the daily proposal quota.
  `test/unit/cloud_category_mapper_test.dart` was written for exactly this failure mode
  — but it pins `proteinType: 'chicken'` and `carbsType: 'rice'` in both fixtures, so the
  two lossy axes are the two it never touches.
* **The `protein none` downgrade is not cosmetic.** `_resolveSpecificCooldown`
  (`cooldown_engine.dart:196-225`) gives `none` the `meatlessCooldownDays` window, whose
  default is **0 = no cooldown** (`app_settings_table.dart:27`, and the comment at
  `cooldown_engine.dart:222-224` is explicit). So an eggs/cheese meal that round-trips
  through the cloud goes from a 14-day window to *no window at all* and can be served
  every single day.

### 2.2 The taxonomy overlaps itself

`MealCategory` re-cuts the same cake as `ProteinType`, with no constraint between them:

* `seafood` vs `ProteinType.fish` — "سمك بلطي" can be tagged `fish + seafood` (fine) or
  `chicken + seafood` (accepted). The UI then says "أسماك وبحريات" while the engine
  applies the 2-day chicken window. Nothing prevents this.
* `vegetarian` vs `legume` / `dairy` / `none` — a "koshary + beef" row is legal.
* `egyptianTraditional` is labelled "Traditional & **stews**" and `soupStew` is labelled
  "Soups & **stews**" (`app_strings.dart:908-925`) — two chips whose labels overlap, so
  the user's choice is a coin flip. In the seed vault the split is already arbitrary:
  مسقعة (an oven tray) = `egyptianTraditional`, طاجن بامية (a stew) = `ovenBaked`,
  حواوشي / كبدة إسكندراني / مكرونة بالسجق = `fastFood`.
* `category` has no `none`/`unknown` (`meals_table.dart:40`, non-nullable), so *every*
  meal must be forced into one of six, and an unclassifiable meal is a *mis*classified
  one. Meanwhile `proteinType` and `carbsType` both ship a `none` sentinel that means
  "genuinely none" **and** "not set" at once.

### 2.3 `none` is overloaded, and "meatless" is a name three layers still disagree on

Since `e8820c9` the *behavioural* definition is consistent:

| Site | "meatless" means | State |
|---|---|---|
| Engine (`cooldown_engine.dart:196-231`) | `none ∪ legume ∪ dairy` | ✅ aligned |
| Vault-capacity judge (`recommendation_provider.dart:351-361`) | same three | ✅ aligned |
| History stats (`history_screen.dart:210`) | `legume ∪ none ∪ dairy` | ✅ aligned |
| Settings + History **labels** | "خضار / Veggie" (`strings.veggies`, `strings.veggieShort`) | ❌ narrower than the bucket, which also holds `none` (soup, salad, plain rice) |
| Cloud vocabulary | `meatless` ← `legume` only; `dairy`/`none` → `other` | ❌ the cloud cannot express the window the user set |

Two consequences are still open:

* **The row is named for a subset of what it governs.** "خضار / Veggie" reads as
  "salad-ish", but it is the cooldown window of every meat-free protein including `none`.
* **The window is off by default and hidden while off.** `meatlessCooldownDays` defaults
  to `0` = *no cooldown* (`app_settings_table.dart:27`, and the explicit note at
  `cooldown_engine.dart:222-223`), while Settings renders the row only
  `if (settings.meatlessCooldownDays > 0)` (`settings_screen.dart:407`). On a fresh install
  that means every `legume`/`dairy` dish (كشري، شوربة عدس، فول مدمس، شكشوكة) is now
  eligible **every day**, and the control that would change it is invisible until it is
  already on. It *is* reachable from the cooldown sheet
  (`cooldown_details_sheet.dart:127-138`), which is what makes this a discoverability bug
  rather than a dead setting.


### 2.4 The rest of the tag surface

* **No time-of-day axis at all.** `فول مدمس` (15 min, breakfast) is in the same pool as
  `فتة مصرية` (75 min, lunch). The app happily suggests ful at 9pm, and the day is
  modelled by exactly one event — see §3.
* **`isStarterMeal` is provenance wearing a tag's clothes** (`meals_table.dart:44`). It
  marks "came from the seed / the starter sync" — which is why it is not in the editor and
  why `deduplicateMeals` sorts by it (`meals_dao.dart:326-340`). It belongs on a
  provenance column (`source`), not in the tag set.
* **`customCooldownDays` is a dead feature.** Declared (`meals_table.dart:48`), preserved
  on upsert (`meals_dao.dart:197-202`), never read by the engine, never settable in
  `QuickAddSheet`. The only place a per-meal override could live does not exist behaviourally.
* **Per-meal "options" are a 2-pill row** (`quick_add_sheet.dart:819-845`) exposing only
  `isFridaySpecial` and `isFavorite`, while the row is labelled "خيارات الوجبة / Meal
  options" — a label that promises a group of settings that isn't there (it hides the
  per-meal cooldown and `isStarterMeal`).
* **`category` cannot be filtered in the UI.** `VaultFilterState.category`,
  `toggleCategory` and the SQL predicate all exist (`vault_providers.dart:29-120`,
  `meals_dao.dart:453-455`), but `VaultFilterBar` renders protein + carbs + favourite +
  Friday + quick chips only (`vault_filter_bar.dart:64-118`). `toggleCategory` has no
  caller. So the tag has no consumer on either side: not in the engine, not in the filter.
* **Two parallel filter implementations.** `MealsDao.watchFilterByTag` / `filterByTag`
  (`meals_dao.dart:54`, `meals_dao.dart:121`) have **no callers**; the vault filters in Dart
  over `allMealsProvider` (`vault_providers.dart:141-180`). Two sources of truth for the
  same predicate set, one of them untested by usage.
* **History snapshots protein + carbs but not category** (`meal_history_table.dart:19-21`),
  so "what did I eat in February" can be answered by protein but never by dish type — the
  one axis a monthly report would actually use.

---

## 3. The home page: three options that are not options

### 3.1 One tap = three writes of meaning

`QuickActions` → `onCookedToday` → `_handleCookedToday` (`home_screen.dart:145-148`,
`507-525`) → `markCookedToday` → `logCookedMeal` → a `cooked` history row
(`meal_history_dao.dart:160-167`). In one gesture, the app:

1. treats the tap as **the decision** ("this is today's meal");
2. records it as **the fact** ("it was cooked");
3. feeds it to **the engine** (the meal is now blocked for its cooldown window).

There is no state between "thinking about it" and "cooked". The card CTA has no
confirmation (the spin wheel does — `spin_wheel_dialog.dart:340-354` — which shows the
pattern was understood and applied only there). Undo exists only inside the transient
toast (`home_screen.dart:515-522`); after it fades, the only path back is **wiping the
whole history**: `HistoryController.deleteHistoryEntry` exists
(`history_providers.dart:65-74`) and is never called by any UI — the History screen offers
only "clear all" (`history_screen.dart:112-140`).

### 3.2 "The day" is not a modelled thing

* `targetCount = min(3, meals.length)` (`cooldown_engine.dart:104`) — three is hardcoded;
  with a 2-meal vault you get two cards and `canSpin` (`home_screen.dart:99`) decides the
  wheel appears.
* There is no `breakfast/lunch/dinner` concept anywhere (grep for lunch/dinner/breakfast
  returns nothing), yet the copy speaks of "وجبة الغداء" (`skippedSuccess`,
  `app_strings.dart:195`) and the reminder says "حان وقت اختيار وجبة اليوم"
  (`app_strings.dart:806-810`). One meal per day is assumed by the words and unenforced by
  the data: nothing stops a second `cooked` row the same day, and the day is then just two
  rows in a list.
* After the pick, **Home shows no trace of it**. The key changes (history signature,
  `recommendation_provider.dart:83-115`) → the pinned replay is skipped → the engine
  re-selects a fresh three. The screen still says "3 options" and never says "اليوم: X ✅",
  so the user cannot tell a decided day from an undecided one — the state that would make
  picking feel safe.
* The daily reminder is scheduled unconditionally at the configured time
  (`notification_service.dart:91-152`) with no check against today's history
  (`hasAnyHistory` is only used for notification-inbox gating,
  `notifications_provider.dart:24`), so the nag arrives whether or not the day is decided.

### 3.3 Picking a card silently re-deals the *other two*

`_rankCandidates` draws the per-meal lottery sequentially over the **filtered** pool:

```dart
final draw = Random(daysSinceEpoch(today) + shuffleSeed * 7919);      // cooldown_engine.dart:366
final ordered = [...candidates]..sort((a, b) => a.id.compareTo(b.id));
final lottery = { for (final c in ordered) c.id: draw.nextDouble() };
```

The comment above it (`cooldown_engine.dart:355-365`) promises "each meal's value is
pinned to the seed, so browsing never moves the cards". It is only pinned against a
*stable pool*: `Random` is a stream, so removing one candidate shifts every value that
follows it by one draw. Logging today's meal changes the filtered pool (that meal is now
in cooldown), which re-rolls the numbers for every higher-id meal, which can swap the two
cards the user was *not* touching. Any event that changes pool size does the same: a new
meal added, a delete, a settings change, a protein flip that moves a meal across a
cooldown boundary, even a relaxation level change.

Fix: derive the per-meal value from a hash of `(mealId, dayEpoch, shuffleSeed)` instead of
a stream draw — then the pool can change freely and every untouched card keeps its number.

*Landed* (`0c9e87a`): `_lotteryFor` is that hash, and
`test/unit/recommendation_lottery_stability_test.dart` cooks the top card across 25 seeds
and asserts the two cards nobody touched keep their order. The mixing is 32-bit with the
multiplies split into 16-bit halves, because a web build computes on a 53-bit double and
`&` there is signed: the day's cards must not depend on the platform that compiled the app.

### 3.4 "Change this meal" is unreachable

`rerollSingle` (`recommendation_provider.dart:245-315`) replaces one card and keeps the
other two, keeps `_pinnedKey` so the swap survives the next drift write, and refuses to
duplicate a staying card's protein. It has **no UI caller**: `rerollMeal`
("غيّر الأكلة دي") and `rerollNoAlternative` (`app_strings.dart:229-233`) are rendered by
nothing. `test/unit/home_recommendation_tuning_test.dart` exercises the provider
directly, so five green tests cover a feature the app cannot reach. That is precisely the
control the "three options" screen is missing: today the only escape from a card you do
not want is `RefreshIndicator` → confirm → re-deal all three (and, per §3.3, re-roll the
lottery too).

*Landed* (`12ef7ed`): `QuickActions` takes an optional `onReroll`; Home renders a flat
secondary chip beside the CTA wherever `canSpin` holds, keyed `btn_reroll_<mealId>`, and
`rerollNoAlternative` is what the user hears when the pool has nothing left to offer.

### 3.5 Other confirmed defects in this flow

* **`Eat yesterday's leftovers` is not bound to yesterday — or to before today.**
  `getLatestCookedMeal()` is called with no `beforeDate` and no window
  (`home_screen.dart:629`, `meal_history_dao.dart:103-115`), so (a) a meal cooked three
  weeks ago is logged as leftovers today and re-blocks itself for a fresh window, and
  (b) a meal cooked *this morning* is offered back as "leftovers" tonight.
* **Locale is baked into persisted data.** That path writes
  `mealName: '(بقايا امبارح) كشري...'` (`home_screen.dart:638`). `mealName` is a stored
  snapshot, and the file is careful about it elsewhere — takeout persists the key `'takeout'`
  precisely so `historyEntryDisplayName` can re-localise it
  (`meal_history_dao.dart:173-182`). Leftovers do the opposite, so the row keeps Arabic
  text after a language switch (and `MealHistory.mealName` has no normalised twin to fall back on).
* **`Cook This` is not localised**: `String get cookThis => 'Cook This';`
  (`app_strings.dart:197`) — the primary CTA of the app is English on an Arabic screen.
  Grepping the file for display getters with no `isEn` branch returns only three: this,
  `defaultUserName => 'User name'` (`app_strings.dart:687`, shown as the profile fallback in
  the settings header and the edit dialog — `settings_screen.dart:279`, `profile_edit_dialog.dart:176`) and the `EN`/`AR` language switch labels (`:744-745`), which are the only
  legitimate ones. So "no display literal outside `AppStrings`" is a repo rule the string
  table itself does not follow.
* **The `skipped` entry type is unreachable**: `MealEntryType.skipped` (`meal_history_table.dart:11`) is in the
  enum, the DB default set and the History labels, `logSkippedMeal` + `markSkipped` exist
  (`meal_history_dao.dart:184-193`, `recommendation_provider.dart:469-486`) — no UI calls
  them. The one button that would answer "not cooking today" (`notCookingToday`,
  `app_strings.dart:196`) was built and never wired.
* **A never-cooked meal outranks any cooked meal, always.** `sRecency = 25.0` for
  `lastCookedDate == null` vs `min(20.0, …)` otherwise (`cooldown_engine.dart:300-306`),
  and bands are 5 wide (`_interchangeableBand`, `cooldown_engine.dart:321-324`): 25 lands
  in a band no cooked meal can reach. Add three dishes to a 20-dish vault and those three
  own every card until they have been cooked once each.
* **Variety is a 3-protein rule with a carb tiebreak, and nothing else**
  (`cooldown_engine.dart:416-445`): no two cards share a protein, and only once two cards
  exist do carbs enter. `category` is never consulted, which is why "three oven trays" or
  "three 75-minute pots" is a normal day.
* **The `isFavorite` exclusion from the eligibility key is half-true.** The comment
  (`recommendation_provider.dart:60-63`) says a heart is "a pure score nudge" and
  therefore safe to leave out of the key. With `+5` and a band width of `5`, a heart moves
  a meal exactly one band — so it *can* change which three meals a day gets; the pin only
  defers it to the next recompute (midnight, history write). Fine as a UX trade, wrong as
  a stated invariant — and the same comment is what justifies leaving `category` out.

---

## 4. Proposed model

### 4.1 One rule: every tag must answer one question, and someone must consume it

Assign each tag an owner and a consumer; if a tag has no consumer, it is not a tag — it is
noise the user pays for at every meal they add.

| Axis | Question | Type | Consumer |
|---|---|---|---|
| `proteinGroup` | which rotation window applies? | enum {chicken, beef, fish, legume, dairy, none} | cooldown engine — `legume`/`dairy`/`none` already share the meatless window (`e8820c9`) |
| `carbs` | what is the plate built on? | enum {rice, pasta, bread, potato, grains, none} | variety axis + filter |
| `style` | how is it cooked / served? | **optional** enum {طبيخ, صينية فرن, مشويات, سندوتش, شوربة, ناشف} + `unknown` | variety axis + filter + report |
| `occasions` | when does it make sense? | **set** {breakfast, lunch, dinner, fridayFeast} | day slots + time-of-day filter |
| `effort` | how much day does it take? | int minutes (already exists) | quick filter, weekday/weekend weighting |
| `flags` | user's relationship to it | `isFavorite` (+ `source` = seed/cloud/local, moved out of tags) | ranking nudge, dedup, UI |
| `cooldownOverride` | "trust me, different" | int days, nullable | engine, *before* `proteinGroup` |

Then:

1. **`category` either earns its place or is derived.** Two defensible options:
   * *derive* it from `proteinGroup` + `style` + name heuristics for display, store nothing
     (removes 100% of the `fish + seafood`-style contradictions);
   * or keep it stored but make it **owned**: `style` describes cooking/serving only,
     `seafood` moves out of the category set entirely (it is already a protein) and
     `vegetarian` too (it is `legume`/`eggsDairy` + no meat).
   Either way the label collision "Traditional & stews" vs "Soups & stews" must be resolved.
2. **Name `meatless` for what it is.** Engine, capacity judge and History stats agree now
   (`none ∪ legume ∪ dairy`). Left over is the copy: the settings row and the History card
   say "خضار / Veggie" while the bucket is "no meat", and the cloud's `meatless` carries
   only `legume`. Rename the two UI strings to a generic "بدون لحوم / Meatless"; the cloud
   fold stays a local policy, which is exactly why it must not appear in a sync diff (§4.1.4).
3. **Kill or finish the per-meal override.** `customCooldownDays` should be read by
   `_resolveSpecificCooldown` first (one line) and exposed as a pill in the "meal options"
   row — or the column should go. A silent, unwired override is worse than none.
4. **One vocabulary owner, and compare folded-to-folded.** The cloud set cannot just be
   widened: `firestore.rules:64-67` whitelists exactly four carbs (`rice|pasta|bread|none`)
   and five proteins, so a new token means a rules deploy plus a migration of rows that are
   already published. The honest fix is (a) `mealCloudDiffs` compares **`local → cloud
   token` against the cloud token**, so a fold never reads as an edit; (b) the same rule
   stops `isProposableAgainstCloud` burning the daily proposal quota on an unrepresentable
   difference; (c) "update from cloud" must not write a folded value back over a local axis
   the cloud cannot express. And both directions belong in one file — today they are split
   across `meal_proposal_service.dart:445-505` and `discovery_providers.dart:117-148`.
   `popular` should stop being a category: a feed-wide popularity flag is not a cuisine.
5. **Persist provenance, not display, in history**: leftovers should store
   `mealId` + `entryType: leftover` and let `historyEntryDisplayName` decorate the name,
   and the row should snapshot `style`/`occasions` too, so monthly reports can group by
   dish type and not only by protein.

### 4.2 Home page: split *decide* from *eat*

The 3 cards are **options**, not 3 meals, and choosing among them should not be the same
event as cooking. Proposed model:

```
MealPlan(day, slot, mealId, status)      // status: planned | cooked | rejected
MealHistory(day, slot, mealId, kind)     // kind: cooked | leftover | takeout | skipped
```

* Tapping a card = **plan it** ("دي أكلة النهاردة") — visible on Home as a decided state,
  reversible from Home itself (not only from a toast), and it does **not** touch the
  cooldown window.
* `Cook This` (or "خلصت/طبختها") inside the details sheet = **eat it** — the only action
  that writes history and moves the rotation window.
* If the product wants one-meal-a-day, say it in data: `day` unique per slot, with a
  visible "اليوم اتحدد" state; if it wants lunch + dinner, `occasions` + `slot` is the
  axis that makes "I already picked lunch" and "still open for dinner" two different,
  useful states instead of a conflict.
* The daily reminder then becomes honest: skip if the day's slot is already planned.

Minimal version that needs no new table (worth doing first, and it fixes the felt
problem): the CTA stops writing history and instead sets a `plannedMealId(day)` in
`app_settings`/prefs; Home renders "النهاردة: <name> · هنطبخها؟ [سجل]" and the 3 cards
stay as-is; "سجل" performs today's `markCookedToday`. One flag, one banner, no migration.

### 4.3 Day-level determinism

* Replace the stream draw with `hash(mealId, dayEpoch, seed)` (§3.3) so an untouched card
  never moves.
* Clamp `sRecency` and make "never cooked" a **band-mates-with-overdue** value (e.g.
  `20`) instead of `25`, so a new dish competes rather than occupies.
* Wire `rerollSingle` to a per-card "غيّر الأكلة دي" (§3.4): it is the control that makes
  "3 options" feel like options, and it is already implemented and tested.
* Include the day's decision in the eligibility key, or the pinned replay will fight it.

---

## 5. Plan

**P0 — no schema change, no product decision. All six items are in scope, in this order**
(one commit each, `flutter analyze` + `flutter test` green between them):

1. **i18n** *(landed `617b483`)* — `AppStrings.cookThis` and `defaultUserName` got their
   Arabic branch, plus `app_strings_localization_test.dart`, which reads the table itself so
   a third getter cannot slip in the same way.
2. **Leftovers** *(landed `617b483`)* — bound the lookup to the previous days *and* exclude today
   (`meal_history_dao.dart:103-115`); store the *kind* of entry instead of display text
   (the `logTakeoutMeal` pattern), decorate at render time, and normalise the legacy rows
   that already hold `'(بقايا امبارح) …'` inside `mealName` (`home_screen.dart:631-648`,
   `AppStrings.historyEntryDisplayName`).
3. **Sync diff** *(landed `d6b7074`)* — compare mapped-to-mapped so `dairy`/`none`/`potato`/`grains` stop
   producing a phantom diff and a permanent proposal affordance
   (`meal_sync_diff.dart:44-62`); stop "update from cloud" overwriting a local axis the
   cloud cannot express; and extend `cloud_category_mapper_test.dart` with the protein and
   carbs legs — it pins `chicken`/`rice`, so the two lossy axes are the two it never covers.
4. **Determinism** *(landed `0c9e87a`)* — replace the sequential lottery with a per-meal hash of
   `(id, day, seed)` (`cooldown_engine.dart:361-371`), plus a test that cooking one card
   cannot re-order the others.
5. **Reachability** *(landed `12ef7ed`)* — wire `rerollSingle` to a real "غيّر الأكلة دي" control on the home
   card (`quick_actions.dart`, `home_screen.dart:145`). Implemented, tested, unreachable.
6. **Dead code** *(landed `1a490fe`)* — `watchFilterByTag`/`filterByTag` **and the private
   `_buildFilteredQuery` behind them** (the vault filters the watched list in Dart, so the
   SQL-side copy was a second definition of "what counts as fish"),
   `latestCookedMealProvider` + `watchLatestCookedMeal`, `undoHistoryEntry`, `leftoverOnly`.
   `toggleCategory` + `VaultFilterState.category` were **kept**: they are P2's missing chip
   row waiting for a caller, not a duplicate. Kept deliberately:
   `markSkipped`/`logSkippedMeal` and `HistoryController.deleteHistoryEntry` — P1 gives
   them their callers.

**P1 — decide vs eat, no migration (the change this audit exists for).** Tapping a card
sets `plannedMealId` (prefs) and Home shows the decided state with its own un-plan control;
`Cook This` moves inside the details sheet, asks once, and is the only thing that writes
history; History gains a per-entry delete (the controller method already exists,
`history_providers.dart:65`); "مش هتطبخ النهاردة" wires the dead `skipped` type; the daily
alarm skips a day that is already decided. See `docs/p1-p2-plan.md` for files and tests.

**P2 — tag model (approved subset, schema-free).** Rename the meatless rows generically;
make `customCooldownDays` real (read first in `_resolveSpecificCooldown`, folded into the
eligibility key so a change re-ranks, editable in the "meal options" row); give `category`
the consumer it is missing — a filter chip in the vault; and fix the seed rows whose
category contradicts the dish (مسقعة and طاجن مكرونة بالسجق are oven trays). Nothing is
deleted and no column is added, so: no migration, no rules deploy. `occasions`/`style` —
the axes that *do* need one — wait for P1.

**P3 — day slots** (lunch/dinner), only if the product wants two decisions per day. That
is a data-model change touching history, cooldown semantics (a meal cooked for lunch is
blocked for dinner too), the vault's "cooked" badges and the reports — worth it, but it is
a product decision, not a refactor.

---

## 6. Dead / inconsistent, for the record

| Thing | Location | State |
|---|---|---|
| `customCooldownDays` | `meals_table.dart:48` | column + upsert preservation, no read, no UI |
| `isStarterMeal` | `meals_table.dart:44` | not editable, provenance in the tag set |
| `MealEntryType.skipped` | `meal_history_table.dart:11` | written by nothing |
| `markSkipped` | `recommendation_provider.dart:469` | no caller |
| `rerollSingle` + 2 strings + 5 tests | `recommendation_provider.dart:245` | was unreachable → `12ef7ed` |
| `toggleCategory` / `VaultFilterState.category` | `vault_providers.dart:29,116` | settable by no UI |
| `watchFilterByTag` / `filterByTag` / `_buildFilteredQuery` | `meals_dao.dart` | deleted → `1a490fe` |
| `latestCookedMealProvider` | `history_providers.dart:16` | deleted → `617b483` |
| `undoHistoryEntry` | `recommendation_provider.dart:510` | deleted → `1a490fe` |
| `HistoryController.deleteHistoryEntry` | `history_providers.dart:65` | no UI → no per-entry undo |
| `ISSUES.md` (referenced in `quick_add_sheet.dart:44`) | — | file does not exist in the repo |
| `veggies`/`veggieShort` as the meatless Settings label | `app_strings.dart` | still wording-specific → P2 |
| `healthyTag` / `balancedTag` / `deliciousTag` | `meal_info_banner.dart:116-133` | `'صحي'` is prepended to **every** meal unconditionally, and balanced/delicious is re-derived from `proteinType` — three labels the user never set, two of them a protein restatement |
