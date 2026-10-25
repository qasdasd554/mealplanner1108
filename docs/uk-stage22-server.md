# Stage 22 — recipient-language notifications (2026-10-22)

## Scope and evidence

The UK account already received English weekly-plan/import/reminder bodies,
but almost every push title was still Polish. Comments, moderation decisions,
shopping-list invitations, purchase confirmations and contest announcements
also used Polish templates regardless of the recipient. A request's actor or
an administrator's selected catalogue market must not determine the language
of a different account's notification.

Changes are local only. There were no production database, FCM, store, email,
billing-service or other external network calls. No version bump or release
package was produced. The existing notification types, targets, permissions,
timing and push counts remain unchanged.

## Implementation

- `notification_language.py` selects a template from the persisted recipient's
  account market. Missing/unsupported saved values retain Polish behaviour.
- `push.py` has an English title for every existing title type. The default
  path reads the recipient account; callers already holding the persisted
  recipient country can pass it without another read. Push-disabled remains
  a zero-I/O path. Recipe/plan target data and message bodies are unchanged.
- Comments and likes use each eligible recipient's language after the existing
  access/UK-availability check. User-authored names and comment text are not
  translated; the existing 80-character preview is retained.
- Recipe approval, recipe-photo approval/rejection and product moderation
  use the author's/submitter's country, not the administrator's country.
  A failed optional product-notification lookup cannot undo a saved review.
- Each administrator receives the matching moderation template. The fan-out
  loads only IDs and countries in one query, without loading avatar payloads.
  All existing callers provide an English template (products, recipes, photos,
  content reports and promotion leaflets).
- Shopping-list sharing/acceptance use the target account/original sender
  respectively. Duplicate share attempts still create no second notification.
- Billing changes only confirmation copy; purchase verification, point awards
  and entitlements are untouched. Contest ranking, settlement dates, award
  amounts and recipients are unchanged; only per-recipient announcement copy
  changes. Contest fan-out also selects only account IDs and countries.
- Existing English recipe-import, weekly-plan and meal-plan-expiry bodies were
  retained. Their push titles are now translated by the common title path.
- Administrator-written broadcasts remain the original entered text. The
  product brand “Meal Planner Polska” is unchanged in both markets.

## Verification

Read `systematic-debugging` and `verification-before-completion` before edits.
The initial title regression run failed 48 cases (recipient was not resolved,
and GB titles stayed Polish) and passed the disabled-push case.

Fresh expanded targeted run:

```text
ENVIRONMENT=test
python -m pytest
  tests/test_notification_language_market.py
  tests/test_notification_bodies_market.py
  tests/test_admin_notifications.py
  tests/test_friend_social_messages_market.py
  tests/test_recipe_comment_market_access.py
  tests/test_admin_product_review.py
  tests/test_recipe_photo_thumbnail.py
  tests/test_billing.py
  tests/test_plan_lifecycle_integration.py
  tests/test_meal_plan_lifecycle.py
  tests/test_ai_recipe_market.py
  tests/test_audit_import_worker.py
  tests/test_regional_shopping.py
  tests/test_audit_shopping_integrity.py -q
313 passed, 38 existing datetime.utcnow deprecation warnings in 13.92s
```

Mocks or ephemeral SQLite only. Cross-market tests cover actor PL/recipient GB
and the reverse, template/payload preservation, mixed-market fan-out, pending
share deduplication, unchanged contest awards and disabled-push zero I/O.
The root agent owns the subsequent whole-backend regression run.

## Deliberate limits

This stage is notification localisation, not automatic translation of
user-generated content, a UK launch, a push-delivery certification or a bulk
rewrite of API validation/error messages. Older already-stored notifications
are not rewritten. There are no new premium features, database migrations,
quotas, purchase rules or market-switching controls in this stage.
