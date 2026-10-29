"""Conservative cooking roles for automatic suggestions, before macro ranking.

These are possible user-selected alternatives, not a guarantee of identical
taste, allergens or nutrition. Explicitly curated substitutions can express
other choices (e.g. a vegan alternative); this gate is only for macro search.
Unknown names only match the same name. Do not infer roles from substrings:
rice flour, rice noodles and a ready-made rice dish are not bags of rice.
"""
from functools import lru_cache
import re
import unicodedata

from app.services.system_content_language import _index


def _normal(name: str) -> str:
    text = unicodedata.normalize("NFKD", (name or "").casefold().replace("ł", "l"))
    text = "".join(char for char in text if not unicodedata.combining(char))
    return re.sub(r"\s+", " ", text).strip()


# Keep different preparations separate. Fresh/dried herbs, dry/canned pulses,
# cooking/condensed milk, raw/smoked meat and starch/flour are not 1:1 swaps.
_ROLE_FOODS = (
    "Jajka|Jajka przepiórcze",
    "Ryż biały|Ryż basmati|Ryż jaśminowy|Ryż brązowy",
    "Makaron penne|Makaron spaghetti|Makaron fusilli|Makaron tagliatelle",
    "Mleko 2%|Mleko bez laktozy|Mleko kozie|Milk|Whole milk|Semi-skimmed milk|Skimmed milk",
    "Oliwa z oliwek|Olej rzepakowy|Olej słonecznikowy",
    "Pierś z kurczaka|Polędwiczki z kurczaka|Filet z indyka",
    "Udka z kurczaka|Podudzia z kurczaka",
    "Dorsz filet|Mintaj filet|Morszczuk filet",
    "Łosoś filet|Pstrąg filet",
    "Wołowina mielona|Mielone wieprzowo-wołowe|Mięso mielone z indyka",
    "Parmezan|Ser grana padano|Ser pecorino",
    "Ser cheddar|Ser żółty gouda|Ser provolone",
    "Ser brie|Ser camembert",
    "Jogurt naturalny|Jogurt grecki|Skyr naturalny",
    "Śmietana 18%|Śmietana 30%",
    "Mleko kokosowe|Mleczko kokosowe light",
    "Mąka pszenna|Mąka pszenna pełnoziarnista|Mąka orkiszowa",
    "Mąka ziemniaczana|Skrobia kukurydziana",
    "Bułka tarta|Bułka tarta panko",
    "Cukier|Cukier trzcinowy",
    "Cebula|Cebula czerwona|Szalotka",
    "Papryka czerwona|Papryka żółta|Papryka zielona",
    "Sałata lodowa|Sałata masłowa|Sałata rzymska",
    "Pieczarki|Pieczarki portobello",
    "Pomidory|Pomidorki koktajlowe",
    "Pomidory całe pelati|Pomidory krojone|Pomidory krojone z bazylią",
    "Passata pomidorowa|Przecier pomidorowy",
    "Fasola biała konserwowa|Fasola czerwona konserwowa|Fasola czarna konserwowa|Fasola cannellini|Fasola konserwowa",
    "Fasola biała sucha|Fasola czerwona sucha",
    "Kuskus|Kasza bulgur",
    "Soczewica zielona|Soczewica czarna beluga",
    "Oliwki czarne|Oliwki kalamata",
    "Ocet jabłkowy|Ocet winny czerwony|Ocet ryżowy",
    "Sos sojowy|Sos tamari",
    "Musztarda|Musztarda dijon|Musztarda francuska",
    "Cynamon|Cynamon cejloński",
)


@lru_cache(maxsize=1)
def _roles_and_aliases():
    roles = {_normal(name): str(index)
              for index, group in enumerate(_ROLE_FOODS) for name in group.split("|") }
    aliases = {}
    for row in _index()["ingredients"].values():
        source = _normal(row["source"])
        aliases[_normal(row["en_GB"])] = source
    return roles, aliases


def cooking_role(name: str) -> str | None:
    normal = _normal(name)
    if not normal:
        return None
    roles, aliases = _roles_and_aliases()
    normal = aliases.get(normal, normal)
    return roles.get(normal, "identity:" + normal)


def same_cooking_role(original_name: str, candidate_name: str) -> bool:
    original = cooking_role(original_name)
    return original is not None and original == cooking_role(candidate_name)
