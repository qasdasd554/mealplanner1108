# Stage 18: pantry and ingredient matching

## Decision brief before repair

- Existing Flutter mobile flow (iOS and Android): pantry inventory, selection of ingredients, matching recipe cards.
- Primary objects: canonical product IDs and saved pantry quantities; the selected recipe remains the navigation target.
- Preserve the existing list/card/sheet structure, 90 px recipe image, palette, typography, spacing, Premium access and AI fallback. No new features, dependencies or motion.
- Layout: app bar / scrollable inventory or recipe results / existing actions. Card text drives its height; image must receive finite constraints. No intrinsic measurement of image LayoutBuilder.
- States: loading, empty, selected, Premium gate, error/retry, pending search, pending deletion and failed deletion recovery.
- Repairs require reproduced tests, not guessed causes. Verify PL and en-GB, exact IDs/amounts/units, stale asynchronous responses and small-screen enlarged text. No live AI, camera, production database or deployment.
- Visual evidence supplements interaction tests; widget tests alone do not prove native device accessibility or release readiness.

## Reproduced baseline

Nine widget tests: 3 passed, 6 failed. Three English-label failures and three existing defects: an unbounded-height matching card, RangeError when overlapping optimistic deletions fail, and an older search response replacing newer results.

An additional asynchronous-selection test also failed before its fix: the matching request used the submitted IDs, but the AI fallback received names from a later selection. Names and IDs are now captured together before awaiting the response.

## Implementation boundaries

- Localize only existing pantry, ingredient-selection and matching-results labels/prompts for en-GB. Polish text and the AI allowance of at most 2-3 extra ingredients are preserved. User/catalogue names are not translated in the client.
- Retain Premium checks, default all-selected behavior, request endpoints, product IDs, quantity units and shopping-list refreshes. Optional service parameters are test seams with unchanged production defaults.
- Restore a failed optimistic removal at a valid current index; do not duplicate an item already restored by a refresh.
- Only the latest search generation may alter results, loading state or errors. Clearing a query invalidates pending results, without adding debounce/delays or requests.
- Independent review identified two additional pre-existing gaps. New tests reproduced both: after a new query fails, do not redisplay results from the previous query; during pending deletion, a refresh must not resurrect the deleted row. Filtering pending/completed deleted row IDs covers refresh responses arriving both before and after deletion completes.
- An intermediate whole-response revision guard was rejected during review: it could discard a valid refresh containing a newly added different product. A new test reproduced this regression before replacing that guard with per-row filtering. The backend hard-deletes pantry rows and generates fresh UUIDs for re-additions; a test verifies the same canonical product with a fresh row ID remains visible. These deleted-ID markers are local to the lifetime of the screen, never persisted or shared between screens.
- Bound recipe-image height from the text-driven card, preserving the same image width, card style, title ellipsis and full/partial distinction. The existing readiness label can wrap inside its own available width.

## Render inspection

Four widget-render captures at 320 x 740 logical px, 150% text: PL/en-GB, light/dark, under `evidence/`. Inspected all four, then re-rendered after fixing the capture-only app-bar font (Ahem test blocks were evidence-harness artifacts, not production UI).

- Recipe title, full-match readiness, missing-ingredient text and existing AI action remain in their own regions; no infinite constraints or overflow exceptions.
- Existing title truncation and category-image fallback are intentional. Synthetic fixture recipes do not include user photos. No asset generation or styling changes.
- Stark influenced the finite text-driven layout repair and state/recovery evidence, not a redesign.
- Acceptance is limited to this local repair, not a complete visual/native accessibility certification. Font proof uses local Arial in the test harness; real device fonts, camera, IAP and native builds remain unverified in this stage.

## Release boundary

Still version 1.0.66+267, UK disabled. No production database writes, migration, external AI/camera calls, package/AAB, push or deployment in this stage. The update notice still uses the current localized three-bullet text from stage 17, whose stability/readability bullet covers these corrections.
