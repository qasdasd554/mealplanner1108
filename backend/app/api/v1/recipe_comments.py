"""Endpointy komentarzy, zdjęć i polubień pod przepisami.

Zdjęcia komentarzy są przechowywane w bazie danych (Base64), NIE na
dysku serwera — Render nie ma trwałego systemu plików, więc pliki
zapisane lokalnie znikałyby przy każdym wdrożeniu. Szczegóły w
app/models/recipe_comment.py.
"""

import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.core.markets import account_country
from app.core.exceptions import NotFoundException
from app.models.friendship import Friendship
from app.models.notification import Notification
from app.models.recipe import Recipe, RecipeIngredient
from app.models.recipe_comment import RecipeComment, RecipeCommentLike
from app.models.user import User
from app.schemas.moderation import ContentReportCreate, ContentReportResponse
from app.schemas.recipe_comment import RecipeCommentCreate, RecipeCommentResponse
from app.services.moderation import get_blocked_user_ids
from app.services.market_catalog import ensure_recipe_available_in_market
from app.services.recipe_access import ensure_recipe_access
from app.services.notification_language import notification_text

router = APIRouter()


async def _accessible_recipe(db: AsyncSession, recipe_id: uuid.UUID, user: User) -> Recipe:
    """A recipe UUID must not bypass its permissions through comment routes.

    Authors and moderators retain access to their editing/review workspace.
    For everyone else, UK availability is checked just as on recipe detail.
    Load nutrition/measure relationships only for that UK check, not for every
    Polish comment request.
    """
    recipe = await db.get(Recipe, recipe_id)
    await ensure_recipe_access(db, recipe, user)
    if (account_country(user) == "GB"
            and recipe.created_by_user_id != user.id and user.role != "admin"):
        result = await db.execute(
            select(Recipe)
            .options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product))
            .where(Recipe.id == recipe_id)
        )
        recipe = result.scalar_one()
        await ensure_recipe_available_in_market(db, recipe, user)
    return recipe


async def _notification_recipients(db: AsyncSession, recipe: Recipe, candidate_ids: set[uuid.UUID]) -> list[User]:
    """Historical participation is not permanent access to future comments.

    Batch-load accounts and accepted friendships. UK eligibility is the same
    for all ordinary GB recipients, so evaluate it once, never once per user.
    """
    if not candidate_ids or not recipe.is_active:
        return []
    users = (await db.execute(select(User).where(User.id.in_(candidate_ids)))).scalars().all()
    author_id = recipe.created_by_user_id
    public = author_id is None or recipe.visibility == "public"
    friend_ids = set()
    if not public and recipe.visibility == "private":
        friendships = await db.execute(select(Friendship.user_a_id, Friendship.user_b_id).where(
            Friendship.status == "accepted",
            or_(
                and_(Friendship.user_a_id == author_id, Friendship.user_b_id.in_(candidate_ids)),
                and_(Friendship.user_b_id == author_id, Friendship.user_a_id.in_(candidate_ids)),
            ),
        ))
        for first, second in friendships.all():
            friend_ids.add(second if first == author_id else first)
    users = [user for user in users if (
        public or user.id == author_id or user.role == "admin" or user.id in friend_ids
    )]
    gb_readers = [user for user in users if (
        account_country(user) == "GB" and user.id != author_id and user.role != "admin"
    )]
    if gb_readers:
        result = await db.execute(
            select(Recipe)
            .options(selectinload(Recipe.ingredients).selectinload(RecipeIngredient.product))
            .where(Recipe.id == recipe.id)
        )
        loaded_recipe = result.scalar_one()
        try:
            await ensure_recipe_available_in_market(db, loaded_recipe, gb_readers[0])
        except NotFoundException:
            denied_ids = {user.id for user in gb_readers}
            users = [user for user in users if user.id not in denied_ids]
    return users


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

    # AUTOR PRZEPISU — najważniejszy odbiorca, a wcześniej go tu NIE było.
    # Ta funkcja powstała, gdy przepisy były wyłącznie wspólnym katalogiem
    # bez autora (patrz docstring wyżej). Odkąd użytkownicy publikują
    # własne przepisy (`created_by_user_id`), autor musi dostać
    # powiadomienie o komentarzu pod SWOIM przepisem — nawet jeśli sam
    # nic w wątku nie napisał i nie ma go w ulubionych.
    if recipe.created_by_user_id and recipe.created_by_user_id != author.id:
        recipient_ids.add(recipe.created_by_user_id)

    recipients = await _notification_recipients(db, recipe, recipient_ids)
    if not recipients:
        return

    preview = (new_comment.text or "").strip()
    if len(preview) > 80:
        preview = preview[:80].rstrip() + "…"
    created = []
    for recipient in recipients:
        n = Notification(
            user_id=recipient.id,
            notification_type="recipe_comment",
            message=notification_text(recipient,
                f'{author.display_name or "Ktoś"} skomentował(a) "{recipe.name}": {preview or "dodał(a) zdjęcie"}',
                f'{author.display_name or "Someone"} commented on "{recipe.name}": {preview or "added a photo"}',
            ),
            recipe_id=recipe.id,
            comment_id=new_comment.id,
        )
        created.append(n)
        db.add(n)
    await db.commit()

    # Push wysyłany PO zapisie — patrz komentarz przy push_for_notification.
    await _send_pushes(db, created)


def _to_response(
    comment: RecipeComment, like_count: int, liked_by_me: bool
) -> RecipeCommentResponse:
    return RecipeCommentResponse(
        id=comment.id,
        recipe_id=comment.recipe_id,
        user_id=comment.user_id,
        author_name=comment.user.display_name or "Użytkownik",
        author_avatar=comment.user.avatar,
        author_avatar_photo=comment.user.avatar_photo_base64,
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
    komentarz. Komentarze autorów zablokowanych przez bieżącego
    użytkownika są pomijane (patrz Guideline 1.2 Apple — blokada musi
    faktycznie ukrywać treść, nie tylko istnieć jako przycisk)."""
    await _accessible_recipe(db, recipe_id, current_user)
    blocked_ids = await get_blocked_user_ids(db, current_user.id)
    query = (
        select(RecipeComment)
        .where(RecipeComment.recipe_id == recipe_id)
        .options(selectinload(RecipeComment.user), selectinload(RecipeComment.likes))
        .order_by(RecipeComment.created_at.desc())
    )
    if blocked_ids:
        query = query.where(RecipeComment.user_id.not_in(blocked_ids))
    result = await db.execute(query)
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

    recipe = await _accessible_recipe(db, recipe_id, current_user)

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
    # Cleanup and moderation remain possible after a recipe becomes private,
    # inactive or unavailable locally. This path returns no recipe content;
    # ownership/admin checks below still forbid deleting anybody else's note.
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
    recipe = await _accessible_recipe(db, recipe_id, current_user)
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
        return

    # Powiadomienie dla autora komentarza. Świadomie NIE powiadamiamy
    # o polubieniu WŁASNEGO komentarza — to jedyny przypadek, w którym
    # użytkownik dostawałby wiadomość o czymś, co sam przed chwilą zrobił.
    if comment.user_id != current_user.id:
        recipients = await _notification_recipients(db, recipe, {comment.user_id})
        if not recipients:
            return
        n = Notification(
            user_id=comment.user_id,
            notification_type="comment_like",
            message=(
                notification_text(recipients[0],
                    f"{current_user.display_name or 'Ktoś'} polubił(a) Twój komentarz.",
                    f"{current_user.display_name or 'Someone'} liked your comment.",
                )
            ),
            recipe_id=recipe_id,
            comment_id=comment_id,
        )
        db.add(n)
        await db.commit()
        await _send_pushes(db, [n])


@router.delete("/{recipe_id}/comments/{comment_id}/like", status_code=status.HTTP_204_NO_CONTENT)
async def unlike_recipe_comment(
    recipe_id: uuid.UUID,
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cofnij polubienie. Idempotentne — jeśli nie było polubione, nic
    się nie dzieje (nie zwraca błędu)."""
    await _accessible_recipe(db, recipe_id, current_user)
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


@router.post(
    "/{recipe_id}/comments/{comment_id}/report",
    response_model=ContentReportResponse,
    status_code=status.HTTP_201_CREATED,
)
async def report_recipe_comment(
    recipe_id: uuid.UUID,
    comment_id: uuid.UUID,
    payload: ContentReportCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Zgłasza komentarz do rozpatrzenia przez administratora
    (Apple Guideline 1.2). Nie usuwa ani nie ukrywa komentarza
    automatycznie — to robi admin po rozpatrzeniu zgłoszenia."""
    from app.core.rate_limit import content_report_limiter, enforce_user_rate_limit
    from app.models import ContentReport

    enforce_user_rate_limit(content_report_limiter, current_user.id, "zgłaszanie treści")

    await _accessible_recipe(db, recipe_id, current_user)
    comment = await db.get(RecipeComment, comment_id)
    if not comment or comment.recipe_id != recipe_id:
        raise HTTPException(status_code=404, detail="Nie znaleziono komentarza")

    report = ContentReport(
        reporter_user_id=current_user.id,
        content_type="comment",
        content_id=comment_id,
        reason=payload.reason,
        details=payload.details,
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)

    from app.services.admin_notifications import notify_admins_pending_review

    await notify_admins_pending_review(
        db,
        notification_type="content_report_pending",
        message=(
            f'{current_user.display_name or "Użytkownik"} zgłosił(a) komentarz '
            "do moderacji."
        ),
        english_message=f'{current_user.display_name or "A user"} reported a comment for moderation.',
        recipe_id=recipe_id,
    )
    return report

async def _send_pushes(db, notifications) -> None:
    """Wysyła push dla listy powiadomień — PO ich zapisaniu w bazie.
    Cicho pomijane, gdy push jest wyłączony (brak klucza FCM)."""
    from app.services.push import is_push_enabled, push_for_notification

    if not is_push_enabled():
        return
    for n in notifications:
        await push_for_notification(db, n)
