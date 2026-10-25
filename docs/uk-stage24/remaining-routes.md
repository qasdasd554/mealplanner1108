# UK stage 24 — common remaining routes

Owned production files: `widgets/recipe_approval_bar.dart`,
`widgets/add_product_sheet.dart`, and `screens/shopping/export_list_screen.dart`.
All three are reachable from the current Recipe Detail or Shopping screens.

The localization map is `remaining-l10n.json`. Existing labels, colours, API
values and Polish text are retained. User-entered recipe/product names, store
names and free-text items are never translated by heuristics. Export maps only
the existing recognized `Inne`/pantry headings and canonical unit display codes
for English; unknown department/unit names remain unchanged.

## Confirmed pre-fix failures

After adding only optional fake-service constructor injection, the targeted
actual-widget baseline ran 10 tests: 3 existing Polish paths passed, 7 failed.

- Approval bar, shopping-add sheet and export dialog were still Polish under GB.
- Two rapid approval taps sent two requests before rebuild.
- Reusing the approval widget for another pending recipe retained its resolved
  state from the preceding recipe.
- A previous product-search result was accepted during the next query's 350 ms
  debounce interval and could be selected despite the changed text.
- Two rapid catalogue-result taps submitted two shopping-list items.

Fixes use per-operation guards, approval generation/ID invalidation and
immediate query invalidation. The established search debounce remains 350 ms;
the data sources, API route/IDs and shopping insertion semantics are unchanged.

## Boundary / unresolved decision

The original export dialog includes Jush and Glovo launch links. They are kept
with localized verb labels, not silently replaced with invented UK providers.
Those provider links still require an explicit UK product decision; translating
this dialog is not a claim that those delivery services operate in the UK.
The price-source dialog and report/block menu already use English display
strings, so this batch does not rewrite them. No production DB/network call,
native build, version bump, package, activation or deployment is part of this
batch. Full suite and ARB/generated integration are owned by the main agent.

## Verification

Pending final focused widget test run. Test fixture:
`test/widgets/remaining_market_routes_test.dart`. All responses and identities
are synthetic; clipboard/launcher calls are intercepted locally.
