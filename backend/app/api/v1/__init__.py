"""Router API v1 — agreguje wszystkie podrzędne routery zasobów."""

from fastapi import APIRouter

from app.api.v1.auth import router as auth_router
from app.api.v1.meal_plans import router as meal_plans_router
from app.api.v1.products import router as products_router
from app.api.v1.promotions import router as promotions_router
from app.api.v1.recipes import router as recipes_router
from app.api.v1.recipe_comments import router as recipe_comments_router
from app.api.v1.notifications import router as notifications_router
from app.api.v1.shopping_lists import router as shopping_lists_router
from app.api.v1.stores import router as stores_router
from app.api.v1.users import router as users_router
from app.api.v1.food_log import router as food_log_router
from app.api.v1.price_compare import router as price_compare_router

router = APIRouter()

router.include_router(auth_router, prefix="/auth", tags=["Auth"])
router.include_router(users_router, prefix="/users", tags=["Users"])
router.include_router(stores_router, prefix="/stores", tags=["Stores"])
router.include_router(products_router, prefix="/products", tags=["Products"])
router.include_router(recipes_router, prefix="/recipes", tags=["Recipes"])
router.include_router(recipe_comments_router, prefix="/recipes", tags=["Recipe Comments"])
router.include_router(notifications_router, prefix="/notifications", tags=["Notifications"])
router.include_router(meal_plans_router, prefix="/meal-plans", tags=["Meal Plans"])
router.include_router(
    shopping_lists_router, prefix="/shopping-lists", tags=["Shopping Lists"]
)
router.include_router(food_log_router, prefix="/food-log", tags=["Food Log"])
router.include_router(price_compare_router, prefix="/price-compare", tags=["Price Comparison"])
router.include_router(promotions_router, prefix="/promotions", tags=["Promotions"])
