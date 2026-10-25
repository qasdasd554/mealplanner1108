# Stage 7 — diary entry and barcode presentation

Local only. Keep the approved Flutter iOS/Android app, existing Material
controls, colours, ordinary layout, navigation and Premium gating.
No redesign, framework/library change, publishing or UK activation.

## UX / task contract (Stark)

- Job/user: a returning mobile user logs a recipe or a scanned food with
  the intended physical quantity. Daily repetition; nutrition/data risk.
- Object/action: selected recipe/product and its amount; confirm the
  existing add-to-diary action, or choose existing scan destinations.
- Pattern: existing search -> selection -> amount/meal confirmation,
  with the current three diary tabs and single/batch scan actions.
  Reject a new wizard, landing hero, extra dashboard panel or modal chain.
- Preserve faster repeated paths: recent foods, catalogue search, scanning,
  one destination selection for a whole batch.
- Prevention: display labels are localised, API meal/measure codes are not.
  Never turn a package into 1 g, infer density, send non-finite numbers or
  overwrite newer search results with a late response.
- Form anatomy/timing: retain labelled native Flutter fields/dropdowns;
  validate numbers on submit, retain values after invalid input/server
  failure, show errors by the relevant field. Server schemas remain
  authoritative. Preserve documented native limits and units.
- State matrix: empty plan/results -> existing alternative actions;
  pending -> stable busy state; partial nutrition/package -> label repair;
  camera permission/error -> manual code entry; invalid input -> correction;
  save error -> retained selection/retry; success -> confirmed navigation;
  cancel/back -> no unconfirmed save.
- Accessibility: native buttons/chips/dropdowns/dialogs keep semantics,
  focus traversal, Escape/cancel and tap alternatives. Controllers live
  through reverse transitions. No new animation or hidden-only controls.
- Adaptation: small-width / larger-text and keyboard checks may repair
  containment without changing the normal composition or shrinking text.
- Evidence tasks: PL/EN labels, selected physical amount and canonical API
  values, invalid numeric input/retry, late search, manual scanner cancel/
  confirm, batch Premium preview and multi-destination selection.
- Visual evidence must be rendered and inspected before claiming visual
  quality; widget interactions alone do not establish native-phone or
  assistive-technology usability.
- References read: task-ergonomics, interaction-state-matrix,
  form-state-validation-system, usability-pattern-matrix,
  usability-heuristic-evaluation, usability-scenario-testing and
  accessibility-interaction-contract.

## Out of scope / release gates

No real camera or physical labels are available in this Windows test
environment. Native focus/permission/lifecycle and real-device scanning
remain explicit QA gates. Product submission/OCR forms, regional external
data parameters, catalogue data and untranslated account/admin/premium
surfaces remain separate work unless addressed and tested here.
