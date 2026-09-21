# Project: أكلة النهاردة (Daily Meal) Flutter MVP

## Architecture
- **Framework & Language**: Flutter 3.44.0 (Android target), Dart 3.12.0.
- **Persistence**: Drift SQLite (`drift`, `drift_flutter`, `path_provider`, `path`) with compile-time query safety, reactive streams, and foreign key cascades.
- **State Management**: Riverpod (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) using `AsyncNotifier` for automatic cache invalidation and immediate UI reflection upon meal additions or cooking logs.
- **Navigation**: `go_router` using `StatefulShellRoute.indexedStack` preserving state across 4 bottom navigation tabs:
  1. Home (الرئيسية)
  2. Meal Vault (بنك الوجبات)
  3. History (سجل الأكلات)
  4. Settings (الإعدادات)
- **UI & Localization**: Material Design 3 (Dynamic Color, ColorScheme.fromSeed), RTL by default (`locale: Locale('ar')`, `supportedLocales: [Locale('ar')]`, `GlobalMaterialLocalizations.delegates`).
- **Notifications**: `flutter_local_notifications` + `timezone` for daily scheduled meal reminders.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Drift Database Setup | Core Drift database class, connection via drift_flutter, DAOs, schema generation | M1 | R1 |
| 2 | Meals Table Schema | Fields: id, name, photoPath, proteinType, carbsType, category, prepTime, isFridaySpecial, isBudgetFriendly, isFavorite | M1 | R1 |
| 3 | MealHistory Table Schema | Fields: id, mealId (nullable foreign key with SetNull), mealName, proteinType, carbsType, cookedAt, entryType ('cooked'/'leftover') | M1 | R1 |
| 4 | AppSettings Table Schema | Singleton table: cooldownDays (default 14), themeMode, notificationEnabled, notificationHour, notificationMinute, preventRepeatProtein, preventRepeatCarbs | M1 | R1 |
| 5 | Meals CRUD Operations | DAOs and repository for creating, reading, updating, and deleting meals with stream watches | M1 | R1 |
| 6 | Seed Catalog | 20 authentic Egyptian starter meals seeded on first database creation | M1 | Survey |
| 7 | Cooldown Math Algorithm | Pure Dart engine filtering meals cooked within cooldown days and preventing consecutive protein/carbs repeat | M2 | R2 |
| 8 | 5-Level Graceful Degradation | Fallback cascade when candidates < 3: relax carbs -> halve cooldown -> relax protein -> emergency same-day filter -> minimal vault state | M2 | R2 |
| 9 | Inter-Card Diversity Filter | Guarantee top 3 recommendation cards don't have duplicate protein types when possible | M2 | R2 |
| 10 | Friday Special Booster | Bias recommendation towards Friday special tagged meals when current day is Friday | M2 | R2 |
| 11 | Cooldown Unit Test Suite | Comprehensive unit tests verifying cooldown date boundaries, protein filtering, and fallback cascade | M2 | Acceptance Criteria |
| 12 | Riverpod Providers Setup | AsyncNotifier providers for Meals, History, Settings, and auto-refreshing TodayRecommendations | M3 | R4 |
| 13 | GoRouter Configuration | StatefulShellRoute with 4 tabs, Material 3 navigation bar, Arabic RTL labels | M3 | R4 |
| 14 | Home Screen 3-Card Stack | Swipeable/stacked recommendation cards displaying meal name, prep time, category, protein/carbs tags, photo | M3 | R2 |
| 15 | Quick Actions: Cooked & Leftover | Instant buttons on recommendation cards to log meal into history as 'cooked' or 'leftover' | M3 | R2 |
| 16 | Spin the Wheel Roulette | Animated roulette dialog/sheet picking a random eligible meal from available candidates | M3 | R2 |
| 17 | Meal Vault Screen & Form | List/grid of all meals with search, filter chips, and full Add/Edit Meal modal/screen with immediate Riverpod UI updates | M3 | R1, Acceptance Criteria |
| 18 | Meal Deletion & Cascade | Safely delete meal while preserving history log via snapshot fields | M3 | R1 |
| 19 | History Screen | Chronological log of cooked meals grouped by date (Today, Yesterday, This Week, Older) with delete/undo | M4 | R3 |
| 20 | Settings Screen | Interactive controls for cooldown duration slider, Dark/Light/System theme selector, notification time picker | M4 | R3 |
| 21 | Notification Service | Daily local reminder scheduled via flutter_local_notifications with Android 13 permission handling | M4 | R3 |
| 22 | RTL Arabic Localization | MaterialApp configured with Arabic locale, RTL directionality, Arabic strings, auto-mirrored icons | M4 | R4, Acceptance Criteria |
| 23 | E2E Test Suite (Tiers 1-4) | Systematic 4-tier opaque-box test suite published in TEST_READY.md | Track A | Dual Track |
| 24 | Final E2E Pass & Hardening | 100% pass of E2E test suite + Tier 5 adversarial testing | M5 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| Track A | E2E Testing Track | Build opaque-box test suite across Tiers 1-4, publish TEST_INFRA.md and TEST_READY.md | none | DONE |
| M1 | Core Database & Drift Layer | pubspec.yaml packages, Drift schemas (Meals, MealHistory, AppSettings), DAOs, 20 seed meals, build_runner code generation | none | DONE |
| M2 | Recommendation Engine & Cooldown Logic | Pure Dart Cooldown Algorithm, 5-level fallback, inter-card diversity, comprehensive unit tests | M1 | DONE |
| M3 | Presentation Layer & Riverpod State | Riverpod providers, GoRouter, Home Screen 3-card stack, Spin the Wheel roulette, Quick actions, Vault CRUD UI | M1, M2 | IN_PROGRESS |
| M4 | History, Settings & Notifications | History screen, Settings screen, flutter_local_notifications, theme mode, Arabic RTL localization | M1, M3 | PLANNED |
| M5 | Final E2E Pass & Adversarial Hardening | Run 100% E2E test suite (Tiers 1-4), Tier 5 adversarial hardening, flutter analyze (0 issues), flutter test (100% pass) | Track A, M1-M4 | PLANNED |

## Interface Contracts
### Drift Database ↔ Repositories / Riverpod
- `AppDatabase`: provides `MealsDao`, `MealHistoryDao`, `AppSettingsDao`.
- `MealsDao`: `watchAllMeals() -> Stream<List<Meal>>`, `getMealById(int id) -> Future<Meal?>`, `insertMeal(MealsCompanion meal) -> Future<int>`, `updateMeal(Meal meal) -> Future<bool>`, `deleteMeal(int id) -> Future<int>`.
- `MealHistoryDao`: `watchHistory() -> Stream<List<MealHistoryData>>`, `logMeal({required int mealId, required String mealName, required String protein, required String carbs, required DateTime cookedAt, required String entryType}) -> Future<int>`, `getRecentHistory(int limit) -> Future<List<MealHistoryData>>`, `deleteHistoryEntry(int id) -> Future<int>`.
- `AppSettingsDao`: `watchSettings() -> Stream<AppSetting>`, `getSettings() -> Future<AppSetting>`, `updateCooldownDays(int days) -> Future<void>`, `updateThemeMode(String mode) -> Future<void>`, `updateNotificationTime(int hour, int minute) -> Future<void>`.

### Recommendation Engine ↔ Riverpod Notifier
- `RecommendationEngine.getRecommendations({required List<Meal> allMeals, required List<MealHistoryData> history, required AppSetting settings, DateTime? now}) -> List<Meal>`: Returns top 3 distinct meal recommendations satisfying cooldown and protein diversity.

### Riverpod State ↔ UI
- `todayRecommendationsProvider`: Auto-invalidates whenever `allMealsProvider` or `mealHistoryProvider` changes.
- `allMealsProvider`: Exposes current vault items as `AsyncValue<List<Meal>>`.
- `appSettingsProvider`: Exposes user settings and provides mutation methods.

## Code Layout
```text
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   └── app_constants.dart
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── daos/
│   │   │   ├── app_settings_dao.dart
│   │   │   ├── meal_history_dao.dart
│   │   │   └── meals_dao.dart
│   │   ├── tables/
│   │   │   ├── app_settings_table.dart
│   │   │   ├── meal_history_table.dart
│   │   │   └── meals_table.dart
│   │   └── seed/
│   │       └── initial_meals.dart
│   ├── router/
│   │   └── app_router.dart
│   ├── services/
│   │   └── notification_service.dart
│   └── theme/
│       └── app_theme.dart
├── features/
│   ├── history/
│   │   ├── presentation/
│   │   │   ├── history_screen.dart
│   │   │   └── widgets/
│   │   └── providers/
│   │       └── history_providers.dart
│   ├── home/
│   │   ├── domain/
│   │   │   └── cooldown_engine.dart
│   │   ├── presentation/
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/
│   │   │       ├── quick_mealview.dart
│   │   │       ├── quick_actions.dart
│   │   │       └── spin_wheel_dialog.dart
│   │   └── providers/
│   │       └── recommendation_provider.dart
│   ├── settings/
│   │   ├── presentation/
│   │   │   └── settings_screen.dart
│   │   └── providers/
│   │       └── settings_providers.dart
│   └── vault/
│       ├── presentation/
│       │   ├── add_edit_meal_dialog.dart
│       │   ├── meal_vault_screen.dart
│       │   └── widgets/
│       └── providers/
│           └── vault_providers.dart
└── main.dart

test/
├── unit/
│   ├── cooldown_engine_test.dart
│   └── database_test.dart
├── widget/
│   ├── rtl_layout_test.dart
│   └── riverpod_reactivity_test.dart
└── e2e/
    └── full_flow_test.dart
```

## UI State vs. Persisted State (tab lifecycle)

`StatefulShellRoute.indexedStack` keeps every branch alive, which is what makes
the Meal Vault keep its position — but it also means screens would otherwise
keep their scroll offsets forever. The split is explicit:

| Screen | On leaving + returning to the tab |
|---|---|
| Home | UI state reset (scroll offset) — data untouched |
| History | UI state reset (scroll offset) — data untouched |
| Settings | UI state reset (scroll offset) — data untouched |
| Meal Vault | **Nothing** is reset: selected internal tab, grid offset and the Explore browsing state all survive |
| Vault → "My Vault" (internal switch) | That tab's UI resets (search text + filter chips) |
| Vault → "Explore" (internal switch) | Kept alive, never rebuilt |

* `activeNavBranchProvider` (`lib/core/navigation/nav_lifecycle.dart`) is the
  single signal a screen uses to know it was re-entered.
* `NavBranchReentry` is the mixin screens apply: declare `navBranchIndex`,
  implement `resetTransientUi()`, call `watchNavReentry()` first in `build`.
* **Resetting UI state must never invalidate a data provider** — that is what
  would lose settings or cause a loading flicker. `vaultFilterProvider` is the
  one exception and it is safe because it holds only transient filter/search
  state, never database rows.

## Localisation contract

* Every user-facing string lives in `lib/core/localization/app_strings.dart`
  (`AppStrings`), with an Arabic and an English variant. No literals in widgets.
* The domain/data layers carry **no display copy**. `CooldownEngine` reports a
  `relaxationLevel` + `isEmptyVault` flag; `AdminAuthService` reports an
  `AdminAuthFailure` code; `DiscoveryRepository` throws `CloudMealsFetchException`.
  The UI maps those to localised text.
* Enum labels are resolved through `AppStrings` (`ProteinType.label(strings)`,
  `CarbsType.label(strings)`, `MealCategory.label(strings)`,
  `MealEntryType.label(strings)`). `labelArabic` remains as a locale-free
  convenience for seed data and logs.
* Exceptions that are *data*, not copy: meal names from the database
  (`meal.name`) and the character-folding tables in
  `lib/core/utils/arabic_normalizer.dart` — localising the latter would break
  Arabic search.

### Verifying without the Flutter SDK

`tool/check_localization.py` is a static consistency checker for environments
where the SDK/pub.dev are unreachable. It is **not** a compiler, but it operates
on the real sources and catches: unbalanced brackets, unresolved imports,
`strings.<member>` typos, duplicate `AppStrings` members (including the illegal
getter+method pair), `strings`/`context` used out of scope, references to removed
symbols, and un-localised Arabic literals.

```bash
python3 tool/check_localization.py   # exit code 0 == all checks passed
```

Run `flutter analyze` and `flutter test` as the authoritative gate.
