# Stage 19: batch localization of existing secondary screens

Keep the existing style, interaction model and Standard/Premium access. Localize statistics (including computed insight text), recipe-author rankings, promotion labels and the existing disabled ad-gate screen. Preserve Polish wording, identifiers, units, formulas, reward/ad limits and existing network endpoints.

Promotion API rows currently have only legacy PLN provenance; GB listing/check endpoints return no such rows. Do not relabel legacy prices as GBP or invent UK promotions. This stage localizes their current empty/error states, not the unimplemented UK promotion data supply.

Use optional services only as test seams; retain production defaults. Test PL/en-GB happy, empty, retry, both ranking tabs, Premium-vs-Standard insight coverage, ad completion/cancellation and stale provider responses after logout. Native ads remain disabled; tests use fake services.

No native SDK/package changes, new user features, version bump, database work, generated delivery ZIP or deployment.

## Completed implementation checklist

- [x] Define/render existing screens with injected fake services and PL/en-GB localization.
- [x] Verify initial data, empty and error states; interact with tabs, retry, cancel and completion.
- [x] Verify rebuilt state, canonical data, exact units/dates, Standard/Premium visibility and existing request counts.
- [x] Run targeted widget tests; compare generated weekly insight text/values across both locales with unit tests.
- [x] Reproduce stale promotions after provider clear before adding the generation guard; test latest-request-wins and localized retry afterwards.
- [x] Independent read-only review of formulas, PL wording, dates, Premium gates, navigation and provenance boundaries.

## Boundaries preserved

Weekly insight formulas, active-day criteria, seven-calendar-day window, sorting, water integer average and weight-change threshold are unchanged. Only labels are injected, with Polish as the legacy default. Stats summaries retain their own original whole-range calculations; they are not silently changed to the weekly window.

Rank order, counts, both endpoint calls, reward logic and medals remain unchanged. The pre-existing Polish noun-selection behavior is retained rather than bundling a grammar change; English uses singular/plural labels. Display names and favourite user-entered meal names are not translated.

Statistics dates use existing PL patterns and UK day/month/year presentation. Graph geometry, measurement units, line colors, density, card styles and animation remain unchanged. Tests cover statistics scrolling at 320 px with 150% text; this is not a device-wide UI certification.

Promotion request generation follows the existing StoreProvider pattern. A late request after clear/dispose cannot overwrite the new state; retries and ensureLoadedForStore retain their existing semantics and endpoints. Promos are never relabelled GBP from the locale.

The ad screen's text is translated for completeness only. AdGateService, home-screen disabling, SDK dependency state, advertisement limits and billing are not changed or activated. Tests use a fake service, not a live advert.
