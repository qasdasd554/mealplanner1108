# Stage 23 — explicit diary, pantry, catalogue and profile errors

Date: 2026-10-22. Local changes only; no deployment, external service, production
database, migration, package or version change.

## Evidence and boundaries

The Flutter client can display an API's fixed error detail directly. Several
ordinary UK account actions still received Polish server messages, even though
the interface was English. This finite batch localises fixed server-owned
templates using the persisted account country. It does not translate arbitrary
`str(exc)`, user-authored content or model-validation output and adds no global
middleware or automatic translation service.

`app/core/language.py::account_text` chooses English only for a saved `GB`
account; absent/unsupported saved market values retain Polish. The country is
not inferred from a changing request/device locale, IP or admin market filter.

## Changed paths

- `food_log.py`: free history limit, missing recipe/name input, missing diary
  entry, edit/delete ownership, missing/foreign meal-plan entry. Calculation,
  30-day boundary, selected account day and write behaviour are unchanged.
- `pantry.py`: empty selection, batch Premium gate, quantity/unit/barcode,
  unknown barcode, unknown package mass, missing/user-scoped pantry row.
  Unknown package mass still returns 422 rather than assuming 100g or 1g.
- `recipe_access.py`: all hidden/missing/inactive/private unauthorised access
  retains the same indistinguishable 404 and existing friendship query.
- `products.py`: explicit barcode, missing/foreign product, store-context,
  duplicate contribution/reward, duplicate barcode, missing account and
  complete-nutrition messages. Nutrition completeness thresholds, reward
  amounts/idempotency, moderation and visibility rules are unchanged.
- `users.py`: explicit TikTok Premium, saved-shop market, block/ban, missing
  account/report and unknown report-content messages. Clearing a saved TikTok
  username remains available without Premium. No permission rules changed.

No `recipes.py` or recipe-schema edits were made in this batch; the root agent
owns the recipe overlay work. Existing recipe-notification edits are stage 22.

## Verification

Following the previously-read debugging/verification skills:

- Diary/pantry regression run before edits: **17 GB failures, 17 PL passes**.
- Product/profile/access regression run before edits: **19 GB failures,
  19 PL passes**. Additional guards were covered before the final green run.
- Green diary/pantry + related nutrition/amount/sync tests: **80 passed**.
- Fresh expanded product/profile/diary/access regression run:

```text
ENVIRONMENT=test
python -m pytest
  tests/test_product_profile_errors_market.py
  tests/test_diary_pantry_errors_market.py
  tests/test_products_nutrition_audit.py
  tests/test_recipe_comment_market_access.py
  tests/test_account_market.py
  tests/test_tiktok_profile.py
  tests/test_store_market_access.py
  tests/test_profile_preferences_market.py
  tests/test_product_contribution_reward.py
  tests/test_ai_recipe_market.py -q
361 passed, 3 existing Starlette deprecation warnings in 10.63s
```

Compilation of changed Python modules/tests passed. The tests use fakes and
ephemeral SQLite, verify exact Polish text as well as English text, and assert
statuses/ownership/no-write behaviour. Root owns the later whole-backend run.

## Remaining language audit gaps (not claimed fixed here)

- `api/deps.py` still has fixed Polish authentication, ban-default, email
  verification, administrator and Premium errors. An entered ban reason is
  user/admin content and must remain unchanged.
- `billing.py` fixed rejection details and lower-level store-verification
  exception messages are separate from the confirmation notifications fixed
  in stage 22.
- `display_name.py` validates unique/short/long nicknames with Polish copy;
  registration has no persisted account until creation and needs an explicit,
  scoped signup-country context rather than request-global language guesses.
- Calculator service errors, Pydantic model validators and other router
  errors need their own bounded tests; they are not machine-translated here.

Product label recognition already has account-country English fixed errors;
its existing `str(exc)` propagation was inspected and retained.
