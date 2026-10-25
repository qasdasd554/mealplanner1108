# Stage 7 evidence — diary entry and barcode UI

2026-10-19; local code only. UK remains disabled and the version remains
`1.0.66+267`. No production database operation, release, push or package.

## Implemented scope

- Translate the existing AddFoodEntryScreen tabs, plan/recipe guidance,
  recipe search/log sheet, recent-entry labels and shared catalogue picker.
  Author-written names remain unchanged. Meal/measure API identifiers remain
  Polish canonical codes; only their presentation is English.
- Translate single/batch camera controls, manual-code prompts, lookup/result/
  retry statuses, batch Premium preview and the multi-destination sheet.
  Source macro labels use P/F/C in English, retaining B/T/W in Polish.
- English picked amounts retain the original numerical quantity and physical
  unit, e.g. 2 packs of 500 ml; this is not a density/cup/FX conversion.
  The batch's stored package descriptor is localised while the structured
  `amount_unit=opak` stays unchanged. Default Polish payloads remain compatible.
- The destination selector remains multi-select. One choice still applies
  to the entire batch; no automatic pantry-only default has been added.
  Without a credible whole-pack size the pantry hint asks for g/ml instead
  of promising to save an invented package.
- Optional service/controller injection supports deterministic component
  tests. Existing production constructors and paths retain their defaults;
  no new runtime dependency, permission, network service or feature is added.

## Reproduced defects repaired

1. A late recipe search could overwrite a newer query. The diary recipe tab
   now invalidates older work on input and checks request generation.
2. Closing the manual barcode dialog disposed a controller still used during
   its reverse transition. Single and batch scanning now share one retained
   dialog helper. Cancel and Escape do not save anything.
3. An invalid typed GTIN closed the dialog and lost the user's input. Inline
   validation now preserves it for correction, uses the same checksum/
   normalisation rules and returns only the corrected exact GTIN.
4. Non-finite whole-pack sizes could qualify as known sizes. The batch gate
   requires finite positive g/ml sizes within the existing 100,000 g/ml
   product-submission limit. It does not silently invent a package.
5. A partial batch result with NaN kcal crashed integer rendering. Invalid
   nutrition now has a dash and remains in the existing incomplete-data path.
   Absent catalogue kcal also uses a dash rather than a manufactured zero.
6. The retained legacy ManualEntryForm accepted negative/NaN/Infinity values,
   and parsed a Polish decimal comma as zero. It now validates against the
   existing food-log schema, accepts decimal commas, retains values after
   failures and saves physical amount/unit metadata instead of a misleading
   gram suffix in the food name. Missing values from a new suggestion clear
   old values rather than inheriting another food's nutrition.
   **This component is not newly exposed in navigation**; the active Products
   diary tab continues to use the shared catalogue/amount picker.
7. At 320 px/150% text, the existing Premium-preview badge extended outside
   the screen in PL and EN. It now wraps within the same centred badge,
   preserving the usual style, colours and camera-panel composition.

## Fresh verification

- Full backend: `python -m pytest tests -q` — **981 passed**, 37 existing
  dependency/deprecation warnings, exit 0 (55.42 s), SQLite/mocks only.
- Full Flutter: `flutter test --no-pub` — **352 passed**, exit 0 (49 s).
- `flutter analyze --no-pub --no-fatal-infos` — exit 0, zero errors/warnings,
  333 non-fatal information/style diagnostics.
- PL/en/en_GB have 690 matching resource keys; generated localisation and
  coverage tests pass. This is still not every screen/flow of the app.
- New group: 30 tests — 11 diary-entry, 7 manual-scanner/package invariants,
  4 batch-flow, 2 destination-selector, 2 picked-amount and 4 preview-layout.
- Two manually entered simulated scans followed one three-destination
  confirmation. Each saved 1 pack, retained its 500 ml size and passed
  500 kcal / 25 g protein to the diary. No save occurred before confirmation.
- Regression evidence includes the actual disposed-controller stack,
  invalid-input loss, old-query replacement, decimal-comma zero, invalid
  batch nutrition rendering and off-screen badge bounds. One initial test
  fixture was corrected to use JSON's typed empty map before accepting the
  missing-nutrition assertion; a fixture type error is not product evidence.
- Evidence logs: `uk-stage7-*.log`. Preview PNGs in `evidence/` use the
  current light/dark theme, local Arial test font and MaterialIcons at
  320 x 740 / 150% text. They are test renders, not native screenshots.

## Scoped Stark acceptance

- Six task scenarios: empty plan guidance; repeat/search/select; invalid GTIN
  correction; Escape/cancel; touch multi-destination confirmation; missing/
  invalid nutrition and package data. Existing Premium gating is preserved.
- Four preview bounds tests failed before wrapping the badge and pass after.
  Inspected English light/dark and Polish light renders: heading, badge,
  scrollable content and bottom Premium action remain contained. No new
  visual system, icon set or motion is introduced.
- Error/server-failure tests retain typed data. Changing an invalid code
  needs correction, not reopening/re-entering the whole form.
- Component-level gate: acceptable with explicitly named native risk, not
  a declaration of full real-device usability or release readiness.
  Keyboard Escape is tested; VoiceOver/TalkBack, native focus visibility,
  real camera/permissions/lifecycle and a complete keyboard-only app journey
  have not been verified here.

## Remaining UK release work

The product submission/OCR screens still need localisation, as do remaining
account, Premium, admin/help and provider/server errors. External OFF/USDA
regional parameters, physical unit metadata for newly introduced catalogue
records, real reviewed UK offers, English content and time-zone behaviour
remain separate gates. The legacy shop-products endpoint is still not the
reviewed regional-SKU catalogue. These tests use fake lookup/service results,
not actual retailer stock or live camera recognition.

No AAB/IPA, real PostgreSQL/Neon migration or production purchase/trial test
was performed. Do not enable UK based only on these passing component tests.
