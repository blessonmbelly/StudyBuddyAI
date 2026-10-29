import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import AsyncSessionLocal, engine
from app.db_models import User
from sqlalchemy import select

async def main():
    try:
        async with AsyncSessionLocal() as session:
            res = await session.execute(select(User))
            users = res.scalars().all()
            for u in users:
                print(f"ID={u.id} | Email={u.email} | FullName={repr(u.full_name)}", flush=True)
    finally:
        await engine.dispose()

if __name__ == "__main__":
    asyncio.run(main())
