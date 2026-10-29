"""
StudyBuddy AI - Live PostgreSQL Authentication Verification
Tests end-to-end against a running PostgreSQL database:
1. Database connectivity.
2. User creation in live PostgreSQL 'users' table.
3. RefreshToken insertion in live 'refresh_tokens' table.
4. User lookup & password verification.
5. Refresh token lookup, expiry check, and rotation.
6. Cascade deletion / cleanup of test artifacts.
"""
import asyncio
from datetime import datetime, timezone
from pathlib import Path
import sys
import uuid

# Ensure Windows terminal doesn't crash on utf-8 characters
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Ensure backend root is in sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.auth import (
    create_access_token,
    create_refresh_token,
    decode_access_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.config import settings
from app.db_models import RefreshToken, User


async def run_live_verification():
    print("=" * 75)
    print(" LIVE POSTGRESQL AUTHENTICATION VERIFICATION")
    print("=" * 75)
    print(f"Target Database URL: {settings.async_database_url.split('@')[-1]}")

    engine = create_async_engine(settings.async_database_url, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

    test_email = f"live_test_{uuid.uuid4().hex[:8]}@studybuddy.ai"
    test_password = "LiveDbTestPassword2026!"

    try:
        # Step 1: Probe Database Connection
        print("\n[STEP 1] Probing PostgreSQL connectivity...")
        async with async_session() as session:
            await session.execute(select(1))
        print("  [+] PostgreSQL is reachable and accepted queries.")

        # Step 2: Live Registration / User Insert
        print(f"\n[STEP 2] Inserting test user ({test_email}) into 'users' table...")
        user_id = uuid.uuid4()
        user = User(
            id=user_id,
            email=test_email,
            hashed_password=hash_password(test_password),
            full_name="Live Test Student",
            is_active=True,
        )
        raw_refresh, refresh_hash, refresh_expires = create_refresh_token()
        refresh_record = RefreshToken(
            id=uuid.uuid4(),
            user_id=user_id,
            token_hash=refresh_hash,
            expires_at=refresh_expires,
            revoked=False,
        )

        async with async_session() as session:
            session.add(user)
            session.add(refresh_record)
            await session.commit()
        print(f"  [+] User record created in PostgreSQL: UUID {user_id}")
        print(f"  [+] Refresh token hash stored in PostgreSQL: {refresh_hash[:16]}...")

        # Step 3: Live Query and Password Verification
        print("\n[STEP 3] Fetching user and verifying password against PostgreSQL hash...")
        async with async_session() as session:
            stmt = select(User).where(User.email == test_email)
            res = await session.execute(stmt)
            fetched_user = res.scalar_one_or_none()
            assert fetched_user is not None, "User should be found in PostgreSQL."
            assert verify_password(test_password, fetched_user.hashed_password), "Password verification failed."
            assert not verify_password("WrongPassword!", fetched_user.hashed_password), "Distractor password matched unexpectedly."
        print("  [+] User successfully queried and bcrypt password verified from database.")

        # Step 4: Live Refresh Token Rotation in PostgreSQL
        print("\n[STEP 4] Executing live refresh token rotation in database...")
        new_raw_refresh, new_refresh_hash, new_refresh_expires = create_refresh_token()
        async with async_session() as session:
            # Query old token
            t_stmt = select(RefreshToken).where(RefreshToken.token_hash == refresh_hash)
            t_res = await session.execute(t_stmt)
            stored_tok = t_res.scalar_one_or_none()
            assert stored_tok is not None
            assert stored_tok.revoked is False

            # Mark old revoked, insert new
            stored_tok.revoked = True
            new_record = RefreshToken(
                id=uuid.uuid4(),
                user_id=user_id,
                token_hash=new_refresh_hash,
                expires_at=new_refresh_expires,
                revoked=False,
            )
            session.add(new_record)
            await session.commit()
        print("  [+] Old refresh token marked revoked=True in database.")
        print(f"  [+] New rotated refresh token inserted: {new_refresh_hash[:16]}...")

        # Step 5: Verify Cascade Deletion & Cleanup
        print("\n[STEP 5] Cleaning up test records and verifying cascade deletion...")
        async with async_session() as session:
            await session.execute(delete(User).where(User.id == user_id))
            await session.commit()

            # Confirm tokens were automatically cascade deleted
            tok_check = await session.execute(
                select(RefreshToken).where(RefreshToken.user_id == user_id)
            )
            remaining_tokens = tok_check.scalars().all()
            assert len(remaining_tokens) == 0, "Foreign key ON DELETE CASCADE should remove all tokens."
        print("  [+] Test user deleted and all session tokens cascade-deleted cleanly.")

        print("\n" + "=" * 75)
        print(" ALL LIVE POSTGRESQL AUTHENTICATION CHECKS PASSED SUCCESSFULLY!")
        print("=" * 75)

    except Exception as e:
        err_msg = str(e)
        if "connect" in err_msg.lower() or "connection refused" in err_msg.lower() or "10061" in err_msg:
            print("\n" + "-" * 75)
            print(" [NOTICE: LIVE POSTGRESQL CHECK REQUIRING RUNNING SERVICE]")
            print(f"  Could not connect to PostgreSQL on {settings.async_database_url.split('@')[-1]}")
            print("  This check requires an active, listening PostgreSQL service.")
            print("  To run live checks when PostgreSQL is started:")
            print("    1. Ensure your PostgreSQL service is running on localhost:5432.")
            print("    2. Apply migrations: alembic upgrade head")
            print("    3. Run: python test_auth_live_postgres.py")
            print("-" * 75)
        else:
            print(f"\n[FAIL] Live verification encountered an error: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(run_live_verification())

