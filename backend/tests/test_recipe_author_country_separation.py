"""User-authored catalogues are separate even when all ingredients match UK."""
import asyncio
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

from app.api.deps import get_current_user, get_current_premium
from app.api.v1 import recipes, recipe_comments, shopping_lists, friends
from app.core.exceptions import AppException
from app.db.session import get_db
from app.models import Friendship, Recipe, RecipeIngredient, Store, StoreProduct, User
from app.models.recipe_favorite import RecipeFavorite
from app.models.friendship import canonical_friend_ids
from app.services.meal_plan_generator import MealPlanGenerator
from tests.test_regional_shopping import db, UK_STORES


@pytest.fixture(params=['PL', 'GB'])
def context(db, request, monkeypatch):
    session, adapter, _, product, _ = db
    viewer = User(id=uuid4(),country_code=request.param,role='user',is_premium=True,
        is_email_verified=True,email=f'viewer-{request.param}@example.invalid',password_hash='fixture')
    authors = {country:User(id=uuid4(), country_code=country,
        email=f'author-{country}@example.invalid', password_hash='fixture',
        display_name=f'Author {country}') for country in ('PL','GB')}
    pl_store = Store(id=uuid4(), name='Synthetic PL store', country_code='PL', currency_code='PLN')
    session.add_all([viewer,*authors.values(),pl_store])
    session.flush()
    session.add(StoreProduct(id=uuid4(), store_id=pl_store.id, product_id=product.id,
        price=Decimal('2.00'), is_available=True))
    rows = {}
    for key, author in [('PL',authors['PL']),('GB',authors['GB']),('system',None),('own',viewer)]:
        row = Recipe(id=uuid4(), name=key+' synthetic dish', meal_type='obiad',
            created_by_user_id=author.id if author else None, visibility='public',
            servings=1, is_active=True)
        row.ingredients = [RecipeIngredient(id=uuid4(), product_id=product.id,
            quantity=100, unit='g', is_optional=False)]
        rows[key] = row
        session.add(row)
    for author in authors.values():
        first,second=canonical_friend_ids(viewer.id,author.id)
        session.add(Friendship(id=uuid4(), user_a_id=first, user_b_id=second,
            requested_by_id=viewer.id,status='accepted'))
    session.commit()
    app = FastAPI()
    app.include_router(recipes.router, prefix='/recipes')
    app.include_router(recipe_comments.router, prefix='/recipes')
    app.include_router(shopping_lists.router, prefix='/shopping-lists')
    app.include_router(friends.router, prefix='/friends')
    @app.exception_handler(AppException)
    async def error_response(request, error):
        return JSONResponse(status_code=error.status_code, content={'detail':error.detail})
    app.dependency_overrides[get_db] = lambda:adapter
    app.dependency_overrides[get_current_user] = lambda:viewer
    app.dependency_overrides[get_current_premium] = lambda:viewer
    async def rollback():
        session.rollback()
    adapter.rollback=rollback
    monkeypatch.setattr('app.services.off_on_demand.refresh_public_recipe_evidence',AsyncMock())
    monkeypatch.setattr('app.core.rate_limit.enforce_user_rate_limit',lambda *args:None)
    monkeypatch.setattr('app.services.admin_notifications.notify_admins_pending_review',AsyncMock())
    return SimpleNamespace(session=session, db=adapter, viewer=viewer, authors=authors,
        rows=rows, client=TestClient(app), country=request.param, product=product,
        store_id=pl_store.id if request.param=='PL' else UK_STORES[0].id)


@pytest.mark.parametrize('mode',['catalogue','search','community','favourites','pagination'])
def test_lists_filter_by_author_country_before_pagination(context,mode):
    c=context
    for row in c.rows.values():
        c.session.add(RecipeFavorite(id=uuid4(),user_id=c.viewer.id,recipe_id=row.id))
    c.session.commit()
    params={'search':'synthetic'} if mode=='search' else {'community_only':True} if mode=='community' else {'favorites_only':True} if mode=='favourites' else {}
    if mode=='pagination':
        result=[]
        for offset in range(4):
            response=c.client.get('/recipes/',params={'skip':offset,'limit':1})
            assert response.status_code==200,response.text
            result.extend(response.json())
    else:
        response=c.client.get('/recipes/',params=params)
        assert response.status_code==200,response.text
        result=response.json()
    expected={str(c.rows[c.country].id),str(c.rows['own'].id)}
    if mode!='community':expected.add(str(c.rows['system'].id))
    assert {row['id'] for row in result}==expected
    assert len(result)==len(expected)


@pytest.mark.parametrize('route',['detail','comments','favourite','shopping','friend','available','match'])
def test_foreign_recipe_cannot_leak_through_other_routes(context,route,monkeypatch):
    c=context
    foreign='PL' if c.country=='GB' else 'GB'
    row=c.rows[foreign]
    if route=='detail':response=c.client.get(f'/recipes/{row.id}')
    elif route=='comments':response=c.client.get(f'/recipes/{row.id}/comments')
    elif route=='favourite':response=c.client.post(f'/recipes/{row.id}/favorite')
    elif route=='shopping':
        builder=AsyncMock(side_effect=AssertionError('A foreign recipe reached the builder'))
        monkeypatch.setattr(shopping_lists.ShoppingListBuilder,'build_from_meal_plan',builder)
        response=c.client.post('/shopping-lists/from-recipes',json={'store_id':str(c.store_id),'recipe_ids':[str(row.id)]})
        builder.assert_not_awaited()
    elif route=='friend':response=c.client.get(f'/friends/{c.authors[foreign].id}/recipes')
    elif route=='available':response=c.client.get('/recipes/available',params={'store_id':str(c.store_id)})
    else:response=c.client.post('/recipes/match-by-ingredients',json={'product_ids':[str(c.product.id)]})
    if route in {'friend','available','match'}:
        assert response.status_code==200,response.text
        result=response.json()
        assert str(row.id) not in {item.get('recipe',item)['id'] for item in result}
        if route=='friend':assert result==[]
    else:assert response.status_code==404,response.text


def test_generator_does_not_mix_country_catalogues(context):
    c=context
    actual=asyncio.run(MealPlanGenerator(c.db)._filter_eligible_recipes(
        allergen_ids=set(),store_id=c.store_id,user_id=c.viewer.id,country_code=c.country))
    assert {row.id for row in actual}=={c.rows[c.country].id,c.rows['own'].id,c.rows['system'].id}


def test_comment_notification_does_not_reintroduce_foreign_recipe(context):
    c=context
    candidates={c.viewer.id,*[author.id for author in c.authors.values()]}
    for country in ('PL','GB'):
        actual=asyncio.run(recipe_comments._notification_recipients(c.db,c.rows[country],candidates))
        assert {user.id for user in actual}=={user.id for user in [c.viewer,*c.authors.values()] if user.country_code==country}


def test_same_market_recipe_and_owner_remain_accessible(context):
    c=context
    for key in (c.country,'own','system'):
        response=c.client.get(f'/recipes/{c.rows[key].id}')
        assert response.status_code==200,response.text
    c.rows['own'].visibility='private'
    c.session.commit()
    assert c.client.get(f'/recipes/{c.rows["own"].id}').status_code==200
    response=c.client.get('/recipes/mine')
    assert response.status_code==200,response.text
    assert {row['id'] for row in response.json()}=={str(c.rows['own'].id)}


def test_friendship_does_not_share_private_recipes_across_countries(context):
    c=context
    foreign='PL' if c.country=='GB' else 'GB'
    row=c.rows[foreign]
    row.visibility='private'
    c.session.commit()
    assert c.client.get(f'/recipes/{row.id}').status_code==404
    assert c.client.get(f'/recipes/{row.id}/comments').status_code==404
    response=c.client.get(f'/friends/{c.authors[foreign].id}/recipes')
    assert response.status_code==200,response.text
    assert response.json()==[]
