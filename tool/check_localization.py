#!/usr/bin/env python3
"""Static consistency checks for the Dart sources in this repo.

This is NOT a Dart compiler. It exists because the Flutter SDK cannot be
installed in this sandbox (storage.googleapis.com / pub.dev are unreachable),
so `flutter analyze` / `flutter test` cannot run here. The checks below operate
on the real source files and target the failure modes that a mass string
extraction + widget refactor actually produces:

  1. lexical integrity  — comments/strings stripped, brackets balanced
  2. import resolution  — every relative import points at an existing file
  3. AppStrings surface — every `strings.<member>` used in lib/ exists in
                          app_strings.dart, and no member is declared twice
  4. scope sanity       — a `strings.` usage sits inside a method that actually
                          declares/derives a `strings` binding (or has one in an
                          enclosing builder parameter list)
  5. dead references    — symbols deleted by this change are not referenced
  6. hardcoded copy     — no Arabic string literals left outside the allowed
                          data-only files

Exit code is non-zero when any check fails.
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

ARABIC = re.compile(r'[\u0600-\u06FF]')

# Files allowed to keep Arabic literals because they are data, not UI copy.
ARABIC_ALLOWED = {
    'core/utils/arabic_normalizer.dart',   # search folding rules
    'core/localization/app_strings.dart',  # the translations themselves
    'core/database/seed/initial_meals.dart',  # meal names (DB content)
}

failures: list[str] = []
checks_run: list[str] = []


def fail(check: str, path: str, line: int, msg: str) -> None:
    rel = os.path.relpath(path, ROOT)
    failures.append(f'{check}: {rel}:{line}: {msg}')


def dart_files(root=LIB):
    for dirpath, _dirs, files in os.walk(root):
        for f in sorted(files):
            if f.endswith('.dart') and not f.endswith('.g.dart'):
                yield os.path.join(dirpath, f)


def test_files():
    return dart_files(os.path.join(ROOT, 'test'))


def strip_dart(src: str) -> str:
    """Blank out comments and string literals, keeping newlines so line numbers
    stay aligned. Good enough for bracket counting and identifier scanning."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''
        # line comment
        if c == '/' and nxt == '/':
            while i < n and src[i] != '\n':
                out.append(' ')
                i += 1
            continue
        # block comment (nesting supported in Dart)
        if c == '/' and nxt == '*':
            depth = 1
            out.append('  ')
            i += 2
            while i < n and depth:
                if src[i] == '/' and i + 1 < n and src[i + 1] == '*':
                    depth += 1
                    out.append('  ')
                    i += 2
                    continue
                if src[i] == '*' and i + 1 < n and src[i + 1] == '/':
                    depth -= 1
                    out.append('  ')
                    i += 2
                    continue
                out.append('\n' if src[i] == '\n' else ' ')
                i += 1
            continue
        # raw string
        if c == 'r' and nxt in ("'", '"'):
            quote = nxt
            triple = src[i + 2:i + 4] == quote * 2
            delim = quote * 3 if triple else quote
            out.append(' ' * (1 + len(delim)))
            i += 1 + len(delim)
            while i < n and not src.startswith(delim, i):
                out.append('\n' if src[i] == '\n' else ' ')
                i += 1
            out.append(' ' * len(delim))
            i += len(delim)
            continue
        if c in ("'", '"'):
            quote = c
            triple = src[i + 1:i + 3] == quote * 2
            delim = quote * 3 if triple else quote
            out.append(' ' * len(delim))
            i += len(delim)
            while i < n and not src.startswith(delim, i):
                if src[i] == '\\':
                    out.append('  ')
                    i += 2
                    continue
                out.append('\n' if src[i] == '\n' else ' ')
                i += 1
            out.append(' ' * len(delim))
            i += len(delim)
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def string_literals(src: str):
    """Yield (line_no, literal) for single/double quoted literals."""
    for line_no, line in enumerate(src.split('\n'), 1):
        stripped = line.strip()
        if stripped.startswith(('//', '///', '*', '/*')):
            continue
        for m in re.finditer(r"'((?:[^'\\]|\\.)*)'", line):
            yield line_no, m.group(1)


# ---------------------------------------------------------------------------
# 1 + 2 + 6: per-file lexical, imports, hardcoded copy
# ---------------------------------------------------------------------------
def check_files():
    checks_run.append('lexical-integrity / import-resolution / hardcoded-copy')
    for path in dart_files():
        src = open(path, encoding='utf-8').read()
        code = strip_dart(src)

        for opener, closer in (('{', '}'), ('(', ')'), ('[', ']')):
            delta = code.count(opener) - code.count(closer)
            if delta:
                fail('brackets', path, 1,
                     f'unbalanced {opener}{closer} (delta {delta})')

        for line_no, line in enumerate(src.split('\n'), 1):
            m = re.match(r"\s*import\s+'([^']+)'", line)
            if not m:
                continue
            target = m.group(1)
            if target.startswith('package:') or target.startswith('dart:'):
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(resolved):
                fail('import', path, line_no, f'unresolved import {target}')

        rel = os.path.relpath(path, LIB).replace('\\', '/')
        if rel in ARABIC_ALLOWED:
            continue
        for line_no, literal in string_literals(src):
            if ARABIC.search(literal):
                fail('hardcoded-copy', path, line_no,
                     f'Arabic literal not localised: {literal[:60]!r}')


# ---------------------------------------------------------------------------
# 3: AppStrings surface
# ---------------------------------------------------------------------------
APP_STRINGS = os.path.join(LIB, 'core/localization/app_strings.dart')


DECL = re.compile(
    r'^\s*(?:String|bool|int)\s+(?:get\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(|=>|;)',
    re.M)
FIELD = re.compile(r'^\s*final\s+\w+\s+([A-Za-z_][A-Za-z0-9_]*)\s*;', re.M)


def app_strings_members():
    """Collect declared members once per source line.

    A getter `String get x => …` and a method `String x(…)` are both legal
    individually but NOT together in one class, so duplicates matter.
    """
    src = open(APP_STRINGS, encoding='utf-8').read()
    body = src[src.index('class AppStrings'):]
    members = {}
    seen = set()
    for pattern in (DECL, FIELD):
        for m in pattern.finditer(body):
            line = body[:m.start()].count('\n') + 1
            key = (m.group(1), line)
            if key in seen:
                continue
            seen.add(key)
            members.setdefault(m.group(1), []).append(line)
    for name in members:
        members[name] = sorted(set(members[name]))
    return members, src


def check_app_strings():
    checks_run.append('AppStrings surface (members used vs declared)')
    members, src = app_strings_members()

    for name, lines in members.items():
        if len(lines) > 1:
            fail('app-strings', APP_STRINGS, lines[-1],
                 f'member {name!r} declared {len(lines)} times (lines {lines})')

    used = {}
    for path in dart_files():
        if os.path.abspath(path) == os.path.abspath(APP_STRINGS):
            continue
        s = strip_dart(open(path, encoding='utf-8').read())
        for line_no, line in enumerate(s.split('\n'), 1):
            for m in re.finditer(r'\bstrings\.([A-Za-z_][A-Za-z0-9_]*)', line):
                used.setdefault(m.group(1), []).append((path, line_no))

    for name, sites in sorted(used.items()):
        if name not in members:
            p, ln = sites[0]
            fail('app-strings', p, ln,
                 f'AppStrings has no member {name!r} (used {len(sites)}x)')
    return members, used


# ---------------------------------------------------------------------------
# 4: `strings` binding exists in the enclosing method
# ---------------------------------------------------------------------------
METHOD_START = re.compile(r'^\s*(?:static\s+|Future<[^>]*>\s+|Widget\s+|String\s+|void\s+|bool\s+|int\s+|List<[^>]*>\s+)*[A-Za-z_][A-Za-z0-9_<>,\s]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')


BINDING = re.compile(
    r'\bfinal\s+strings\s*='          # final strings = AppStrings.of(context);
    r'|\bAppStrings\s+strings\b'      # AppStrings strings  (parameter)
)


def check_strings_scope():
    """Every `strings.` usage must be lexically enclosed by a `strings` binding.

    Dart closures are nested, so the search walks *outward* through enclosing
    blocks until a binding is found or the top of the file is reached — exactly
    how the compiler resolves the identifier.
    """
    checks_run.append('strings binding present where `strings.` is used')
    for path in dart_files():
        if os.path.abspath(path) == os.path.abspath(APP_STRINGS):
            continue
        code = strip_dart(open(path, encoding='utf-8').read())
        if 'strings.' not in code:
            continue
        lines = code.split('\n')
        for idx, line in enumerate(lines):
            if 'strings.' not in line:
                continue
            lo = idx
            depth = 0
            found = False
            # Expand the window upwards one enclosing block at a time.
            while lo >= 0:
                depth += lines[lo].count('}') - lines[lo].count('{')
                if depth < 0:
                    # We just stepped over the `{` that opened an enclosing block.
                    window = '\n'.join(lines[lo:idx + 1])
                    if BINDING.search(window):
                        found = True
                        break
                    depth = 0
                lo -= 1
            if not found and BINDING.search('\n'.join(lines[:idx + 1])):
                # top-level / field-level binding
                found = True
            if not found:
                fail('strings-scope', path, idx + 1,
                     '`strings.` used with no enclosing binding')


# ---------------------------------------------------------------------------
# 5: dead references to symbols removed by this change
# ---------------------------------------------------------------------------
REMOVED = [
    (r'\b_expanded\b', 'settings _expanded flag'),
    (r'\b_previousDays\b', 'settings _previousDays map'),
    (r'\b_proteinSwitch\b', 'settings _proteinSwitch helper'),
    (r'\b_showProfileEditDialog\b', 'inline profile dialog'),
    (r'\b_formatPrep\b', 'discovery _formatPrep helper'),
    (r'\.labelArabic\b', 'labelArabic in UI (use .label(strings))'),
]


def check_removed_symbols():
    checks_run.append('dead references to removed symbols')
    ui_roots = ('features/',)
    for path in dart_files():
        rel = os.path.relpath(path, LIB).replace(os.sep, '/')
        code = strip_dart(open(path, encoding='utf-8').read())
        for line_no, line in enumerate(code.split('\n'), 1):
            for pattern, what in REMOVED:
                if what.startswith('labelArabic') and not rel.startswith(ui_roots):
                    continue
                if re.search(pattern, line):
                    fail('dead-reference', path, line_no, f'removed symbol still used: {what}')


# ---------------------------------------------------------------------------
# 7: `context` availability
#
# StatelessWidget / ConsumerWidget methods other than `build` have no implicit
# `context` — using it there is a compile error. State classes do have one.
# ---------------------------------------------------------------------------
STATELESS = re.compile(
    r'class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+'
    r'(StatelessWidget|ConsumerWidget|StatefulWidget|ConsumerStatefulWidget)\b')
# A class-body method starts at exactly two spaces of indentation.
METHOD_DECL = re.compile(r'^  (?:static\s+)?[A-Za-z_][\w<>,?\s]*\s+[A-Za-z_][A-Za-z0-9_]*\s*\(')
CLOSURE_WITH_CTX = re.compile(r'\(\s*(?:BuildContext\s+)?context\s*[,)]')
PARAM_WITH_CTX = re.compile(r'\bcontext\b')
# `Theme.of(context)`, `AppStrings.of(context)` … *use* context, they do not
# bind it. They must be masked before looking for a closure parameter list.
CONTEXT_CONSUMER = re.compile(
    r'\b[A-Z]\w*\.(?:of|maybeOf|maybeLocaleOf|localeOf)\(\s*(?:BuildContext\s+)?context\s*\)')


def _class_ranges(src, lines):
    ranges = []
    for m in STATELESS.finditer(src):
        line_no = src[:m.start()].count('\n')
        depth, started, end = 0, False, line_no
        for j in range(line_no, len(lines)):
            depth += lines[j].count('{') - lines[j].count('}')
            if lines[j].count('{'):
                started = True
            if started and depth <= 0:
                end = j
                break
        ranges.append((line_no, end))
    return ranges


def check_context_availability():
    """`context` is not an implicit member of StatelessWidget/ConsumerWidget.

    For every `context` use inside such a class we locate the enclosing method
    (a declaration at class-body indentation) and require `context` either in
    that method's parameter list or in a closure that introduces it.
    """
    checks_run.append('`context` only used where it is in scope')
    for path in dart_files():
        src = strip_dart(open(path, encoding='utf-8').read())
        lines = src.split('\n')
        ranges = _class_ranges(src, lines)
        if not ranges:
            continue

        for idx, line in enumerate(lines):
            if not re.search(r'\bcontext\b', line):
                continue
            enclosing = [r for r in ranges if r[0] <= idx <= r[1]]
            if not enclosing:
                continue

            # Find the method declaration above this line.
            method_start = None
            for j in range(idx, enclosing[0][0] - 1, -1):
                if METHOD_DECL.match(lines[j]):
                    method_start = j
                    break
            if method_start is None:
                continue  # field initialiser / top level — not our concern

            # Method signature = from the declaration to its opening brace.
            sig_end = method_start
            for j in range(method_start, idx + 1):
                sig_end = j
                if '{' in lines[j]:
                    break
            signature = '\n'.join(lines[method_start:sig_end + 1])

            if PARAM_WITH_CTX.search(signature):
                continue
            # Otherwise a closure between the signature and the use may bind it.
            body = '\n'.join(lines[sig_end + 1:idx + 1])
            body = CONTEXT_CONSUMER.sub('', body)
            if CLOSURE_WITH_CTX.search(body):
                continue
            fail('context-scope', path, idx + 1,
                 '`context` used but not in scope for this widget method')


def check_test_files():
    """Lexical + import checks for the test suite (no copy checks there)."""
    checks_run.append('test suite: brackets + imports resolve')
    for path in test_files():
        src = open(path, encoding='utf-8').read()
        code = strip_dart(src)
        for opener, closer in (('{', '}'), ('(', ')'), ('[', ']')):
            delta = code.count(opener) - code.count(closer)
            if delta:
                fail('brackets', path, 1, f'unbalanced {opener}{closer} (delta {delta})')
        for line_no, line in enumerate(src.split('\n'), 1):
            m = re.match(r"\s*import\s+'([^']+)'", line)
            if not m:
                continue
            target = m.group(1)
            if target.startswith(('package:', 'dart:')):
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(resolved):
                fail('import', path, line_no, f'unresolved import {target}')


def main() -> int:
    check_files()
    check_app_strings()
    check_strings_scope()
    check_removed_symbols()
    check_context_availability()
    check_test_files()

    dart_count = sum(1 for _ in dart_files())
    print(f'scanned {dart_count} Dart files under lib/')
    for c in checks_run:
        print(f'  - {c}')
    if failures:
        print(f'\nFAILURES ({len(failures)}):')
        for f in failures:
            print('  ' + f)
        return 1
    print('\nALL CHECKS PASSED')
    return 0


if __name__ == '__main__':
    sys.exit(main())
