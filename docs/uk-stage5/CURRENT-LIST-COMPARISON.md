# Stage 5 — current-list comparison, local implementation

The old plan comparison aggregates recipe entries. It must remain available,
with Polish behaviour unchanged. A separate UK list comparison reads the
persisted shopping rows, including manual additions and merged/technical lists.
No release/version change, deployment or production data operation is authorised
by this stage. UK stays disabled.

## Agreed contract

- `GET /api/v1/price-compare/shopping-list/{list_id}` reads a current UK list.
- `PUT /api/v1/shopping-lists/{list_id}/store`, body `{store_id}`, changes the
  store for its remaining purchases without rebuilding recipe requirements.
- `list_id` follows the existing public shopping API convention: it is the
  list's `meal_plan_id`, **not** the `shopping_lists.id` database primary key.
  Existing endpoint IDs are not migrated or interpreted interchangeably.
- Only the owner or an accepted collaborator can access a list. A Polish
  collaborator can read an accepted UK share in GBP, without changing the
  collaborator's account market or relabelling it PLN. Source owner/store
  must still be consistent GB/GBP; the destination must be a UK store.
- Merged-away/completed lists cannot be switched. Unknown/custom quantities
  stay visible and unpriced; they cannot produce a complete cheapest basket.
- Total means the whole current list, consistent with its existing total.
  Checked purchases remain a **fixed historical cost/package baseline** across
  candidate stores. Only unchecked purchases are freshly quoted at each store.
  A store switch must not change what was already bought or the physical
  quantity subsequently moved into the pantry.
- Pantry rows retain their explicit snapshot coverage at zero cost. Comparing
  a list does not subtract current pantry stock a second time or mutate rows.
- Unchecked rows retain separate checked/pantry partitions and use exact
  quantities and reviewed local SKU packages. No implicit 100 g or g/ml density.
- A store switch with an incomplete target quote returns 409 without partial
  mutations. The current UI offers a switch only for a completely priced basket;
  this stage does not introduce a new incomplete-basket confirmation flow.
- API changes are additive. The existing comparison screen is reused, without
  changing its visual design. List refresh follows confirmed list-switch success;
  no plan regeneration or success message on a failed switch.

## Verification gate

First reproduce the manual-addition price mismatch and technical-list failure.
Then test exact quantities, merged/custom lists, checked history, pantry,
unknown prices, expiry/corruption of historical evidence, accepted/rejected
sharing, foreign markets and atomic failure. Compare reads must stay read-only
and bulk-loaded, not add an offer/product query per item. Flutter tests must run
serially in this checkout to avoid racing its shared build cache.

## Fresh evidence, 2026-10-19

- Full backend: `python -m pytest tests -q`, **978 passed**, 37 existing
  dependency/deprecation warnings, exit 0 (60.55 s), local SQLite/mocks only.
- Full Flutter: `flutter test --no-pub`, **296 passed**, exit 0 (38 s).
- Full `flutter analyze --no-pub --no-fatal-infos`: exit 0, zero errors/warnings,
  346 non-fatal information/style messages, unchanged from stage 4.
- The list/backend lifecycle group is covered by this full run. GET is read-only even
  if its caller subsequently commits. A 24-product/two-store comparison has
  a fixed ceiling of 12 SELECTs, no per-product query and no pantry read.
- Ten new Flutter tests exercise the real list -> comparison -> switch path,
  HTTP 409 recovery, accepted GBP sharing on a PL account, unchanged PLN routing,
  unavailable totals, navigation away during PUT, account change during PUT,
  response identity checks and confirmed list refresh without plan regeneration.
- Two initial Flutter regressions reproduced the wrong plan route, then passed
  after using the list route. A stale list-ID response test failed then passed
  after checking both returned public list ID and destination store ID.
- Four backend history regressions (two autoflush modes) reproduced package
  rewriting after recalculation and checked-item merge, then passed after
  preserving unchanged frozen evidence and separate already-bought rows.
- A forced failure after the first repriced row proves SAVEPOINT rollback; a
  caught exception followed by commit does not retain partial mutations.
- A real HTTP compare -> PUT switch returns exactly the selected £3.60 for the
  persisted 1,200 g edited basket. Passing its database UUID instead of the
  public plan/list ID returns 404 rather than selecting another list.
- A changed requirement for an already bought generated product rejects before
  deleting or replacing rows, including if a caller commits after catching 409.

## Scoped UX acceptance (Stark)

- Job/user: a returning mobile shopper compares their actual edited basket,
  then selects another shop without losing purchase state or manual work.
- Pattern: keep the existing comparison list with expandable shop detail;
  the new action label names the list, not a regenerated meal plan. No new
  page, icon, colour, motion library, theme or layout was introduced.
- State contract: load/error/retry/partial/busy/success/back are inherited;
  missing prices cannot offer a switch, a failed PUT keeps the current screen,
  successful PUT returns to refreshed shopping, stale-account success is hidden.
- Failure severity: dropped manual data or changed purchased package is a
  data-integrity blocker; false success after 409 is a major recovery failure.
  Re-check uses the same failing task, not decorative changes.
- Evidence: nine component-level interaction tests and a response-identity unit
  test, plus the existing 320 px,
  large-text card tests. This is not observed usability testing with people,
  a fresh native screenshot, or proof of VoiceOver/TalkBack/keyboard behaviour.
- References: Stark task-ergonomics, interaction-state-matrix, usability-pattern-
  matrix, usability-heuristic-evaluation and usability-scenario-testing.

## Remaining limits before UK release

- No real retailer catalogue, current prices/stock or Neon mutation was used;
  no native AAB/IPA or live PostgreSQL/concurrency verification was performed.
- Whole-package pricing is intentionally per retained row/partition, matching
  store-switch persistence. Different rows are not silently merged into a new
  cross-row/mixed-SKU optimisation; checked purchases always remain separate.
- Historical evidence is internal saved provenance with strict structural and
  arithmetic guards, not a cryptographic signature or proof of a real receipt.
  Old/deleted live offers do not invalidate an otherwise valid recorded purchase.
- If a purchased generated row's requirement changes, recalculation rejects
  before deleting old rows; it does not invent what the user actually bought.
- The list switch updates the associated plan's store metadata for consistency;
  it does not regenerate recipes. Other plan-edit/automatic-offer-withdrawal
  workflows remain separate and require their own regional release testing.
- Full English content, real reviewed UK SKU data, automatic regional withdrawal
  handling and native/PostgreSQL QA remain required. UK is still disabled and
  release version remains 1.0.66+267. No release popup falsely announces UK.
