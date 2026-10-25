# Stage 4 — reviewed UK availability and checkout pricing

Local implementation only. UK remains disabled and this does not assert that synthetic fixture products are actually sold by any retailer.

## Availability boundary

`market_catalog.recipe_market_availability` now requires a `RegionalProductOffer`, not a legacy `StoreProduct`, for every non-optional UK ingredient. The correlated SQL predicate runs before recipe pagination, does not duplicate recipes for multiple offers, and preserves Polish catalogue behaviour. Missing optional ingredients do not exclude a recipe; an empty ingredient list is still unknown rather than evidence of availability.

SQL checks GB/GBP, a known UK retailer/store, `available_online`, `online_catalogue`, a completed non-future review, positive bounded package/price values, estimate-kind consistency, basic fingerprint shape, and dated package/price/availability evidence within 30 days. Dates in JSON are guarded ISO text comparisons, not unsafe casts of arbitrary JSON to PostgreSQL DATE. The clock is an explicit server UTC calendar day.

The review timestamp's calendar day is also explicitly UTC: PostgreSQL compiles it as `to_char(reviewed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD')`, while SQLite uses UTC-normalising `strftime`. A PostgreSQL session configured for a different timezone must not reject a valid review around UTC midnight. Verification covers PostgreSQL SQL compilation and real SQLite offset-date boundaries; no live PostgreSQL session was available for this check.

These are deliberately **coarse SQL guards**, not cryptographic/Pydantic validation. Full detail checks, generator selection and all checkout quotes revalidate the proposal fingerprint, deterministic offer ID, retailer source domains, evidence dates and compatible g/ml dimension through `select_uk_offer_quote`. A corrupted row that survives coarse SQL is not trusted for a detailed recipe/generation/price quote. Public lightweight catalogue queries remain SQL-only before pagination.

Owner recovery/editing and administrator moderation exceptions remain in the existing recipe routes. The `/available` route already selected a separate GB predicate and therefore needed no additional legacy-filter patch.

## UK arithmetic and response

- Shared `aggregate_regional_requirements` applies final entry multipliers once, with exact Decimal arithmetic and explicit mass/volume or unambiguous stored measures.
- Quotes use local SKU package sizes and whole-package ceiling. `Product.default_quantity`, Polish packages, name-based weights, implicit `g = ml`, exchange rates and fabricated 100 g fallbacks are not used for GB.
- Comparison and shopping builder both use `regional_pantry_coverage` plus exact `subtract_regional_quantity`. Only the current owner's known, compatible pantry quantities reduce purchases. `include_pantry=false` bypasses this deduction; unknown pantry amounts do not prove full coverage.
- Known pantry coverage is an explicit zero-cost item (`is_from_pantry=true`), not a verified retailer offer. A wholly covered basket may legitimately total £0. A missing purchase quote may not.
- Every incomplete GB comparison has `total_price=null`, `is_complete=false`, missing product names, no cheapest badge and no savings claim. Present item prices can still be inspected. No missing offer becomes a complete £0 basket.
- UK comparison item fields add `regional_offer_id`, `package_quantity`, `package_unit`, `package_count`, `purchased_quantity`, `price_per_package`, `price_source`, `offer_fingerprint` and `is_from_pantry`. Display response quantities are floats; all calculations use Decimal before serialisation.
- Dated estimates retain `price_is_estimated=true` and no observed-price date; observed quotes retain their checked date.

The PL comparison path, formatting assumptions and its three logical batched queries are unchanged. GB uses a bulk offer query and, when pantry is enabled, one owner-scoped pantry query. There are no per-item/store database lookups or network catalogue calls.

### Stage-4 release blocker, resolved by the separate stage-5 list path

The old plan endpoint deliberately retains plan semantics. Stage 5 adds
`GET /price-compare/shopping-list/{meal_plan_id}` plus a list-specific store
switch and wires GBP lists to these paths. See `../uk-stage5/CURRENT-LIST-COMPARISON.md`.
The following is the original stage-4 reproduction, not a remaining claim that
GBP shopping lists still call the plan endpoint.

The comparison endpoint still aggregates `MealPlan.entries`, not the current edited shopping-list rows. Whole-pack calculations agree for an unedited generated plan, but manual additions and retained/merged shopping items are not part of the comparison requirements. An independent synthetic SQLite reproduction on 2026-10-19 confirms a 600 g recipe plus a 600 g manual addition costs £3.75 on its 1,200 g shopping list while the plan comparison still returns £2.50 for 600 g. An empty shopping-only technical plan with a manual product is rejected by the comparison's plan-access guard (404), before an empty ingredient aggregation can occur; merged shopping-only technical plans use the same unsupported access path.

This was not resolved by presenting a partial basket as a complete one. Stage 5
defines separate plan-vs-current-list semantics and preserves manual, merged,
checked and pantry requirements. UK remains disabled for the other catalogue,
localisation and release-QA work. The Polish plan comparison was not redefined.

## Generator and budget

GB candidate selection no longer performs a second legacy `StoreProduct.product_id` filter after regional availability. It batch-loads offers and fully validates source/fingerprint/measure compatibility before greedy selection. Existing visibility, diet and allergen logic remains intact; PL selection keeps its old path.

`_shopping_list_budget_query` returns a total for GB only when the generated list is nonempty and every item to purchase has an estimate. Unknown purchased items or an empty list produce `None`. Proven pantry items may cost zero. Plans created without a shopping list (disabled or quota reached) retain their nullable, uncomputed budget. The Polish COALESCE/SUM behaviour is unchanged.

## Verification and limitations

On 2026-10-16, the new integration file completed with **30 passed**. A subsequent full `python -m pytest tests -q` completed with **885 passed, 0 failed**, and 37 existing dependency/deprecation warnings (24.17 seconds).

On 2026-10-19, an independent follow-up run of `test_regional_shopping.py`, `test_uk_pricing_availability_integration.py`, `test_market_recipe_catalog.py`, `test_market_prices_promotions.py`, `test_friend_recipe_markets.py` and `test_store_market_access.py` completed with **137 passed, 0 failed**, and three dependency/deprecation warnings (20.40 seconds). This includes the repaired mixed-unit/manual-addition, checked/pantry/recalculation and unknown-existing-pantry checkout regressions, plus three UTC review-day regressions. The three UTC tests failed against the prior implementation and passed after the explicit-UTC SQL change. Scoped `py_compile` and `git diff --check` also completed successfully. This scoped follow-up is not a new claim of native build or live PostgreSQL verification.

New `test_uk_pricing_availability_integration.py` covers actual SQLite queries and HTTP serialisation, 500 g vs 100 g package mistakes, exact multipliers and mixed units, explicit volume, invalid/stale/future/missing sources, altered fingerprints, observed/estimated prices, pantry states, generator selection without legacy mappings, SQL ordering, nullable budgets and six real shopping-builder → snapshot → comparison → budget checkout cases. Synthetic helper data live in `tests/uk_regional_fixtures.py` and make no live stock/price claims.

Existing stage-1 GB fixture tests were migrated from legacy price mappings to reviewed synthetic regional offers. Their PL cases were kept unchanged. Real PostgreSQL query plans/migrations, physical devices, live retailer evidence and native builds remain release-QA work. No production Neon/Render writes, deployment, package, version or IAP change occurred here.

The pre-existing greedy selection accepts `max_budget` but does not use it as a hard price cap (also true for PL). This task fixes honest checkout estimates; it does not introduce a new guarantee that generation stays within a requested budget.
