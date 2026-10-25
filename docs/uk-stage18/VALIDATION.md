# Stage 18 verification — 22 October 2026

Local continuation of UK parity; not a UK release.

## Fresh final results

| Check | Result | Evidence |
| --- | --- | --- |
| Full Flutter test suite | 627 passed, exit 0, 1 min 24 sec | `uk-stage18-flutter-final.log` at repository root |
| Backend `python -m pytest tests -q` | 1396 passed, exit 0; 41 existing deprecation warnings | `uk-stage18-backend.log` |
| Flutter analyze, `--no-pub --no-fatal-infos` | exit 0; 0 errors, 0 warnings, 364 info diagnostics | `uk-stage18-analyze-final.log` |
| Python compileall, app and tests | exit 0 | command output |
| Dart format, three screens and new test | 0 remaining changes | format verification |
| Locale key/placeholder parity | PL/en/en-GB agree for pantry/matching keys | read-only JSON comparison |
| Whitespace | `git diff --check` exit 0; owned sources UTF-8/LF | `uk-stage18-whitespace-final.log` |

The informational lint inventory remains; analysis is not represented as entirely clean. Backend was unchanged in this stage and the full backend suite was nevertheless rerun. No manual root-level database test scripts were collected.

## Regression evidence

`frontend/test/screens/recipes/pantry_match_market_test.dart`: 30 new tests in the final full suite.

- PL/en-GB canonical selected IDs, unchanged Premium gate and successful deletion refresh.
- Exact edited amounts in both g and ml; one whole known pack remains `quantity=1, unit=opak`, not a converted persisted amount.
- Localized retry on a failed load, preservation of ingredient names in AI prompts and the existing at-most-2-3-extra-ingredients allowance.
- Full and partial recipe cards at 320 px / 150% text, light and dark; exact recipe navigation.
- Failed overlapping removals restore without RangeError.
- Out-of-order searches, cleared queries and a failing new search do not expose obsolete results.
- Refreshes before/after deletion completion cannot resurrect the deleted row.
- A concurrent add is not lost when another deletion completes; re-adding the same canonical product with a fresh pantry-row UUID remains visible.
- Matching results and the AI fallback retain the originally submitted selection even if checkboxes change while waiting.

Red baselines are retained in `uk-stage18-pantry-red.log`, `uk-stage18-review-red.log` and `uk-stage18-review-race-red.log`. Test-harness compile/finder/equality corrections during expansion were not treated as production defects. An intermediate revision-guard regression was reproduced and replaced with per-row filtering before final verification.

## Independent review and visual evidence

Read-only subagent review checked the three screens, new tests and locale entries. Its two pre-existing asynchronous findings and one intermediate-implementation finding were reproduced and addressed. The final per-row variant had no further concrete regression identified by that review; the root agent then reran the complete suite.

Four inspected widget renders under `evidence/` cover PL/en-GB and light/dark at 320 x 740 / 150%. See [scope and visual limitations](SCOPE-AND-VALIDATION.md). These are local Flutter renders with a proof-only local font, not iOS/Android device captures or native accessibility certification.

## Still not performed / remaining UK work

No native AAB/IPA build, real camera/barcode/AI/IAP flow, store review, production database operation, push or deployment in this stage. UK expansion still has other content/screens and native/store validation pending; this report does not claim the whole UK rollout is finished.

Version remains **1.0.66+267**; default **UK_MARKET_ENABLED=False**. No ZIP was generated.
