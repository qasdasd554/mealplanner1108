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
