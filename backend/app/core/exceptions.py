"""Niestandardowe wyjątki domenowe aplikacji."""

from __future__ import annotations

import uuid


class AppException(Exception):
    """Bazowy wyjątek aplikacji z kodem HTTP i komunikatem.

    Attributes:
        status_code: Kod odpowiedzi HTTP.
        detail: Opis błędu zwracany klientowi.
    """

    def __init__(self, status_code: int = 500, detail: str = "Wewnętrzny błąd serwera") -> None:
        self.status_code = status_code
        self.detail = detail
        self.error_code = None
        super().__init__(detail)


class NotFoundException(AppException):
    """Zasób nie został znaleziony (HTTP 404)."""

    def __init__(self, detail: str = "Nie znaleziono zasobu") -> None:
        super().__init__(status_code=404, detail=detail)


class ProductUnavailableException(AppException):
    """Produkt jest niedostępny w wybranym sklepie (HTTP 409)."""

    def __init__(self, product_id: uuid.UUID, store_id: uuid.UUID) -> None:
        detail = (
            f"Produkt {product_id} jest niedostępny w sklepie {store_id}."
        )
        super().__init__(status_code=409, detail=detail)
        self.product_id = product_id
        self.store_id = store_id


class InsufficientRecipesException(AppException):
    """Nie znaleziono wystarczającej liczby przepisów dla podanych filtrów (HTTP 422)."""

    def __init__(self, filters: dict) -> None:
        detail = (
            f"Nie znaleziono wystarczającej liczby przepisów dla filtrów: {filters}"
        )
        super().__init__(status_code=422, detail=detail)
        self.filters = filters
