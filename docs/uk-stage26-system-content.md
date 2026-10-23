# Stage 26 — existing system content, not a new catalogue

The reviewed English text for 137 system recipes and their 150 distinct generic
ingredients is now connected to existing display/search/sort paths. Selection
requires the exact deterministic seed UUID, no user creator and the matching
canonical Polish source. Instructions and seasonings additionally require the
original lists. Server-side edited variants require a full source fingerprint.
User recipes and changed source text are never translated by a name guess.

Canonical IDs, ingredient amounts, nutrition, photos and Polish account displays
are preserved. The diary and catalogue picker carry the known product identity
through amount selection. A 200 g butter package remains 200 g, not a guessed
100 g, while its UK label is displayed in English.

The generator is `scripts/build_system_content_labels.py --check`; it validates
seed coverage, number/step parity and the generated Dart/JSON indices. Reviewed
JSON files are source data; the generator does not call AI or the internet.

Targeted verification includes all 137 recipe displays, 150 ingredient identities,
authored/modified exclusions, real recipe details at 320 px / 150%, literal UK
search, UK sort, diary response labels and PL/GB saved variants. These checks
use synthetic accounts and local databases. They do not establish UK stock,
retailer prices or generic-ingredient-to-GTIN mappings. UK remains disabled.
