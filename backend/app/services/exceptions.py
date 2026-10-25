"""Wyjątki warstwy serwisowej Smart Meal Planner."""

from __future__ import annotations

from uuid import UUID


class ServiceError(Exception):
    """Bazowy wyjątek serwisowy."""

    def __init__(self, message: str = "Wystąpił błąd w warstwie serwisowej") -> None:
        self.message = message
        super().__init__(self.message)


class InsufficientRecipesError(ServiceError):
    """Zbyt mało przepisów, aby wypełnić plan posiłków."""

    def __init__(
        self,
        meal_type: str,
        required: int,
        available: int,
    ) -> None:
        self.meal_type = meal_type
        self.required = required
        self.available = available
        super().__init__(
            f"Niewystarczająca liczba przepisów dla '{meal_type}': "
            f"wymagane {required}, dostępne {available}."
        )


class UserNotFoundError(ServiceError):
    """Nie znaleziono użytkownika o podanym ID."""

    def __init__(self, user_id: UUID) -> None:
        self.user_id = user_id
        super().__init__(f"Nie znaleziono użytkownika: {user_id}")


class StoreNotFoundError(ServiceError):
    """Nie znaleziono sklepu o podanym ID."""

    def __init__(self, store_id: UUID) -> None:
        self.store_id = store_id
        super().__init__(f"Nie znaleziono sklepu: {store_id}")


class MealPlanNotFoundError(ServiceError):
    """Nie znaleziono planu posiłków o podanym ID."""

    def __init__(self, meal_plan_id: UUID) -> None:
        self.meal_plan_id = meal_plan_id
        super().__init__(f"Nie znaleziono planu posiłków: {meal_plan_id}")


class ShoppingListNotFoundError(ServiceError):
    """Nie znaleziono listy zakupów o podanym ID."""

    def __init__(self, shopping_list_id: UUID) -> None:
        self.shopping_list_id = shopping_list_id
        super().__init__(f"Nie znaleziono listy zakupów: {shopping_list_id}")


class ProductNotFoundError(ServiceError):
    """Nie znaleziono produktu o podanym ID."""

    def __init__(self, product_id: UUID) -> None:
        self.product_id = product_id
        super().__init__(f"Nie znaleziono produktu: {product_id}")


class StoreProductNotFoundError(ServiceError):
    """Nie znaleziono pozycji sklepowej o podanym ID."""

    def __init__(self, store_product_id: UUID) -> None:
        self.store_product_id = store_product_id
        super().__init__(f"Nie znaleziono pozycji sklepowej: {store_product_id}")


class NoSubstituteFoundError(ServiceError):
    """Nie znaleziono substytutu produktu."""

    def __init__(self, product_id: UUID, store_id: UUID) -> None:
        self.product_id = product_id
        self.store_id = store_id
        super().__init__(
            f"Brak substytutu dla produktu {product_id} w sklepie {store_id}."
        )


def service_error_text(error: ServiceError, *, country_code: str) -> str:
    """Keep Polish diagnostics and status codes; localise UK response copy.

    Exception attributes, not Polish text parsing, carry variable values.
    Unknown service failures must not leak a Polish/internal message into UK.
    """
    if country_code != "GB":
        return str(error)
    if isinstance(error, InsufficientRecipesError):
        meals = {"śniadanie": "breakfast", "obiad": "lunch", "kolacja": "dinner",
            "przekąska": "snack", "deser": "dessert"}
        meal = meals.get(error.meal_type, "the selected meal")
        return (f"Not enough recipes for {meal}: {error.required} required, "
            f"{error.available} available. Try a different diet or meal selection.")
    if isinstance(error, StoreNotFoundError):
        return "The selected shop was not found. Please select it again."
    if isinstance(error, UserNotFoundError):
        return "Your account was not found. Please sign in again."
    if isinstance(error, MealPlanNotFoundError):
        return "The meal plan was not found."
    if isinstance(error, ShoppingListNotFoundError):
        return "The shopping list was not found."
    if isinstance(error, (ProductNotFoundError, StoreProductNotFoundError)):
        return "One of the selected products was not found."
    known = {
        "Plan można utworzyć dla 1–8 osób.": "A plan can be created for 1–8 people.",
        "Cel kaloryczny musi wynosić 800–6000 kcal na osobę.": "The calorie target must be 800–6000 kcal per person.",
        "Wybierz poprawną dietę w ustawieniach planu.": "Choose a valid diet in your plan settings.",
        "Nieznana dieta. Wybierz ją ponownie w ustawieniach planu.": "This diet was not recognised. Please select it again in your plan settings.",
    }
    return known.get(str(error), "Could not prepare your plan. Please check your settings and try again.")
