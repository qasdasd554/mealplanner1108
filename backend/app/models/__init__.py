"""Eksport wszystkich modeli ORM i bazy deklaratywnej."""

from app.db.session import Base
from app.models.meal_plan import MealPlan, MealPlanEntry
from app.models.moderation import BlockedUser, ContentReport
from app.models.product import (
    Allergen,
    Product,
    ProductAllergen,
    ProductSubstitute,
    StoreProduct,
)
from app.models.recipe import Recipe, RecipeIngredient, RecipeTag
from app.models.recipe_comment import RecipeComment, RecipeCommentLike
from app.models.recipe_favorite import RecipeFavorite
from app.models.shopping_list import ShoppingList, ShoppingListItem
from app.models.shopping_list_share import ShoppingListShare
from app.models.pantry import PantryItem
from app.models.processed_apple_purchase import ProcessedApplePurchase
from app.models.store import Store, StoreDepartment
from app.models.user import User, UserAllergen
from app.models.weekly_contest_payout import WeeklyContestPayout
from app.models.food_log import FoodLogEntry
from app.models.notification import Notification

__all__ = [
    "Base",
    # Store
    "Store",
    "StoreDepartment",
    # Product
    "Product",
    "StoreProduct",
    "ProductSubstitute",
    "Allergen",
    "ProductAllergen",
    # Recipe
    "Recipe",
    "RecipeTag",
    "RecipeIngredient",
    "RecipeComment",
    "RecipeCommentLike",
    "RecipeFavorite",
    # User
    "User",
    "WeeklyContestPayout",
    "UserAllergen",
    # Meal Plan
    "MealPlan",
    "MealPlanEntry",
    # Shopping List
    "ShoppingList",
    "ShoppingListShare",
    "ShoppingListItem",
    # Pantry
    "PantryItem",
    "ProcessedApplePurchase",
    # Food Log
    "FoodLogEntry",
    "Notification",
    # Moderation
    "ContentReport",
    "BlockedUser",
]