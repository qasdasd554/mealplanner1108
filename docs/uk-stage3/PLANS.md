# UK stage 3 — plan configuration and plan view

Local implementation only. This does not enable the UK market or constitute a release.

## Implemented

- `PlanConfigScreen`: English display labels, validation messages, generated-plan confirmation, estimate explanation, pantry option and weekly-limit information. Diet and meal-type display is localised through `catalog_labels`; submitted identifiers remain Polish canonical values.
- Store selection is constrained by both the persisted account country and `Store.currencyCode`. A foreign or inconsistent store cannot be submitted even if stale catalogue data reaches the client.
- The budget input currency follows the account market. The generated numeric estimate is displayed only when the returned plan belongs to the same country-validated selected store. Existing Polish formatting remains `12.30 zł`; GB uses `£12.30`. There is no currency conversion or assumed exchange rate.
- Saved calorie goal and default `2000` are retained. The people slider and increment button remain capped at 8, including profiles containing larger legacy values. Pantry toggle, plan-only diet selection and meal selection behaviour are unchanged.
- `PlanViewScreen`: localised day labels, meal slots, difficulty, swap search/messages, empty/expired/archive-gated states, confirmation/deletion messages and navigation buttons. Original recipe content is not overwritten.
- Optional `RecipeService` injection in `PlanViewScreen` permits deterministic component tests without changing production defaults or shared services.

## Reproduced bugs repaired without redesign

1. After choosing a replacement dish, `showModalBottomSheet` completes on pop before the closing animation finishes. Disposing its search controller immediately caused `A TextEditingController was used after being disposed` and cascading overlay/layout errors. Cleanup now waits for `ModalRoute.completed`, while the swap request proceeds immediately. The same interaction test failed before this fix and passed afterwards.
2. A slow failed DELETE used the already-closed confirmation dialog context to show its error. A 500 ms test response reproduced `Looking up a deactivated widget's ancestor is unsafe`. The dialog now has a distinct context; subsequent actions use the still-mounted plan screen. The same regression test passes after the fix.
3. At 320 px and 150% text scale, macro columns overflowed (PL 162 px; GB 107 px). They now share the existing row width with `Expanded` and centre/wrap their text. The four-stat layout, colours and values are retained; neither text scaling nor data is suppressed.

## Verification

On 2026-10-16 the scoped test command completed with **30 passed, 0 failed**:

```text
flutter test --no-pub test/screens/meal_plan/market_plan_screens_test.dart test/plan_lifecycle_and_preferences_test.dart test/meal_plan_request_test.dart test/weekly_plan_automation_test.dart
```

The new component suite covers PL/GB stores/currencies, account-country priority over a changed phone region, calorie defaults and saved goal, max 8 people, untranslated API identifiers, budget amount preservation, pantry toggle, calorie validation, plan estimates, swap search without refetching, controller lifecycle, delayed delete failure, empty/expired states and 320 px/150% text.

Scoped whitespace checks passed after UTF-8/LF normalisation. Parent verification performs the full Flutter test suite and analysis after integration.

## Remaining work

- `plan_archive_screen.dart` and `weekly_plan_automation_screen.dart` retain their existing Polish strings/date/time presentation. Automation timezone policy must be validated with the UK backend before translating any schedule promise.
- Server-originated preference warnings and API error messages may still be Polish. They require a backend-localisation pass, not rewriting server data in widgets.
- Actual UK store prices/availability and recipe-content translations are separate catalogue work. No prices, accounts or data were changed on Neon/Render.
- No native Android/iOS build or physical-device test was performed here. No IAP changes, version bump, ZIP, push or deployment.

Translation fragments `plans-pl.json` and `plans-en.json` are input for the parent task's shared ARB generation; runtime uses the generated app localisations only.
