# UK stage 22 — secondary admin screens

Scope: `admin_users_screen.dart`, `admin_comments_screen.dart`, and
`admin_photos_screen.dart`. Existing moderation endpoints, IDs, ordering,
permissions, colours and ordinary layout are unchanged. The account locale
controls wording; choosing a market elsewhere must not change the language.
This stage does not add country filtering to globally scoped account moderation.

## Changes

- Moved visible labels, confirmations, empty states, photo errors and success
  messages to generated localizations. Original Polish wording is preserved,
  including the photo button **Zaakceptuj** (not the shared **Akceptuj** label).
- Passed the locale to the existing friendly-error mapper.
- Kept current results when an older search response or failure arrives after
  a newer user/comment search has completed.
- Synchronous pending-ID guards prevent two rapid unban/photo-approval taps
  from issuing duplicate moderation requests before the next frame.
- Comment confirmation checks `mounted` before calling `setState`/the service.
- The ban dialog scrolls when the keyboard reduces available height; its
  reason field now owns its controller rather than disposing a controller
  before the closing dialog animation has finished.
- The existing banned-account filter can shrink/wrap on narrow screens.
- Optional constructor service injection is backwards compatible and is used
  only for isolated widget tests; no production network or database was used.

## Evidence

Baseline actual-widget tests: 3 passed, 7 failed (three English screens still
Polish; stale search success/failure; duplicate unban and photo approval).
Additional 320×568 tests with a 250 px keyboard reproduced overflowing ban
dialogs in PL and GB, plus a GB filter overflow. After the overflow fix, focusing
and closing the reason field exposed `TextEditingController was used after
being disposed`; internal field ownership removed that lifecycle error.
Rapid comment taps were already intercepted by the dialog route barrier, so
no speculative duplicate-dialog fix was added.

Final targeted command (2026-10-22):

```text
flutter test --no-pub test/screens/admin/admin_secondary_market_test.dart --reporter expanded
13 passed; exit 0
```

These tests render and interact with all three real screens in PL/GB, perform
confirmation/delete/reject/unban, exercise out-of-order searches and repeated
taps, and type/cancel with a synthetic keyboard at 320 px. They use only fake
service responses and synthetic `.invalid` accounts. This is not native device
or production integration certification. Main agent owns full-suite validation
and the ARB/generated-file integration of `uk-stage22/admin-secondary-l10n.json`.
No version, package, deployment or production DB changes were made here.
