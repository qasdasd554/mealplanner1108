"""Eksport wszystkich modeli ORM i bazy deklaratywnej."""

from app.db.session import Base
from app.models.meal_plan import MealPlan, MealPlanEntry
from app.models.product import (
    Allergen,
    Product,
    ProductAllergen,
    ProductSubstitute,
    StoreProduct,
)
from app.models.recipe import Recipe, RecipeIngredient, RecipeTag
from app.models.shopping_list import ShoppingList, ShoppingListItem
from app.models.store import Store, StoreDepartment
from app.models.user import User, UserAllergen
from app.models.food_log import FoodLogEntry

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
    # User
    "User",
    "UserAllergen",
    # Meal Plan
    "MealPlan",
    "MealPlanEntry",
    # Shopping List
    "ShoppingList",
    "ShoppingListItem",
    # Food Log
    "FoodLogEntry",
]