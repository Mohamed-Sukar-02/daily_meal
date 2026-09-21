#!/usr/bin/env python3
"""Static audit substituting for `flutter analyze` (no Flutter SDK in sandbox).

Checks, for every file touched/created by this mission:
  1. Brace / paren / bracket balance (string- and comment-aware).
  2. Import resolution: relative imports must exist on disk; `package:` imports
     must be declared in pubspec.yaml (or be flutter/sdk/daily_meal itself).
  3. Cross-file symbol references used by the new/modified code:
       - AppGlyph.cloudUp declared in the enum AND handled in the painter.
       - Every `strings.<name>` used in touched files exists in AppStrings.
       - Providers referenced by new files exist in their source files.
  4. Widget-key uniqueness across lib/ (duplicate Key('x') = test ambiguity).
  5. Firestore-rules parity: every key literal produced by
     MealProposalPayload.build must be inside isValidStagingMeal's allow-list,
     and every required key must be producible.

Exit code 0 = all green. Any FAIL prints a diagnostic.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

TOUCHED = [
    "lib/features/vault/application/meal_proposal_service.dart",
    "lib/features/meals/presentation/quick_meal_view.dart",
    "lib/features/meals/presentation/meal_screen.dart",
    "lib/features/vault/presentation/widgets/meal_details_sheet.dart",
    "lib/core/localization/app_strings.dart",
    "lib/core/widgets/app_icons.dart",
    "lib/core/router/app_router.dart",
    "lib/main.dart",
    "lib/features/vault/presentation/meal_vault_screen.dart",
    "test/unit/meal_proposal_payload_test.dart",
    "test/widget/meal_details_sheet_actions_test.dart",
]

failures = []
warnings = []


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def strip_noise(src):
    """Remove comments and string/char literals so balance checks are honest."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
        elif c in "'\"":
            quote = c
            triple = src[i : i + 3] == quote * 3
            delim = quote * 3 if triple else quote
            i += len(delim)
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src.startswith(delim, i):
                    i += len(delim)
                    break
                i += 1
            out.append('""')  # placeholder token
        elif c == "$":
            # interpolation: keep braces of ${...} by skipping the $ only
            i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def check_balance(path):
    src = strip_noise(read(path))
    pairs = {"}": "{", ")": "(", "]": "["}
    stack = []
    line = 1
    for ch in src:
        if ch == "\n":
            line += 1
        elif ch in "{([":
            stack.append((ch, line))
        elif ch in "}])":
            if not stack or stack[-1][0] != pairs[ch]:
                failures.append(f"{path}: unbalanced '{ch}' at line ~{line}")
                return
            stack.pop()
    if stack:
        failures.append(f"{path}: unclosed '{stack[-1][0]}' opened line ~{stack[-1][1]}")


def check_imports(path):
    src = read(path)
    pubspec = read("pubspec.yaml")
    deps = set(re.findall(r"^\s{2}([a-z0-9_]+):\s*[\^0-9]", pubspec, re.M))
    deps |= {"flutter", "flutter_localizations", "flutter_test", "daily_meal"}
    base_dir = os.path.dirname(os.path.join(ROOT, path))
    for m in re.finditer(r"import\s+'([^']+)'", src):
        imp = m.group(1)
        if imp.startswith("dart:"):
            continue
        if imp.startswith("package:"):
            pkg = imp.split("/")[0][len("package:") :]
            if pkg not in deps:
                failures.append(f"{path}: package '{pkg}' not in pubspec deps")
        else:
            target = os.path.normpath(os.path.join(base_dir, imp))
            if not os.path.isfile(target):
                failures.append(f"{path}: relative import missing → {imp}")


def check_glyph():
    src = read("lib/core/widgets/app_icons.dart")
    enum_block = re.search(r"enum AppGlyph \{(.*?)\}", src, re.S).group(1)
    values = [v.strip() for v in enum_block.split(",") if v.strip()]
    cases = set(re.findall(r"case AppGlyph\.(\w+):", src))
    for v in values:
        if v not in cases:
            failures.append(f"app_icons.dart: AppGlyph.{v} has no painter case")
    if "cloudUp" not in values:
        failures.append("app_icons.dart: cloudUp missing from AppGlyph enum")
    if "cloudUp" not in cases:
        failures.append("app_icons.dart: painter missing case AppGlyph.cloudUp")


def check_strings():
    strings_src = read("lib/core/localization/app_strings.dart")
    getters = set(re.findall(r"String get (\w+)", strings_src))
    getters |= set(re.findall(r"String (\w+)\(", strings_src))
    used = set()
    for path in TOUCHED:
        if not path.startswith("lib/"):
            continue
        # `(?<![\w_])` skips `app_strings.dart` in imports; `.dart` guard too.
        for m in re.finditer(r"(?<![\w_])strings\.(\w+)", read(path)):
            if m.group(1) != "dart":
                used.add((path, m.group(1)))
    missing = [(p, g) for (p, g) in used if g not in getters]
    for p, g in sorted(missing):
        failures.append(f"{p}: strings.{g} not defined in AppStrings")


def check_provider_refs():
    service = read("lib/features/vault/application/meal_proposal_service.dart")
    network = read("lib/core/providers/network_provider.dart")
    for sym in ("cloudAccessStatusFutureProvider", "CloudAccessStatus"):
        if sym not in network:
            failures.append(f"network_provider.dart: expected symbol {sym} missing")
        if sym not in service:
            failures.append(f"meal_proposal_service.dart: should reference {sym}")
    vault = read("lib/features/vault/providers/vault_providers.dart")
    screen = read("lib/features/meals/presentation/meal_screen.dart")
    for sym in ("allMealsProvider", "vaultControllerProvider"):
        if sym not in vault:
            failures.append(f"vault_providers.dart: {sym} missing")
        if sym not in screen:
            failures.append(f"meal_screen.dart: expected reference to {sym}")
    # toggleFavorite must exist on the vault controller used by meal_screen
    if "toggleFavorite" not in vault:
        failures.append("vault_providers.dart: VaultController.toggleFavorite missing")
    # go_router route + push targets must agree
    router = read("lib/core/router/app_router.dart")
    if "path: '/meal/:id'" not in router:
        failures.append("app_router.dart: /meal/:id route missing")
    sheet = read("lib/features/vault/presentation/widgets/meal_details_sheet.dart")
    if "router.push('/meal/" not in sheet:
        failures.append("meal_details_sheet.dart: full-details push missing")


def check_keys_unique():
    keys = {}
    # Constructor-style widget keys only: excludes containsKey('X'), map['x'],
    # generated drift code (.g.dart) and interpolated runtime-unique keys (${…}).
    key_re = re.compile(r"(?<![A-Za-z0-9_$])(?:ValueKey|GlobalKey|Key)\('([^'$]+)'\)")
    for dirpath, _, files in os.walk(os.path.join(ROOT, "lib")):
        for fn in files:
            if not fn.endswith(".dart") or fn.endswith(".g.dart"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT)
            for m in key_re.finditer(read(rel)):
                keys.setdefault(m.group(1), []).append(rel)
    for k, files in keys.items():
        if len(set(files)) > 1:
            failures.append(f"duplicate widget key '{k}' in: {', '.join(sorted(set(files)))}")


def check_rules_parity():
    rules = read("firestore.rules")
    allowed = set()
    m = re.search(r"allowedKeys = \[(.*?)\]", rules, re.S)
    if not m:
        failures.append("firestore.rules: allowedKeys block not found")
        return
    allowed = set(re.findall(r"'([^']+)'", m.group(1)))
    m = re.search(r"requiredKeys = \[(.*?)\]", rules, re.S)
    required = set(re.findall(r"'([^']+)'", m.group(1)))

    service = read("lib/features/vault/application/meal_proposal_service.dart")
    build = re.search(r"static Map<String, dynamic>\? build\((.*?)\n  \}\n", service, re.S)
    if not build:
        failures.append("service: build() body not located for parity check")
        return
    body = build.group(1)
    produced = set(re.findall(r"'(\w+)':", body))
    illegal = produced - allowed
    if illegal:
        failures.append(f"payload produces keys outside rules allow-list: {illegal}")
    missing_required = required - produced
    if missing_required:
        failures.append(f"payload missing REQUIRED rules keys: {missing_required}")
    if "'shortName'" in body:
        failures.append("payload builder references shortName (forbidden by rules)")
    # status must be the literal 'pending'
    if "'status': 'pending'" not in body:
        failures.append("payload status literal must be 'pending'")


def check_storage_rules():
    rules = read("storage.rules")
    if "staging_meal_images/{uid}" not in rules:
        failures.append("storage.rules: staging_meal_images/{uid} path missing")
    if "request.auth.uid == uid" not in rules:
        failures.append("storage.rules: staging path must pin uid")
    if "500 * 1024" not in rules:
        failures.append("storage.rules: staging path must cap at 500KB")
    # the service must upload under the same path shape
    service = read("lib/features/vault/application/meal_proposal_service.dart")
    if "staging_meal_images/$uid/" not in service:
        failures.append("service upload path does not match storage.rules shape")


def main():
    for path in TOUCHED:
        if not os.path.isfile(os.path.join(ROOT, path)):
            failures.append(f"MISSING FILE: {path}")
            continue
        check_balance(path)
        check_imports(path)
    check_glyph()
    check_strings()
    check_provider_refs()
    check_keys_unique()
    check_rules_parity()
    check_storage_rules()

    print("=" * 64)
    print("STATIC AUDIT — mission_cloud_export_2026_09_21")
    print("=" * 64)
    for w in warnings:
        print(f"WARN  {w}")
    if failures:
        for f in failures:
            print(f"FAIL  {f}")
        print(f"\nRESULT: {len(failures)} FAILURE(S)")
        sys.exit(1)
    print(f"checked {len(TOUCHED)} touched files + rules parity + key uniqueness")
    print("\nRESULT: PASS (0 failures)")
    sys.exit(0)


if __name__ == "__main__":
    main()
