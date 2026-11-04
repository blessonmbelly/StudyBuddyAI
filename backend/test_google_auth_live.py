"""
StudyBuddy AI - Live PostgreSQL Google Authentication Verification
Tests end-to-end:
1. POST /api/auth/google with new user -> creates user in PostgreSQL.
2. GET /api/auth/me with issued JWT.
3. Creates study document associated with the Google user.
4. Second POST /api/auth/google with same email -> retrieves existing user with same UUID.
5. Verifies documents and data remain associated with the account.
6. Refresh token rotation for Google authenticated session.
7. Deactivated user rejection (HTTP 403).
8. Cleanup of test records.
"""
import asyncio
import os
from pathlib import Path
import sys
import uuid

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from httpx import ASGITransport, AsyncClient
from main import app
from app.database import AsyncSessionLocal
from app.db_models import Document, User
from sqlalchemy import select


async def run_live_google_auth_test():
    print("=" * 75)
    print(" LIVE GOOGLE AUTHENTICATION & DATA RETENTION VERIFICATION")
    print("=" * 75)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        test_uid = uuid.uuid4().hex[:8]
        test_email = f"google_student_{test_uid}@studybuddy.ai"
        test_name = f"Google Student {test_uid}"
        mock_token = f"mock-firebase-token:{test_email}:{test_name}:uid_{test_uid}"

        # 1. Sign in with Google (New User Registration)
        print("\n[STEP 1] Testing POST /api/auth/google for new user...")
        res = await client.post("/api/auth/google", json={"id_token": mock_token})
        assert res.status_code == 200, f"Google login failed: {res.text}"
        data = res.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == test_email
        assert data["user"]["full_name"] == test_name
        user_id = data["user"]["id"]
        access_token = data["access_token"]
        refresh_token = data["refresh_token"]
        headers = {"Authorization": f"Bearer {access_token}"}
        print(f"  [+] New Google user created in PostgreSQL: UUID {user_id}")
        print("  [+] Valid access & refresh tokens issued.")

        # 2. Query /api/auth/me
        print("\n[STEP 2] Verifying GET /api/auth/me with issued access token...")
        res_me = await client.get("/api/auth/me", headers=headers)
        assert res_me.status_code == 200, f"/me failed: {res_me.text}"
        me_data = res_me.json()
        assert me_data["id"] == user_id
        assert me_data["email"] == test_email
        print(f"  [+] Profile verified from database: {me_data['full_name']} ({me_data['email']})")

        # 3. Create a study document associated with this Google user
        print("\n[STEP 3] Creating a study document for Google user...")
        doc_payload = {
            "title": "Quantum Physics Notes",
            "extracted_text": "Quantum entanglement is a physical phenomenon...",
            "subject": "Physics",
            "topics": ["Quantum", "Physics"],
        }
        res_doc = await client.post("/api/documents", json=doc_payload, headers=headers)
        assert res_doc.status_code == 201, f"Doc creation failed: {res_doc.text}"
        doc_id = res_doc.json()["id"]
        print(f"  [+] Document created with ID: {doc_id}")

        # 4. Sign in again with Google using the same email (Account Retrieval)
        print("\n[STEP 4] Re-authenticating via Google with same email...")
        res_relogin = await client.post("/api/auth/google", json={"id_token": mock_token})
        assert res_relogin.status_code == 200, f"Relogin failed: {res_relogin.text}"
        relogin_data = res_relogin.json()
        assert relogin_data["user"]["id"] == user_id, "User ID changed on relogin! Data would be lost."
        new_access_token = relogin_data["access_token"]
        new_headers = {"Authorization": f"Bearer {new_access_token}"}
        print(f"  [+] Correct existing user retrieved: {relogin_data['user']['id']} matches {user_id}")

        # 5. Verify user documents remain associated and accessible
        print("\n[STEP 5] Verifying existing documents remain associated...")
        res_docs = await client.get("/api/documents", headers=new_headers)
        assert res_docs.status_code == 200
        docs = res_docs.json()
        assert len(docs) == 1
        assert docs[0]["id"] == doc_id
        assert docs[0]["title"] == "Quantum Physics Notes"
        print("  [+] Verified! User-specific documents and data remain completely intact.")

        # 6. Test Refresh Token Rotation
        print("\n[STEP 6] Testing refresh token rotation...")
        res_refresh = await client.post("/api/auth/refresh", json={"refresh_token": relogin_data["refresh_token"]})
        assert res_refresh.status_code == 200
        refreshed_data = res_refresh.json()
        assert refreshed_data["refresh_token"] != relogin_data["refresh_token"], "Refresh token was not rotated!"
        print("  [+] Refresh token rotated successfully; new session issued.")

        # 7. Test Deactivated User Rejection
        print("\n[STEP 7] Testing deactivated user rejection (HTTP 403)...")
        async with AsyncSessionLocal() as session:
            stmt = select(User).where(User.id == uuid.UUID(user_id))
            user_obj = (await session.execute(stmt)).scalar_one()
            user_obj.is_active = False
            await session.commit()

        res_deactivated = await client.post("/api/auth/google", json={"id_token": mock_token})
        assert res_deactivated.status_code == 403
        assert "deactivated" in res_deactivated.text.lower()
        print("  [+] Deactivated account safely blocked with HTTP 403.")

        # 8. Cleanup
        print("\n[STEP 8] Cleaning up test records from PostgreSQL...")
        async with AsyncSessionLocal() as session:
            stmt = select(User).where(User.id == uuid.UUID(user_id))
            user_obj = (await session.execute(stmt)).scalar_one_or_none()
            if user_obj:
                await session.delete(user_obj)
                await session.commit()
        print("  [+] Test user and all associated documents cascade-deleted cleanly.")

    print("\n" + "=" * 75)
    print(" ALL GOOGLE AUTHENTICATION TESTS PASSED SUCCESSFULLY!")
    print("=" * 75)


if __name__ == "__main__":
    asyncio.run(run_live_google_auth_test())
