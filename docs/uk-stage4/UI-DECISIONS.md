# Stage 4 — existing shopping UI, truthful regional data

Compact Stark decision brief:

- Product task: a returning shopper checks what to buy, the physical pack and
  an honestly labelled estimate; preserve existing check, share and swap flows.
- Track: existing branded Flutter on Android/iOS. No platform migration,
  navigation redesign, new visual language, icon system, colour or typography.
- Object/action: shopping item / check bought; comparison / choose a shop only
  for a completely priced basket. Preserve the expandable shop-card structure.
- Layout: existing list header, item name and price; a local package line is
  secondary content within the expanded item, not a new card or action.
- States: quoted / estimated / pantry / missing price / partial basket.
  Missing GBP totals remain null and visibly unavailable, not £0 or cheapest.
  Price refresh and switching keep the existing controls and recovery path.
- Adaptation: wrap long English item/pack labels at 320 px and 150/200% text;
  do not reduce text scaling. Native focus and hit targets remain inherited.
- Motion: no added animation or dependency; existing expansion only.
- Explicit owner approval on 2026-10-19 permits a local contrast repair for
  the switch-shop button on the green cheapest card. Its text/border now use
  a legible black/white foreground; the card, button background, shape and
  inherited border width are preserved. Busy feedback uses the same colour.
  Four regression cases first reproduced a 1:1 foreground/background ratio;
  the repaired enabled text is tested at >=4.5:1 in both themes/text scales.
- References read: Stark cross-platform foundations; product bundle
  task-ergonomics and interaction-state-matrix. The existing mobile design is
  authoritative; desktop archetypes do not introduce a desktop shell here.
- Evidence: PL/GB parser tests, incomplete/complete comparison interactions,
  package and pantry assertions, narrow large-text widget tests. Optional PNG
  fixture capture uses MaterialIcons and a local Arial proof font, not a phone
  screenshot. Real VoiceOver/TalkBack, camera and native builds remain separate.
- Render gate on 2026-10-19: root inspected regenerated light/dark package cards
  and priced/unpriced shopping lists at 320 px / 150% text. The two-line switch
  action and physical pack labels fit without clipped text or shrunken fonts.
  Its contrast assertion passes in both themes at 150% and 200%. This confirms
  the scoped button repair, not all inherited card colours or native accessibility.
  The full Flutter suite passed 286 tests; analysis returned zero errors/warnings
  and 346 non-fatal existing/style information messages.

Do not announce UK support in the current release popup. The version stays
1.0.66+267 during local work; an eventual verified release package must bump
the version and replace the popup text with changes actually included.
