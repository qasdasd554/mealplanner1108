"""Static GBP planning prices, like PL seed prices, NOT live retailer offers.

Only unchanged system food identities qualify. These are explicitly model
assumptions per kg/litre or piece, not invented observations, package sizes,
currency conversion or claims that a particular shop stocks a product.
"""
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from functools import lru_cache

from app.services.product_market_presentation import is_uk_generic_seed
from app.services.uk_catalogue_import import canonical_base_unit

MODEL_DAY = date(2026, 10, 26)
MODEL_VERSION = "uk-static-planning-v1"

# GBP per 1 kg/litre for a generic department baseline. No fabricated retailer
# differences: all UK chains use multiplier 1.00 until real quotes exist.
DEPARTMENT_RATES = {
    "Nabiał": "6.00", "Pieczywo": "2.50", "Mięso i wędliny": "9.00",
    "Ryby": "16.00", "Warzywa i owoce": "2.50", "Produkty suche": "5.00",
    "Przyprawy i sosy": "12.00", "Mrożonki": "4.00", "Konserwy": "4.00",
}
# Explicit generic price assumptions refine the broad baseline. A saffron
# gram, for example, must never inherit the price of a cheap dried herb.
FOOD_RATES = {
    "Mleko 2%": "1.00", "Mleko bez laktozy": "1.50", "Mleko kozie": "2.50",
    "Mleko migdałowe": "1.50", "Mleko kokosowe": "4.00", "Mleczko kokosowe light": "4.00",
    "Śmietanka kokosowa": "5.00", "Masło extra": "8.00", "Masło klarowane ghee": "12.00",
    "Jogurt naturalny": "2.00", "Jogurt grecki": "3.00", "Skyr naturalny": "4.00",
    "Kefir": "2.00", "Maślanka naturalna": "1.50", "Ser żółty gouda": "7.00",
    "Ser cheddar": "7.00", "Parmezan": "20.00", "Ser grana padano": "17.00",
    "Ser pecorino": "22.00", "Mozzarella": "8.00", "Ser feta": "9.00",
    "Ricotta": "6.00", "Mascarpone": "6.00", "Burrata": "14.00", "Ser halloumi": "10.00",
    "Pierś z kurczaka": "7.00", "Polędwiczki z kurczaka": "7.50", "Filet z indyka": "9.00",
    "Udka z kurczaka": "4.00", "Podudzia z kurczaka": "3.00", "Skrzydełka z kurczaka": "4.00",
    "Schab wieprzowy": "7.00", "Karkówka wieprzowa": "7.00", "Żeberka wieprzowe": "7.00",
    "Polędwiczka wieprzowa": "10.00", "Wołowina mielona": "9.00", "Stek wołowy": "22.00",
    "Wołowina na gulasz": "12.00", "Łosoś filet": "18.00", "Łosoś wędzony": "25.00",
    "Dorsz filet": "18.00", "Mintaj filet": "8.00", "Krewetki mrożone": "15.00",
    "Chleb pszenny": "1.80", "Mąka pszenna": "0.60", "Mąka pszenna pełnoziarnista": "1.20",
    "Mąka żytnia": "2.00", "Mąka orkiszowa": "3.00", "Mąka migdałowa": "12.00",
    "Mąka kokosowa": "6.00", "Mąka ziemniaczana": "4.00", "Skrobia kukurydziana": "3.00",
    "Ryż biały": "1.50", "Ryż brązowy": "2.00", "Ryż basmati": "2.50", "Ryż jaśminowy": "2.50",
    "Ryż arborio": "3.00", "Ryż dziki": "8.00", "Makaron penne": "2.00",
    "Makaron spaghetti": "2.00", "Makaron fusilli": "2.00", "Makaron tagliatelle": "3.00",
    "Makaron lasagne": "3.00", "Płatki owsiane": "2.00", "Kasza gryczana": "3.00",
    "Kasza jaglana": "3.00", "Soczewica czerwona": "2.50", "Soczewica zielona": "3.00",
    "Ciecierzyca sucha": "2.50", "Quinoa": "5.00", "Nasiona chia": "8.00",
    "Cukier": "1.15", "Cukier puder": "2.00", "Cukier trzcinowy": "2.00",
    "Olej rzepakowy": "2.50", "Olej słonecznikowy": "2.00", "Oliwa z oliwek": "9.00",
    "Olej sezamowy": "8.00", "Sól": "1.00", "Pieprz czarny mielony": "25.00",
    "Papryka słodka": "25.00", "Papryka wędzona": "27.00", "Papryka ostra": "25.00",
    "Bazylia suszona": "80.00", "Oregano": "80.00", "Tymianek suszony": "80.00",
    "Rozmaryn suszony": "80.00", "Estragon suszony": "90.00", "Zioła prowansalskie": "70.00",
    "Liść laurowy": "100.00", "Szafran": "4000.00", "Wanilia (cukier waniliowy)": "20.00",
    "Ekstrakt waniliowy": "70.00", "Cynamon": "25.00", "Cynamon cejloński": "50.00",
    "Kardamon mielony": "60.00", "Gałka muszkatołowa": "50.00", "Goździki mielone": "45.00",
    "Anyż gwiazdkowy": "50.00", "Czosnek granulowany": "20.00", "Kmin rzymski": "25.00",
    "Kurkuma mielona": "20.00", "Kolendra mielona": "20.00", "Curry w proszku": "20.00",
    "Miód": "6.00", "Masło orzechowe": "5.00", "Orzechy włoskie": "9.00",
    "Orzeszki ziemne": "4.00", "Orzechy nerkowca": "9.00", "Orzeszki piniowe": "30.00",
    "Orzechy pekan": "14.00", "Pistacje": "16.00", "Migdały płatki": "10.00",
    "Kakao ciemne": "10.00", "Czekolada gorzka": "12.00", "Płatki drożdżowe nieaktywne": "15.00",
    "Żelatyna": "25.00", "Agar": "50.00", "Proszek do pieczenia": "7.00",
    "Soda oczyszczona": "4.00", "Sos sojowy": "5.00", "Sos tamari": "9.00",
    "Sos rybny": "6.00", "Ocet balsamiczny": "6.00", "Ocet jabłkowy": "2.00",
    "Majonez": "3.00", "Ketchup": "3.00", "Pasta miso": "10.00", "Tahini": "8.00",
    "Pasta gochujang": "10.00", "Pasta curry czerwona": "8.00", "Pasta curry zielona": "8.00",
    "Pomidory": "2.50", "Pomidorki koktajlowe": "4.00", "Cebula": "1.10",
    "Cebula czerwona": "1.50", "Marchew": "0.90", "Ziemniaki": "1.00", "Bataty": "1.50",
    "Jabłka": "2.00", "Banan": "1.10", "Truskawki": "7.00", "Borówki": "10.00",
    "Maliny": "10.00", "Jeżyny": "10.00", "Winogrona jasne": "5.00", "Winogrona ciemne": "5.00",
    "Szpinak świeży": "6.00", "Rukola": "10.00", "Szparagi": "8.00", "Jarmuż": "5.00",
    "Mrożony szpinak": "2.00", "Mrożone warzywa mieszanka": "2.00", "Groszek zielony mrożony": "2.00",
    "Pomidory krojone": "1.70", "Passata pomidorowa": "1.50", "Koncentrat pomidorowy": "4.00",
    "Fasola konserwowa": "1.70", "Fasola biała konserwowa": "1.70", "Fasola czerwona konserwowa": "1.70",
}
PIECE_RATES = {
    "Bułka kajzerka": "0.25", "Jajka": "0.30", "Jajka przepiórcze": "0.25",
    "Ogórek": "0.80", "Kapusta biała": "0.80", "Kapusta czerwona": "0.90",
    "Kapusta pekińska": "1.20", "Seler naciowy": "0.75", "Papryka czerwona": "0.60",
    "Papryka żółta": "0.60", "Papryka zielona": "0.60", "Sałata lodowa": "0.75",
    "Czosnek": "0.08", "Awokado": "0.80", "Cytryna": "0.35", "Limonka": "0.25",
    "Brokuł": "0.80", "Cukinia": "0.60", "Bakłażan": "0.85", "Kalafior": "1.30",
    "Por": "0.50", "Tortilla pszenna": "0.20", "Mango": "0.90", "Kiwi": "0.30",
    "Grejpfrut": "0.45", "Ananas": "1.00", "Melon": "1.30", "Granat": "1.00",
    "Kaki": "0.60", "Rzodkiewka": "0.06", "Kalarepa": "0.65", "Koper włoski": "0.80",
    "Seler korzeniowy": "1.00", "Kukurydza kolba": "0.50", "Rzepa": "0.40",
    "Bulion warzywny": "0.12", "Bulion drobiowy": "0.12", "Bulion wołowy": "0.12", "Bulion grzybowy": "0.15",
}


@lru_cache(maxsize=1)
def _seeds():
    from app.db.seed import PRODUCTS_DATA, _uid
    return {_uid("product:" + row[0]): (row[0], row[1], row[3]) for row in PRODUCTS_DATA}


def _reference(product, unit):
    row = _seeds().get(product.id)
    if row is None or row[0] != product.name or row[1] != product.unit:
        return None
    name, seed_unit, department = row
    if seed_unit == "szt":
        rate = Decimal(PIECE_RATES.get(name, "0.60"))
        if unit == "szt":
            return rate, Decimal(1)
        factors = {Decimal(str(option["base_quantity"])) for option in product.measure_options or []
            if isinstance(option, dict) and option.get("code") == "szt"
            and option.get("base_unit") == unit and option.get("base_quantity") is not None}
        if len(factors) != 1:
            return None
        amount, = factors
        return (rate, amount) if amount.is_finite() and amount > 0 else None
    if canonical_base_unit(product) != unit:
        return None
    return Decimal(FOOD_RATES.get(name, DEPARTMENT_RATES[department])), Decimal(1000)


def quote_static_requirement(product, quantity, unit, *, store_id, as_of):
    if (product is None or product.review_status != "approved"
            or not is_uk_generic_seed(product, country_code="GB")
            or type(as_of) is not date or as_of < MODEL_DAY or isinstance(quantity, (bool, float))):
        return None
    try:
        quantity = Decimal(quantity)
        if not quantity.is_finite() or not 0 < quantity <= Decimal("9999999.999"):
            return None
        reference = _reference(product, unit)
        if reference is None:
            return None
        rate, reference_quantity = reference
        total = (rate * quantity / reference_quantity).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        # The display precision is one penny; never turn a positive cost into free food.
        total = max(Decimal("0.01"), total)
        if total > Decimal("99999999.99"):
            return None
        from app.services.uk_ons_pricing import NationalReferenceQuote
        from app.services.system_content_language import ingredient_display_name
        return NationalReferenceQuote(product.id, store_id,
            ingredient_display_name(product, country_code="GB"), quantity, unit, total,
            {"provider": "uk_catalogue_estimate", "model_version": MODEL_VERSION,
             "publisher": "Meal Planner", "checked_on": MODEL_DAY.isoformat(),
             "basis": "required_quantity_not_shop_price", "confirms_package": False,
             "confirms_store_stock": False, "canonical_product_id": str(product.id),
             "reference_price_gbp": str(rate), "reference_quantity": str(reference_quantity),
             "reference_unit": unit, "store_multiplier": "1.00",
             "note": "Static planning estimate, not an observed retailer price"})
    except (ValueError, TypeError, ArithmeticError, KeyError):
        return None


def frozen_static_reference(item, *, as_of):
    """Keep a checked historical estimate without repricing it after a store switch."""
    try:
        from app.services.uk_ons_pricing import NationalReferenceQuote, _fingerprint
        snapshot = item.regional_snapshot
        body = dict(snapshot.quote_data)
        fingerprint = body.pop("reference_fingerprint")
        source = body["price_source"]
        quantity, rate = Decimal(body["required_quantity"]), Decimal(source["reference_price_gbp"])
        reference = Decimal(source["reference_quantity"])
        total = Decimal(body["total_price"])
        values = (quantity, rate, reference, total)
        if (any(not value.is_finite() or value <= 0 for value in values)
                or max(values) > Decimal("99999999.99")
                or not item.is_checked or item.is_from_pantry or snapshot.quote_status != "quoted"
                or snapshot.country_code != "GB" or snapshot.currency_code != "GBP"
                or snapshot.offer_id is not None or snapshot.pricing_as_of > as_of
                or source["provider"] != "uk_catalogue_estimate" or source["model_version"] != MODEL_VERSION
                or source["publisher"] != "Meal Planner" or source["store_multiplier"] != "1.00"
                or date.fromisoformat(source["checked_on"]) > snapshot.pricing_as_of
                or source["canonical_product_id"] != str(snapshot.product_id)
                or source["basis"] != "required_quantity_not_shop_price"
                or source["confirms_package"] is not False or source["confirms_store_stock"] is not False
                or fingerprint != _fingerprint(body) or body["product_id"] != str(snapshot.product_id)
                or body["price_basis"] != "national_quantity_reference"
                or body["name_en"] != snapshot.name_en or body["price_is_estimated"] is not True
                or body["required_unit"] != snapshot.required_unit or item.unit != snapshot.required_unit
                or source["reference_unit"] != snapshot.required_unit or snapshot.required_unit not in {"g", "ml"}
                or quantity != snapshot.required_quantity or quantity != item.required_quantity
                or total != item.estimated_price
                or max(Decimal("0.01"), (rate * quantity / reference).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)) != total
                or set(body) != {"price_basis", "product_id", "name_en", "required_quantity",
                    "required_unit", "total_price", "price_is_estimated", "price_source"}):
            return None
        return NationalReferenceQuote(snapshot.product_id, snapshot.store_id, snapshot.name_en,
            quantity, snapshot.required_unit, total, source)
    except (AttributeError, KeyError, ValueError, TypeError, ArithmeticError):
        return None
