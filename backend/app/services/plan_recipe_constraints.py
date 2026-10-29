"""Diet/allergen SQL guards shared by the plan picker and swap write.

Caller must authorize the plan first. Ordinary catalogue browsing is not
restricted; these guards apply to selecting a dish for a configured plan.
"""
from sqlalchemy import or_, select

from app.models import Allergen, Product, Recipe, RecipeIngredient, RecipeTag
from app.models.user import UserAllergen
from app.services.recipe_diet_filter import recipe_diet_tag


async def plan_recipe_constraints(db, plan, user):
    saved = getattr(user, "dietary_preferences", None) or {}
    fallback = saved.get("diet") if isinstance(saved, dict) else None
    tag = recipe_diet_tag((plan.preferences or {}).get("diet", fallback))
    conditions = [Recipe.tags.any(RecipeTag.tag == tag)] if tag else []
    allergens = (await db.execute(select(UserAllergen.allergen_id).where(
        UserAllergen.user_id == user.id))).scalars().all()
    if allergens:
        contains = Product.allergens.any(Allergen.id.in_(allergens))
        unknown = Product.nutrition_per_100["_source"]["allergens_checked"].as_boolean().is_(False)
        blocked_products = select(Product.id).where(or_(contains, unknown))
        blocked_recipes = select(RecipeIngredient.recipe_id).where(
            RecipeIngredient.product_id.in_(blocked_products))
        conditions.append(Recipe.id.not_in(blocked_recipes))
    return conditions
