# worker_perf — changes & reasoning

## Applied (zero-risk, high-confidence)
1. **Image cache budget** (lib/main.dart): stock cache = 1000 imgs / 100 MB. A 720px-wide
   decoded frame ≈ 720×720×4 B ≈ 2 MB → ~50 photos evict the cache; scrolling a large vault
   back-and-forth re-decodes JPEGs on the UI isolate = the app's most likely jank source.
   Raised to 1200 imgs / 200 MB via the WidgetsFlutterBinding instance (typed access, no new
   imports). Bounded by design: every MealImage call site passes cacheWidth (720 sheet /
   900 full-screen hero / grid thumbs), so entries stay proportional; 200 MB is native-side
   (ui.Image), outside the Dart heap, and typical of photo-heavy production apps.
2. **Repaint isolation** (meal_vault_screen.dart): grid + list itemBuilders wrap each card in
   RepaintBoundary → ink splashes / heart-toggle animations repaint one card instead of the
   whole sliver. Finder-transparent (no test impact — see tester_regression).
3. **No re-rank on favourite** (verified, not changed): pinned-notifier eligibility key is
   blind to meal fields → liking never triggers engine.compute(); the *perception* of speed on
   the home tab is preserved by design (already covered by recommendation_variety_test).
4. **New-code hygiene**: const constructors everywhere legal (QuickMealView pills/badges,
   buttons, paddings); photo decode budgets on new surfaces (cacheWidth 720/900); proposal
   spinner state is a single StateProvider<int?> (no provider-list churn during upload);
   `runProposalFlow` reuses the 30s reachability cache (`_reachabilityCache`) — rapid taps
   don't stack 2s socket probes.

## Deliberately NOT done (documented as recommendations)
- **Bundling Cairo font**: google_fonts fetches at first runtime and falls back offline —
  real offline-first/TTI issue, but bundling needs the font binaries (network-blocked
  sandbox). → ISSUES.md open item.
- **Pre-caching vault thumbs / precacheImage**: speculative without profiling data.
- **Isolate-offloaded filtering** (arabic_normalizer per keystroke): O(n) over ≤ few hundred
  meals is sub-millisecond; complexity not justified.
- **Home card-stack RepaintBoundary**: home list is short (3 cards + banner); churn risk
  against the most-tested screen outweighs the marginal gain.
