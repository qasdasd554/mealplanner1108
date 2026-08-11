import asyncio
from app.db.session import engine, Base
from app.models import * # Import all models

async def recreate_db():
    print("Dropping all tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    
    print("Creating all tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    print("Done!")

if __name__ == "__main__":
    asyncio.run(recreate_db())
