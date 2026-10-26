# UK Food database → Shop: English system foods

## Cause and scope

The UK Shop endpoint returned only separately reviewed retailer SKUs. The
general Catalogue already exposed 390 canonical system foods in English, but
the Shop tab did not reuse them. This was a read-path gap, not missing Polish
recipes or a reason to copy user submissions across markets.

The new client opts into `include_generic_foods=true`. The UK response appends
English system food references after reviewed retailer offers. A reviewed
offer for a canonical food replaces its generic fallback. Search, stable
pagination and country/account guards apply to both parts. PL retains the
existing StoreProduct path. Old clients retain the old response by default.

## Data honesty

- Reuse the existing 390 immutable system food identities/translations and
  nutrition. No user products/recipes, global OFF import, extra database rows,
  brand translation, SKU substitution, or fabricated store inventory.
- Generic rows are explicitly `generic_food_reference`, with unknown stock,
  no retail package and no Polish example brand or package weight.
- The existing reviewed ONS national references provide a labelled estimate
  per 100 g/ml for supported food categories only. They do not attest a shop
  price, package or availability. Expired/unsupported data remains null.
- Unknown price renders `Price unavailable`, never £0.00. Known retailer
  offers keep their independently reviewed GBP price and package.
- Display references use deterministic presentation IDs, not real offer IDs;
  the Shop list is read-only. Checkout/pricing never consume these as offers.
- No schema migration, external HTTP request, production database write or
  per-product SQL query is added to browsing. A page with generic foods takes
  three SELECTs in the HTTP regression fixture (store, offers, generic page).

## UI contract

Preserve the existing Flutter iOS/Android list, shop selector, search,
colours, navigation, scan actions and motion. Distinguish a generic food from
an actual shop SKU in text. On small screens/large text the reference price
moves below the food description to avoid broken words. At text scales above
130%, the existing contribution/scan header scrolls within a bounded height,
so it cannot push the product list off screen; no actions are removed.

Stark informed these limited data-state/containment decisions, not a redesign.
The 320 px / 150% screenshot was inspected and the initially cramped reference
row repaired and rendered again. This is widget evidence, not a device test.

## Verification and release

Regression tests cover all 390 system foods, all ten UK shops, search,
pagination, literal percent signs, real-offer preference, expired estimates,
authored/scanned/pending/renamed exclusions, read-only/query count, old-client
compatibility, PL prices, nullable data parsing and enlarged-text rendering.
Fresh command outputs are recorded in `docs/audit/uk-shop-*-20261026.txt`.

Verified results on 2026-10-26:

- Full backend suite: 3547 passed, 45 warnings. The final refined shop
  implementation plus two additional expiry/query-count tests: 25 passed.
- Full Flutter suite after the release-notice correction: 1146 passed.
  Enlarged-text/font-render shop and parser/service tests: 21 passed.
  Final update-notice assertions in PL/EN: 2 passed.
- Full Flutter analysis: no errors or warnings, 385 informational diagnostics.
  Final changed-file analysis: no errors or warnings, 7 informational
  diagnostics (existing deprecations/context advice).
- Scoped `git diff --check`: passed; changed deliverable text normalized to LF.

Changes remain local. No Render deploy, GitHub push, production/Neon mutation,
new package or native Android/iOS build was performed for this change. The
existing 1.0.73+274 delivery ZIP is unchanged. A future package needs the user's
current Codespace snapshot and an unused build number. Both API and app must
be updated to activate the opt-in Shop extension. Update-notice copy includes
the English foods in UK shops in both PL and EN.

Pre-change key files were copied to the sibling workspace directory
`backups/uk-shop-catalogue-20261026/` before editing.
