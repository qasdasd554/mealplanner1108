import asyncio
from app.db.session import async_session_factory
from app.db.seed import seed_database
import sys

async def test_seed():
    print("Rozpoczynam test seedowania bazy danych...")
    async with async_session_factory() as db:
        try:
            await seed_database(db)
            await db.commit()
            print("SUKCES: Baza danych zostala pomyslnie zasilona danymi!")
        except Exception as e:
            print("BLAD: Seedowanie zakonczylo sie wyjatkiem!")
            import traceback
            traceback.print_exc()
            sys.exit(1)

if __name__ == "__main__":
    asyncio.run(test_seed())
