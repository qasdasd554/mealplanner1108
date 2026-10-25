"""Market-specific projections, never edits to canonical product identities."""

from app.schemas.product import ProductResponse
from app.services.system_content_language import is_system_ingredient


def is_uk_generic_seed(product, *, country_code: str) -> bool:
    return (country_code == "GB" and getattr(product, "barcode", None) is None
            and is_system_ingredient(product))


def product_brand_for_market(product, *, country_code: str):
    # A reviewed UK food-concept link does not attest sale of its PL example
    # brand. Exact coded SKUs and authored food retain their actual identity.
    return None if is_uk_generic_seed(product, country_code=country_code) else product.brand


def product_for_market(product, *, country_code: str):
    """Hide PL example brand/pack in a GB generic-food response, without writes.

    Keep food-level measures (piece/spoon/glass), units and nutrition. Reviewed
    local SKU pack facts are separate fields on StoreProductResponse; do not
    copy them into the shared generic product or infer them from an OFF link.
    """
    if not is_uk_generic_seed(product, country_code=country_code):
        return product
    response = ProductResponse.model_validate(product)
    measures = None if response.measure_options is None else [
        option for option in response.measure_options
        if option.code.casefold() not in {"opak", "opakowanie", "pack", "package"}
    ]
    return response.model_copy(update=dict(brand=None, serving_quantity=None,
        measure_options=measures, submitted_price=None))
