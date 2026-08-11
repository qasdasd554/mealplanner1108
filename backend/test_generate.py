import asyncio
import sys
import uuid
from app.db.session import async_session_factory
from app.services.meal_plan_generator import MealPlanGenerator
from sqlalchemy import select
from app.models.user import User
from app.models.store import Store

async def test_gen():
    async with async_session_factory() as db:
        user_res = await db.execute(select(User).limit(1))
        user = user_res.scalar_one_or_none()
        
        store_res = await db.execute(select(Store).limit(1))
        store = store_res.scalar_one_or_none()
        
        if not user or not store:
            print("No user or store")
            return
            
        generator = MealPlanGenerator(db)
        try:
            plan = await generator.generate(
                user_id=user.id,
                store_id=store.id,
                duration_days=3,
                meals_per_day=3,
                max_budget=100.0,
                preferences={}
            )
            print("SUCCESS:", plan.id)
        except Exception as e:
            print("ERROR:")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_gen())
