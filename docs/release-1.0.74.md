# 1.0.74+275 — English foods in UK shops

Food database → Shop now reuses the 390 canonical system foods with reviewed
English names and their food-level nutrition. Reviewed retailer SKUs remain
preferred. No Polish user products, example brands, package weights or PLN
prices are transplanted to UK shops.

Generic foods are labelled as references, not confirmed store inventory.
Supported existing ONS references display an estimated national price per
100 g/ml; unsupported/expired prices display “Price unavailable”, never £0.00.
The Polish shop catalogue and separation of community recipes are preserved.

The client requests this additive catalogue explicitly, keeping older apps
compatible. No migration or new service is needed. Both backend and app need
this update; changing only APP_VERSION does not deploy the fix. PL and EN
update notices include the English shop foods. Small screens/large text keep
the list accessible without changing the normal layout or colours.

Exact base: 21072e4ee35d8094f1b65a744a8e366d5c05c130, 1.0.73+274.
Target: 1.0.74+275. The installer backs up changed files, checks source/payload
hashes, runs tests/analysis and builds the Android bundle before commit/push.
Native AAB compilation is performed in Codespace, not asserted from a local
simulation. iOS needs a normal Xcode archive using build 275.
