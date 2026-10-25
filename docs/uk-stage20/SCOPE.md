# Stage 20: existing cooking tips and splash wording

Localize the static 30-tip catalogue and its existing home-card/list presentation. Keep Polish content and public `kCookingTips` compatible, preserve ordering, icons, day-of-year selection, route argument and 3-second highlight/450 ms scroll behavior. English remains a compiled static catalogue: no AI/network/DB calls and no per-build translation or catalogue import.

The owner approved content corrections on 22 October 2026, with the explicit condition that the jar-opening life hack must remain. All 30 tips retain their positions and icon categories. Twelve Polish entries were corrected; the other eighteen retain their exact original wording, checked against a pre-edit fixture. The jar tip remains at index 26 with its original Polish title, using a rubber glove/non-slip grip/jar opener rather than striking glass.

Localize only the splash subtitle; retain brand, logo, 800 ms animation delay, session/verification/onboarding routing, update gate, notification/premium/share-link priorities and native channels unchanged.

## Test plan

- [x] Define unit and widget tests with deterministic dates and locales.
- [x] Mount existing screens, locate title/body and initial highlight.
- [x] Simulate scrolling and check highlighted tip visibility/expiry (including border assertions).
- [x] Verify 30 matching positions/categories, immutable static data and Polish content parity.
- [x] Run targeted tests, then one complete frontend suite and analysis after final edits (see Android stability validation; informational lints remain).

Verification and password-reset emails now use the persisted account market, defaulting to Polish for legacy callers. Subjects, code and 15-minute validity are preserved; English does not come from a request-supplied region. A reproduced HTML-name injection in the existing template is escaped. Local HTTP fakes capture messages; no real emails are sent.

This stage was interrupted by the owner's higher-priority Android stability reports. Verification is recorded alongside the subsequent stability work; do not describe UK as complete.

No redesign, new user feature, billing change, version bump, production access, ZIP/AAB/IPA, push or deployment.
