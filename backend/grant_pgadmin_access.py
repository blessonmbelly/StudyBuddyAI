import asyncio
import asyncpg
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app.config import settings

async def grant_all():
    clean_url = settings.DATABASE_URL.replace("+asyncpg", "")
    conn = await asyncpg.connect(clean_url)
    try:
        # Check available roles
        roles = await conn.fetch("SELECT rolname FROM pg_roles;")
        role_names = [r['rolname'] for r in roles]
        print("Available PostgreSQL roles:", role_names)

        target_roles = [r for r in ['postgres', 'PUBLIC'] if r in role_names or r == 'PUBLIC']
        for r in target_roles:
            try:
                await conn.execute(f"GRANT USAGE ON SCHEMA public TO {r};")
                await conn.execute(f"GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO {r};")
                await conn.execute(f"GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO {r};")
                await conn.execute(f"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO {r};")
                await conn.execute(f"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO {r};")
                print(f"Granted schema & table privileges to {r}")
            except Exception as e:
                print(f"Notice granting to {r}: {e}")

        # Verify tables queryable
        tables = [
            'users', 'refresh_tokens', 'documents', 'generated_notes',
            'quizzes', 'quiz_attempts', 'flashcard_decks', 'flashcards',
            'flashcard_reviews', 'alembic_version'
        ]
        print("\nVerifying tables:")
        for t in tables:
            cnt = await conn.fetchval(f"SELECT COUNT(*) FROM {t};")
            print(f"  {t}: {cnt} rows")

    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(grant_all())

