# Stage 4 - UK shopping snapshots and mutations

Local implementation only. UK remains disabled; the release version, production
data, IAP and Polish product/package records are unchanged. Test products, prices
and retailer URLs are synthetic, not a ready UK assortment.

## Persisted boundary

The additive `shopping_list_item_regional_snapshots` table is one-to-one with a
legacy shopping-list item. It preserves the canonical product ID, GB store,
English SKU name, explicit required g/ml, the selected offer and a frozen JSON
quote. The quote contains the local package size, whole-package count, purchased
quantity, GBP package/total price, estimate flag, dated price source, availability
scope and offer fingerprint. Removing an offer sets only its FK to null; it does
not erase historical package evidence. Removing the shopping item cascades its
snapshot. No ALTER to legacy item columns or rewrite of PL quantities is needed.

`manual_extra_quantity` records additional demand on a generated item exactly
once. `purchase_is_checked` preserves the previous purchase state underneath an
auto-checked pantry row; pantry coverage does not mean an item was bought.
Neither is a new user-facing counter.

Unknown measures stay unpriced and keep their original amounts. Compatible,
explicit recipe measures are converted by the shared requirements service;
manual shopping `1 pack` instead resolves a validated local SKU. It never means
the canonical Polish product's package, an invented 100 g or an assumed g/ml
density. Stored positive quantities round conservatively upward to 0.001 **before**
the quote is selected, so the packages cover the persisted/displayed quantity.

## Connected GB paths

- Build: aggregate final recipe multipliers once, subtract only known compatible
  pantry stock when enabled, and quote the remaining demand from reviewed local
  offers. Missing quotes are null, not free purchases.
- Recalculate/store change: reload persisted rows before rebuilding, preserve
  manual extras and proven checked states, retain manual lines, and requote the
  destination store's local packages. No same-session stale collection doubles
  demand after a pantry split.
- Merge: retain canonical identity, original units, pantry/purchase and checked
  states. Requote combined demand instead of summing old whole-package prices.
- Add: explicit g/ml or a validated local package; additional demand never
  inherits a checked purchase state. Already checked demand remains a separate
  checked row and the new manual amount remains unchecked.
- Pantry sync: split global known coverage only once, without merging checked
  and unchecked demand. Removing pantry stock restores the original purchase
  status, including after a full-pantry recalculation.
- Substitute: compatible canonical dimensions and a reviewed local offer are
  required. Suggestions batch-load regional offers and expose `regional_quote`,
  not a Polish `StoreProduct`. A confirmed replacement resets checked state.
- Complete: move the frozen **purchased whole-package** g/ml quantity, not the
  smaller recipe requirement. Completion is idempotent. The entire checked batch
  is validated before any pantry assignment/add. An existing unknown pantry
  amount returns 409 with a request to enter its quantity or finish without
  moving items; it is not treated as zero and cannot silently swallow a purchase.
  Unknown custom text/measures do not create fictitious pantry inventory.

Price checks use an explicit UTC server calendar day. Recalculation refreshes the
transient GB plan estimate; missing purchase prices keep the total nullable.
Existing owner/shared-list authorization remains in the routes. Read responses
use the list store's currency even when the viewer's account belongs to another
market; creation still validates the account/store market.

## API additions

Existing amount, checked and price names remain unchanged. GB item responses add:

| Field | Meaning |
| --- | --- |
| `currency_code` | `GBP`; absent legacy fields remain `PLN` |
| `quote_status` | `quoted`, `unpriced` or `pantry` |
| `price_is_estimated` | Preserved quote provenance, not a guessed live price |
| `package_quantity`, `package_unit` | Nullable local pack g/ml |
| `package_count`, `purchased_quantity` | Nullable whole-pack purchase |
| `regional_offer_id` | Nullable FK; frozen evidence can survive deletion |
| `price_source` | Nullable `{url, publisher, checked_on}`; ISO date |
| `pricing_as_of` | Quote UTC calendar date |

List responses add `currency_code`, `has_unpriced_items` and
`price_is_estimated`. An incomplete GB purchase total is null; an empty or wholly
covered pantry purchase can genuinely total zero. Known requirements use g/ml;
unknown raw measures remain visibly unpriced, never silently converted.

## Regression evidence

`tests/test_regional_shopping.py` uses real local SQLite tables, foreign keys,
commit/reload and both autoflush enabled and disabled. The suite exercises all
paths above, SKU package changes, frozen evidence after offer deletion, owner
pantry coverage and incompatible/unknown measures. It also reproduces these
specific bugs before their fixes:

- Mixed `100 g + 1 cup` with no cup mapping plus a manual `10 g` used to overwrite
  the original recipe requirement. It now retains `110 g + 1 cup`, honestly
  unpriced, and repeated recalculation does not duplicate the extra.
- Pantry sync used to merge checked 100 g and unchecked 100 g into checked 200 g.
  Both purchase states now survive partial/full coverage and removal.
- A stale in-session list collection used to double a manual amount after a
  pantry split. Reloading before rebuild keeps the amount stable.
- Completing a valid product followed by an unknown-quantity pantry product used
  to report success while losing the known purchase. Full-batch preflight now
  rejects before mutation; a regression deliberately commits after catching 409
  to prove that an earlier valid product was not partially written.
- Fully covering a checked purchase, recalculating and removing pantry stock
  used to forget the prior checked state. The frozen purchase flag now survives.

Latest verification on 2026-10-19: the focused shopping suite completed with
**40 passed**, including both autoflush modes. A fresh full `pytest tests -q`
then completed with **906 passed**, 37 existing dependency/deprecation warnings,
exit 0 (30.33 seconds). These are local SQLite/mock tests, not a native AAB/IPA
build or real PostgreSQL verification.

## Remaining release work and limits

- No live catalogue/stock/price import, Neon connection, real PostgreSQL DDL
  execution, concurrency/load or physical-device verification took place.
- A dated `available_online` offer is online-catalogue evidence, not a promise of
  stock at every physical branch. Historical cart evidence is not a live quote;
  explicit recalculation validates current offers again.
- A missing English SKU can still fall back to the canonical name on an unpriced
  recovery line. Full English product content is a separate data/localisation job.
- Legacy automatic withdrawal callbacks are keyed to `StoreProduct`; automatic
  replacement when a regional offer changes status is not connected. Explicit
  GB substitution/recalculation is connected and does not fabricate availability.
- A deleted canonical product keeps a historic snapshot. A later rebuild that
  needs an orphaned manual extra must fail rather than guess a product/measure.
- The new additive table still requires isolated PostgreSQL migration testing
  before enabling UK. Existing snapshot schemas from an intermediate local test
  are not a production migration strategy. UK must stay disabled until catalogue,
  complete localisation and full native/release QA are ready.
