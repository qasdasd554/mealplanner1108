# Stage 6 — products, the main diary and shared amount selection

Local work only, 2026-10-19. UK remains disabled and the release stays
`1.0.66+267`. No push, deploy, production query or ZIP is part of this stage.

## Scope and compatibility

- Localise the existing product screen (shop, catalogue and own submissions),
  its search/clear/retry/review labels, the reward banner and price-source help.
- Localise the main calorie diary, date heading, hydration/activity dialogs,
  entry amount editing and meal/amount display labels.
- Localise the shared amount sheet: pack, serving, item, teaspoon, glass,
  grams and millilitres, quick choices and nutrition previews.
- PL retains its labels and canonical API/storage values. English labels
  never change `opak/porcja/szt/lyzeczka/szklanka/g/ml` or Polish meal IDs.
  Author-written product, recipe, activity and brand names are not translated.
- Translating a glass does not turn it into a British/US cup. The physical
  amount is retained (for example 250 ml, or a reviewed 200 ml measure).
  An incompatible g/ml portion is discarded, not converted using assumed
  density. A known API measure wins over an approximate fallback; duplicate
  measure codes are no longer offered with conflicting quantities.
- The regular layout, theme and colours are unchanged. Error/empty product
  messages can scroll when little vertical space remains, including the
  initial loading transition on a narrow screen with larger text.

## Price provenance is not a currency conversion

`ProductResponse.submitted_country_code` exposes the existing submission
market column. The Flutter product DTO reads it, defaulting old responses
to PL. A user's submitted price follows the submission's country, not the
viewer or the phone language. Unsupported submission markets are not given
an invented price currency.

Legacy `StoreProductResponse` explicitly serialises PLN; its Flutter DTO
also defaults missing legacy currency to PLN. The product tab accepts rows
only for its selected store and matching supported currency, with finite,
non-negative prices. A PLN row cannot silently become a GBP offer in a GB
shop. Invalid data produces a visible unavailable/retry state, not a price.

This **does not connect the legacy shop-product endpoint to the reviewed
regional-SKU catalogue**. That endpoint must be integrated separately before
UK activation. No local prices or availability have been invented. An empty
UK shop is still an empty shop, not evidence of a complete catalogue.
These response additions require no additional database DDL in this stage.

## Reproduced failures and fixes

The first eight amount/diary widget tests had two passes and six failures:
English measure labels were absent, NaN/Infinity/overflowing exponents
reached integer calorie rendering, unknown nutrition appeared as zero and
closing the activity dialog disposed a still-mounted text controller.

- Reject non-finite, non-positive and excessive input before preview/save.
  Non-finite metadata cannot create a package or measure option.
- Render absent nutrient values as a dash, not a manufactured zero; known
  zero values are still numeric values. Existing nutrition completeness
  and source-validation rules are not relaxed.
- A local dialog controller is disposed only after the dialog's reverse
  transition completes. The shared retained-dialog helper keeps the normal
  root navigator, captured themes, dismissible barrier, safe area and
  closed-loop keyboard traversal. Activity, water and entry editing use it.
- Additional unit tests first reproduced a 77 g portion being rebuilt as
  77 ml, and duplicate glass choices. They pass after dimension validation
  and first-known-measure precedence.
- The product error/empty-state column overflow was reproduced at normal
  test height and at 320 px / 130% text, then fixed without shrinking text
  or redesigning the header.

## Evidence and remaining limits

- New Flutter group: 26 passing tests (6 products, 6 diary, 5 amount-sheet,
  9 measure/unit invariants), `uk-stage6-targeted-tests.log`.
- Full backend: 981 passing tests, 37 existing dependency/deprecation
  warnings, exit 0, local SQLite/mocks; `uk-stage6-backend-tests.log`.
- Full Flutter, analyser and l10n evidence is recorded in
  `../UK-EXPANSION.md` and the `uk-stage6-*.log` files.
- Product tests cover explicit GBP, rejecting PLN in a GBP store, unchanged
  PL price labels, GB vs legacy-PL submission currency, search/clear,
  unknown nutrients and narrow-screen rendering.
- Diary tests cover English dates/labels, both providers moving to the same
  selected day, unchanged PL labels, safe activity/water dialog close,
  invalid quantity rejection and 2 x 500 ml packs retaining canonical
  `opak` and correctly doubling calories.
- These are component/unit tests, not native screenshots, physical-phone
  testing, assistive-technology trials, an AAB/IPA or real PostgreSQL QA.
- This is not a full translation of every diary or product flow. The food
  entry form, barcode scanner/batch/destination flows, submission/OCR
  forms, provider/server errors and remaining account/premium/admin/help
  surfaces still need localisation. Regional OFF/USDA parameters, physical
  unit metadata for newly introduced products, time-zone behaviour and
  real reviewed UK product/store data remain release gates.
