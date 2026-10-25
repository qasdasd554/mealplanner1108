# Stage 19 verification — 22 October 2026

## Fresh final results

| Check | Result | Evidence at repository root |
| --- | --- | --- |
| Complete Flutter suite | 663 passed, exit 0, 1 min 44 sec | `uk-stage19-flutter-final.log` |
| Flutter analyze `--no-pub --no-fatal-infos` | exit 0; 0 errors, 0 warnings, 363 info diagnostics | `uk-stage19-analyze-final.log` |
| Targeted screens and insight unit tests | 38 passed (36 new tests and 2 existing weekly tests) | `uk-stage19-expanded.log` |
| Whitespace | `git diff --check` exit 0 after UTF-8/LF normalization | `uk-stage19-whitespace-final.log` |
| Dart format | owned Dart files formatted; final no-change check below | verification command |

This stage changed no backend code. To save redundant work, the unchanged backend suite was not rerun: the latest backend result is the stage 18 run of 1396 passed with 41 deprecation warnings, not a new stage 19 result. The frontend was fully retested because its shared generated localization and provider code changed.

## Regression and parity evidence

- First targeted run: 7 passed, 7 failed; six English-localization failures plus one existing late-promotion-response-after-clear defect. Root cause: the provider updated its state after an awaited request without invalidating requests on clear/dispose. The new guard follows the existing StoreProvider generation mechanism.
- Screens: PL/en-GB ranking tabs/counts/nicknames, per-tab retry, empty tabs, statistics retry, untouched favourite user-entered meal, Standard preview versus full Premium insights, daily dates/macros/water, statistics scrolling at 320 px and 150% text, promotion empty states, Polish store filtering with exact legacy PLN amounts, ad failure/retry/cancel and completion values.
- Providers: response after clear is discarded; a newer request wins over an older reply without extra requests; localized error can retry; successful cached store loading retains the existing request count.
- Insights: all branch fixtures preserve numeric counts/averages, seven-day filtering, kind order, integer water average, weight threshold and sign. Explicit Polish labels match the legacy default; English text changes no numeric values.
- A generator failure from unsupported exact plural cases was corrected in the localization implementation, not by changing count semantics. The original Polish noun-selection rule is retained explicitly, with English singular/plural labels.

Independent read-only review found no concrete new regression in the final diff. It checked original PL text, calculations/grouping, date patterns, Premium/ad semantics and the promotion-provenance boundary. The full suite and analysis were then confirmed by the root agent.

## Limitations and release boundary

These are widget/unit tests and static review, not real device captures or a native accessibility/camera/billing/advertisement certification. No new visual design or responsive replacement was introduced. Native advertising remains disabled.

The GB promotions API still returns an empty list because the current promotion rows/sources are legacy PLN-only. This stage does not solve UK promotion data sourcing or falsely advertise Polish offers in pounds. Wider UK product/recipe coverage, system recipe/tip translations, remaining screen/admin/email/push/document localization, and native/store testing remain separate unfinished work.

The current localized update notice from stage 17 is retained, including its stability/readability bullet; no claim of a completed UK release is added. No release bump, production database access, migration, ZIP/AAB/IPA, push or deployment. Version **1.0.66+267**, default **UK_MARKET_ENABLED=False**.
