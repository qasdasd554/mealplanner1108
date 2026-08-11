import asyncio
from sqlalchemy import select, func
from app.db.session import async_session_factory
from app.models import Store, Recipe

async def check_db():
    async with async_session_factory() as db:
        stores_count = await db.execute(select(func.count(Store.id)))
        recipes_count = await db.execute(select(func.count(Recipe.id)))
        
        stores = await db.execute(select(Store.name))
        
        print("--- DB CHECK ---")
        print(f"Stores count: {stores_count.scalar()}")
        print(f"Recipes count: {recipes_count.scalar()}")
        print(f"Store names: {[r[0] for r in stores.all()]}")

if __name__ == "__main__":
    asyncio.run(check_db())
