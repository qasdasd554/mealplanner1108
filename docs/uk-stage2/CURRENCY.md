# UK stage 2 — currency presentation foundation

This is local work in progress, not a UK release or an exchange-rate service.

## Implemented scope

- `frontend/lib/utils/market_money.dart`: strict PLN/GBP formatting and account-market currency selection. The existing Polish format (`12.30 zł`) is preserved exactly; British display uses `£12.30`. Numeric amounts are never converted.
- Price comparison response model reads `currency_code`. An old response with no currency remains PLN for backward compatibility; it must not be relabelled GBP.
- Price comparison service rejects unsupported, mixed or unexpected currencies before display. Comparing unlike currency rows in the sort comparator also fails explicitly.
- The comparison screen requests the currency for the persisted account country, not the phone language or the temporary admin catalogue selector. A changed account market during a request invalidates the result.
- The existing comparison screen/card layout, colours, buttons and actions are retained. English display strings, common quantity-unit labels and checked dates use generated localisations.
- UK information dialog describes local catalogue prices and estimates without showing Polish example prices. The existing Polish information dialog is unchanged.
- Missing provenance remains conservative: absent estimate flags, or a supposedly checked item without a parseable `last_verified`, still display as estimates. `~`, basket text and item text distinguish estimates from checked prices.

Translation fragments are `currency-pl.json` and `currency-en.json`; the parent task merges them into PL, base English and British English ARBs. Do not maintain a second runtime translation source in these JSON files.

## Verification on 2026-10-15

The following test command completed with **29 passed, 0 failed**:

```text
flutter test --no-pub test/utils/market_money_test.dart test/services/price_compare_market_test.dart test/widgets/price_compare_market_card_test.dart test/store_prices_test.dart
```

Coverage includes legacy PLN, GBP amount preservation, unknown/mixed/foreign currencies, missing provenance, 320 px at 150% text scale, complete/incomplete baskets, expansion and switch-button interaction. New provenance tests failed before their fixes and passed afterwards.

Targeted `dart analyze` on the seven implementation/test files completed with exit 0, no errors or warnings, and two pre-existing info-level suggestions in `price_compare_screen.dart`. Scoped `git -c core.autocrlf=false diff --check` completed with exit 0 after LF normalisation.

## Explicit limitations

- No rates, exchange conversion, IAP prices, subscription prices or billing code were changed.
- This does not populate UK product availability or verify retailer prices. It only presents the currency/provenance returned by the country-scoped backend.
- Other price views (shopping lists, product detail and plan setup) still need their own market-aware presentation pass. Do not enable UK until those remaining views are ready.
- No Android/iOS native build, physical-device test or production API/Neon test was performed in this subtask.
- `UK_MARKET_ENABLED` remains off; no version bump, ZIP, push or deploy was performed.
