"""Endpointy komentarzy, zdjęć i polubień pod przepisami.

Zdjęcia komentarzy są przechowywane w bazie danych (Base64), NIE na
dysku serwera — Render nie ma trwałego systemu plików, więc pliki
zapisane lokalnie znikałyby przy każdym wdrożeniu. Szczegóły w
app/models/recipe_comment.py.
"""

import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.models.notification import Notification
from app.models.recipe import Recipe
from app.models.recipe_comment import RecipeComment, RecipeCommentLike
from app.models.user import User
from app.schemas.recipe_comment import RecipeCommentCreate, RecipeCommentResponse

router = APIRouter()


async def _notify_thread_participants(
    db: AsyncSession, recipe: Recipe, new_comment: RecipeComment, author: User
) -> None:
    """Tworzy powiadomienia dla użytkowników zainteresowanych tym
    przepisem (poza samym autorem nowego komentarza) — z DWÓCH źródeł:

    1. Osoby, które wcześniej skomentowały TEN SAM przepis — jak wątek
       dyskusji: "byłeś w tej rozmowie, oto nowa odpowiedź".
    2. Osoby, które mają ten przepis w ULUBIONYCH — skoro komuś ten
       przepis się podoba na tyle, żeby go zapisać, prawdopodobnie
       zainteresuje go nowa opinia/wskazówka pod nim, nawet jeśli sam
       jeszcze nic nie napisał.

    Przepisy w aplikacji są wspólne dla wszystkich, nie ma jeszcze pojęcia
    "mój przepis" (funkcja dodawania własnych przepisów jest dopiero
    zapowiedziana) — stąd te dwa źródła, a nie "ktoś skomentował Twój
    przepis".

    Jeśli ktoś jest w OBU grupach naraz (skomentował I ma w ulubionych),
    dostaje tylko JEDNO powiadomienie — zbiór (`set`) sam eliminuje
    duplikaty ID.
    """
    from app.models.recipe_favorite import RecipeFavorite

    thread_result = await db.execute(
        select(RecipeComment.user_id)
        .where(
            RecipeComment.recipe_id == recipe.id,
            RecipeComment.user_id != author.id,
        )
        .distinct()
    )
    favorite_result = await db.execute(
        select(RecipeFavorite.user_id).where(
            RecipeFavorite.recipe_id == recipe.id,
            RecipeFavorite.user_id != author.id,
        )
    )
    recipient_ids = set(thread_result.scalars().all()) | set(favorite_result.scalars().all())
    if not recipient_ids:
        return

    preview = (new_comment.text or "").strip()
    if len(preview) > 80:
        preview = preview[:80].rstrip() + "…"
    elif not preview:
        preview = "dodał(a) zdjęcie"

    author_name = author.display_name or "Ktoś"
    message = f'{author_name} skomentował(a) "{recipe.name}": {preview}'

    for user_id in recipient_ids:
        db.add(
            Notification(
                user_id=user_id,
                notification_type="recipe_comment",
                message=message,
                recipe_id=recipe.id,
                comment_id=new_comment.id,
            )
        )
    await db.commit()


def _to_response(
    comment: RecipeComment, like_count: int, liked_by_me: bool
) -> RecipeCommentResponse:
    return RecipeCommentResponse(
        id=comment.id,
        recipe_id=comment.recipe_id,
        user_id=comment.user_id,
        author_name=comment.user.display_name or "Użytkownik",
        text=comment.text,
        photo_base64=comment.photo_base64,
        created_at=comment.created_at,
        like_count=like_count,
        liked_by_me=liked_by_me,
    )


@router.get("/{recipe_id}/comments", response_model=List[RecipeCommentResponse])
async def list_recipe_comments(
    recipe_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Zwraca komentarze pod przepisem, od najnowszych, wraz z liczbą
    polubień i informacją, czy zalogowany użytkownik już polubił dany
    komentarz."""
    result = await db.execute(
        select(RecipeComment)
        .where(RecipeComment.recipe_id == recipe_id)
        .options(selectinload(RecipeComment.user), selectinload(RecipeComment.likes))
        .order_by(RecipeComment.created_at.desc())
    )
    comments = result.scalars().all()
    return [
        _to_response(
            c,
            like_count=len(c.likes),
            liked_by_me=any(like.user_id == current_user.id for like in c.likes),
        )
        for c in comments
    ]


@router.post(
    "/{recipe_id}/comments",
    response_model=RecipeCommentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_recipe_comment(
    recipe_id: uuid.UUID,
    payload: RecipeCommentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Dodaje komentarz (tekst i/lub zdjęcie) pod przepisem.

    Limit: 30 komentarzy na godzinę na użytkownika — ochrona przed spamem
    (w tym spamem zdjęciami, które trafiają bezpośrednio do bazy danych).
    """
    from app.core.rate_limit import comment_creation_limiter, enforce_user_rate_limit

    enforce_user_rate_limit(comment_creation_limiter, current_user.id, "dodawanie komentarzy")

    if not payload.text and not payload.photo_base64:
        raise HTTPException(
            status_code=400,
            detail="Komentarz musi zawierać tekst, zdjęcie, albo oba naraz.",
        )

    recipe = await db.get(Recipe, recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Nie znaleziono przepisu")

    comment = RecipeComment(
        recipe_id=recipe_id,
        user_id=current_user.id,
        text=payload.text,
        photo_base64=payload.photo_base64,
    )
    db.add(comment)
    await db.commit()
    await db.refresh(comment)
    comment.user = current_user

    # ── Powiadom osoby, które wcześniej komentowały ten sam przepis ──
    # Przepisy w aplikacji są wspólne dla wszystkich (nie ma jeszcze
    # pojęcia "mój przepis"), więc najsensowniejsze powiadomienie to
    # "nowa odpowiedź w wątku, w którym już brałeś udział". Sam autor
    # nowego komentarza NIE dostaje powiadomienia o własnym komentarzu.
    await _notify_thread_participants(db, recipe=recipe, new_comment=comment, author=current_user)

    # Świeżo utworzony komentarz na pewno ma zero polubień — wiemy to z
    # samego faktu, że dopiero co powstał, więc NIE dotykamy relacji
    # `.likes` w ogóle (dotknięcie jej próbowałoby ją leniwie doczytać,
    # co w kontekście async rzuca MissingGreenlet).
    return _to_response(comment, like_count=0, liked_by_me=False)


@router.delete("/{recipe_id}/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_recipe_comment(
    recipe_id: uuid.UUID,
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Usuwa komentarz. Zwykły użytkownik może usuwać tylko własne;
    administrator (rola "admin") może usunąć KAŻDY komentarz —
    potrzebne do moderacji treści."""
    comment = await db.get(RecipeComment, comment_id)
    if not comment or comment.recipe_id != recipe_id:
        raise HTTPException(status_code=404, detail="Nie znaleziono komentarza")
    if comment.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Możesz usuwać tylko własne komentarze")

    await db.delete(comment)
    await db.commit()


@router.post("/{recipe_id}/comments/{comment_id}/like", status_code=status.HTTP_204_NO_CONTENT)
async def like_recipe_comment(
    recipe_id: uuid.UUID,
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Polub komentarz. Idempotentne — polubienie już polubionego
    komentarza nic nie zmienia (nie zwraca błędu)."""
    comment = await db.get(RecipeComment, comment_id)
    if not comment or comment.recipe_id != recipe_id:
        raise HTTPException(status_code=404, detail="Nie znaleziono komentarza")

    existing = await db.execute(
        select(RecipeCommentLike).where(
            RecipeCommentLike.comment_id == comment_id,
            RecipeCommentLike.user_id == current_user.id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        return  # już polubione — nic do zrobienia

    like = RecipeCommentLike(comment_id=comment_id, user_id=current_user.id)
    db.add(like)
    try:
        await db.commit()
    except IntegrityError:
        # Wyścig: dwa równoległe żądania polubienia w tym samym momencie —
        # ograniczenie unikalności w bazie i tak to obsłuży poprawnie,
        # więc po prostu wycofujemy i traktujemy jako sukces (idempotentnie).
        await db.rollback()


@router.delete("/{recipe_id}/comments/{comment_id}/like", status_code=status.HTTP_204_NO_CONTENT)
async def unlike_recipe_comment(
    recipe_id: uuid.UUID,
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cofnij polubienie. Idempotentne — jeśli nie było polubione, nic
    się nie dzieje (nie zwraca błędu)."""
    comment = await db.get(RecipeComment, comment_id)
    if not comment or comment.recipe_id != recipe_id:
        raise HTTPException(status_code=404, detail="Nie znaleziono komentarza")

    existing = await db.execute(
        select(RecipeCommentLike).where(
            RecipeCommentLike.comment_id == comment_id,
            RecipeCommentLike.user_id == current_user.id,
        )
    )
    like = existing.scalar_one_or_none()
    if like is not None:
        await db.delete(like)
        await db.commit()
