"""Eksport wszystkich modeli ORM i bazy deklaratywnej."""

from app.db.session import Base
from app.models.barcode_cache import BarcodeProductCache
from app.models.meal_plan import MealPlan, MealPlanEntry
from app.models.meal_plan_creation import MealPlanCreation
from app.models.device_token import DeviceToken
from app.models.wellness import ActivityLog, WaterLog, WeightLog
from app.models.moderation import BlockedUser, ContentReport
from app.models.product import (
    Allergen,
    Product,
    ProductAllergen,
    ProductSubstitute,
    StoreProduct,
)
from app.models.recipe import Recipe, RecipeIngredient, RecipeTag
from app.models.recipe_import_job import RecipeImportJob
from app.models.recipe_comment import RecipeComment, RecipeCommentLike
from app.models.recipe_favorite import RecipeFavorite
from app.models.shopping_list import ShoppingList, ShoppingListItem
from app.models.shopping_list_creation import ShoppingListCreation
from app.models.shopping_list_share import ShoppingListShare
from app.models.pantry import PantryItem
from app.models.processed_apple_purchase import ProcessedApplePurchase
from app.models.store import Store, StoreDepartment
from app.models.user import User, UserAllergen
from app.models.weekly_contest_payout import WeeklyContestPayout
from app.models.food_log import FoodLogEntry
from app.models.notification import Notification
from app.models.friendship import Friendship
from app.models.purchase_campaign import PurchaseCampaign

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
    "BarcodeProductCache",
    # Recipe
    "Recipe",
    "RecipeImportJob",
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
    "MealPlanCreation",
    # Shopping List
    "ShoppingList",
    "ShoppingListShare",
    "ShoppingListItem",
    "ShoppingListCreation",
    # Pantry
    "PantryItem",
    "ProcessedApplePurchase",
    # Food Log
    "FoodLogEntry",
    "Notification",
    "Friendship",
    "PurchaseCampaign",
    # Moderation
    "ContentReport",
    "BlockedUser",
    "DeviceToken",
    "WaterLog",
    "WeightLog",
    "ActivityLog",
]
