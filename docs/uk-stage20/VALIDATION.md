# Stage 20 — verification and boundary

Date: 22 October 2026. Local continuation, followed by a separately requested Android stability priority. No release bump, activation, database write, real email, native build, package or deployment.

## Cooking content and interface

- Static English catalogue has the same 30 positions and icon categories as Polish, with no per-build allocation, server lookup or AI work.
- A pre-edit fixture proves the other 18 Polish tips retain exact text; only the 12 approved positions changed.
- The jar-opening topic and original Polish title remain at position 26. The advice describes dry hands/lid, a rubber glove/non-slip grip or jar opener rather than hitting glass.
- Widget tests verify automatic scrolling to positions 0, 20 and 29 in PL/GB, visible highlight and border expiry, the 320 px / 150% list, and invalid-index handling.
- Pure tests compare the original day-of-year calculation over 367 consecutive dates in each of 2024, 2025 and 2026. No rotation or date rule was redesigned.
- Splash tests retain brand, native method names and signed-out routing. Additional stability tests cover routing after storage failure.
- Targeted final tips/splash/update-notice batch: 23 passed (`android-stability-tips-notice.log`; before the last additional notice wording and scanner-only fixes). Final whole-tree validation is recorded in the [stability report](../audit/android-stability-20261022.md), not inferred from that earlier batch.

## Email

Targeted email/account-market tests: 66 passed (`uk-stage20-email-targeted.log`). Red evidence: nine new cases failed against the original signatures/templates/callers (`uk-stage20-email-red.log`). An intermediate missing import was corrected and the targeted run repeated.

Fakes inspect both email types, stored PL/GB market on resend/reset, exact recipient/code/brand, 15-minute wording and the legacy three-argument Polish default. User-controlled display names and the code are HTML-escaped. No real Resend call is made. Session issuance, reset codes, expiry, rate limits and account-enumeration-resistant responses were not changed.

## Content references

- [Royal Berkshire NHS: opening jars with grips/gloves/openers](https://www.royalberkshire.nhs.uk/media/tw3lujac/practical-suggestions-for-reduced-hand-function_may22.pdf).
- [FDA: egg safety and pasteurised eggs for uncooked/lightly cooked uses](https://www.fda.gov/food/buy-store-serve-safe-food/what-you-need-know-about-egg-safety).
- [FoodSafety.gov: refrigeration and marinating](https://www.foodsafety.gov/keep-food-safe/4-steps-to-food-safety).
- [Tefal manufacturer instructions: avoid overheating empty non-stick cookware](https://dam.groupeseb.com/m/5c952aaf992c46c8/original/1520011809-IFU.pdf).

These references support particular corrections, not certification of every culinary claim in the catalogue.

## Unfinished UK scope

This does not finish English system recipes, remaining administrative/export/server/push/document strings, UK promotional provenance and product/price coverage, or real Android/iOS device and purchase tests. UK remains disabled. Cooking-tip and splash layouts/styles are unchanged.
