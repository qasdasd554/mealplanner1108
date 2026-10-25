# Stage 8 — product submission and label review

Local-only continuation of the approved UK expansion. Existing Flutter
forms, theme, ordinary layout, navigation, reward rules and API identifiers
remain the contract. No release/version bump, deployment or UK activation.

## UX / form contract (Stark)

- Job/user: occasional PL/GB contributor adds or corrects a product,
  optionally using two label photos. Risk: wrong package size or nutrition
  reaching a shared catalogue/cache.
- Pattern: keep the existing grouped submission form and photo -> review ->
  explicit confirmation sheet. No new wizard, marketing panel or animation.
- Primary action: save the reviewed product. Photo selection, manual entry,
  correction and cancellation remain available without an unconfirmed save.
- Anatomy: labelled Flutter fields, existing units/dropdowns and optional
  nutrition disclosure. Per-100 nutrition and whole-net-pack size must be
  distinct; missing values stay empty, not zero or a guessed 100 g pack.
- Validation: on submit, near each field, preserving typed values. Client
  bounds match ProductSubmission/ProductLabelConfirmation; backend schemas
  remain authoritative. Finite numeric values only, comma decimal accepted.
- Market: account/editing product country selects the currency. Do not
  relabel the legacy PLN suggested-price range as GBP or offer PL shops to
  a GB submission. Display labels never change canonical unit IDs.
- States/recovery: empty/photos missing; picking/recognising/submitting;
  partial recognition; invalid field; cancelled picker; failed API with
  retained data and safe retry; confirmed save. Prevent duplicate actions
  while busy and ignore late results after sheet disposal.
- Accessibility/native controls: keep text labels, normal focus traversal,
  dropdown keyboard operation and sheet Back/Escape dismissal. Report
  errors visibly and through a live-region summary without clearing input.
- Responsive: preserve normal composition; test 320 px / 150% text with
  simulated keyboard and bottom system inset. Buttons must remain reachable
  by scrolling and must not occupy the system/keyboard area.
- Evidence: reproduce wrong ml edit, stale suggestion data, invalid numeric
  input and unknown nutrition. Widget mocks verify payload, retry, explicit
  confirmation and cancellation; PL/EN light/dark renders verify containment.
- Scope limits: widget/mock evidence is not real OCR accuracy, physical
  camera/permission QA, real UK SKU validation or native screen-reader QA.

References: task-ergonomics, interaction-state-matrix,
form-state-validation-system, usability-pattern-matrix,
usability-heuristic-evaluation, usability-scenario-testing,
accessibility-interaction-contract.
