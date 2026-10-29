"""
End-to-end contract validation between Flutter AuthService and FastAPI backend.
Simulates the exact HTTP requests, payloads, headers, and response parsing
performed by Flutter StudyBuddy AI.
"""
import sys
import os
import json
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient
from unittest.mock import MagicMock, AsyncMock, patch
from main import app
from app.database import get_db
from app.db_models import User, RefreshToken
from app.auth import hash_password, hash_token, verify_password

def run_flutter_e2e_verification():
    print("=" * 70)
    print(" FLUTTER AUTHENTICATION END-TO-END CONTRACT VERIFICATION")
    print("=" * 70)

    # In-memory mock database state for fast and isolated verification
    users_db = {}
    users_by_id = {}
    tokens_db = {}

    class MockAsyncSession:
        async def execute(self, statement):
            stmt_str = str(statement)
            mock_result = MagicMock()
            compiled = statement.compile()
            params = compiled.params

            if "FROM users" in stmt_str:
                for val in params.values():
                    val_str = str(val)
                    if val_str in users_db:
                        mock_result.scalar_one_or_none.return_value = users_db[val_str]
                        return mock_result
                    if val_str in users_by_id:
                        mock_result.scalar_one_or_none.return_value = users_by_id[val_str]
                        return mock_result

                mock_result.scalar_one_or_none.return_value = None
                return mock_result

            elif "FROM refresh_tokens" in stmt_str:
                for val in params.values():
                    val_str = str(val)
                    if val_str in tokens_db:
                        mock_result.scalar_one_or_none.return_value = tokens_db[val_str]
                        return mock_result

                mock_result.scalar_one_or_none.return_value = None
                return mock_result

            mock_result.scalar_one_or_none.return_value = None
            return mock_result

        def add(self, obj):
            if isinstance(obj, User):
                users_db[obj.email] = obj
                users_by_id[str(obj.id)] = obj
            elif isinstance(obj, RefreshToken):
                tokens_db[obj.token_hash] = obj

        async def commit(self):
            pass

        async def flush(self):
            pass

        async def delete(self, obj):
            pass

        async def refresh(self, obj):
            if isinstance(obj, User) and not obj.created_at:
                obj.created_at = datetime.now(timezone.utc)

        async def rollback(self):
            pass

    mock_session = MockAsyncSession()

    async def override_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = override_get_db

    client = TestClient(app)

    # 1. Test POST /api/auth/register (exactly as sent by AuthService.register)
    reg_payload = {
        "email": "flutter_student@studybuddy.ai",
        "password": "StrongPassword123!",
        "full_name": "Flutter Student",
    }
    print("\n1. Testing Registration (POST /api/auth/register)...")
    res = client.post("/api/auth/register", json=reg_payload)
    assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.text}"
    reg_data = res.json()
    assert "access_token" in reg_data
    assert "refresh_token" in reg_data
    assert reg_data["token_type"] == "bearer"
    assert reg_data["user"]["email"] == "flutter_student@studybuddy.ai"
    assert reg_data["user"]["full_name"] == "Flutter Student"
    assert reg_data["user"]["is_active"] is True
    print("   ✓ Registration successful (201 Created)")
    print(f"   ✓ Access Token issued: {reg_data['access_token'][:25]}...")
    print(f"   ✓ User ID: {reg_data['user']['id']}")

    # 2. Test GET /api/auth/me (exactly as sent by AuthService.getMe)
    print("\n2. Testing Profile Fetch (GET /api/auth/me)...")
    access_token = reg_data["access_token"]
    res = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {access_token}"}
    )
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    me_data = res.json()
    assert me_data["email"] == "flutter_student@studybuddy.ai"
    assert me_data["full_name"] == "Flutter Student"
    print("   ✓ GET /api/auth/me returned correct profile (200 OK)")

    # 3. Test POST /api/auth/login (exactly as sent by AuthService.login)
    print("\n3. Testing Login (POST /api/auth/login)...")
    login_payload = {
        "email": "flutter_student@studybuddy.ai",
        "password": "StrongPassword123!",
    }
    res = client.post("/api/auth/login", json=login_payload)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    login_data = res.json()
    assert "access_token" in login_data
    assert "refresh_token" in login_data
    print("   ✓ Login successful (200 OK)")

    # 4. Test POST /api/auth/refresh (exactly as sent by AuthService.refreshToken)
    print("\n4. Testing Token Rotation (POST /api/auth/refresh)...")
    import time
    time.sleep(1.05)
    old_refresh_token = login_data["refresh_token"]
    res = client.post("/api/auth/refresh", json={"refresh_token": old_refresh_token})
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    refresh_data = res.json()
    new_access_token = refresh_data["access_token"]
    new_refresh_token = refresh_data["refresh_token"]
    assert new_access_token != login_data["access_token"]
    assert new_refresh_token != old_refresh_token
    print("   ✓ Refresh token rotated successfully (200 OK)")

    # 5. Verify old refresh token is now revoked
    print("\n5. Testing Revoked Token Rejection...")
    res = client.post("/api/auth/refresh", json={"refresh_token": old_refresh_token})
    assert res.status_code == 401, f"Expected 401, got {res.status_code}: {res.text}"
    print("   ✓ Revoked refresh token rejected (401 Unauthorized)")

    # 6. Test POST /api/auth/logout (exactly as sent by AuthService.logout)
    print("\n6. Testing Logout (POST /api/auth/logout)...")
    res = client.post(
        "/api/auth/logout",
        headers={"Authorization": f"Bearer {new_access_token}"},
        json={"refresh_token": new_refresh_token}
    )
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    print("   ✓ Logout successful (200 OK)")

    # 7. Verify logged-out refresh token cannot be reused
    res = client.post("/api/auth/refresh", json={"refresh_token": new_refresh_token})
    assert res.status_code == 401
    print("   ✓ Logged-out token cannot be refreshed (401 Unauthorized)")

    print("\n" + "=" * 70)
    print(" ALL 6 FLUTTER AUTHENTICATION CONTRACT CHECKS PASSED PERFECTLY!")
    print("=" * 70)

if __name__ == "__main__":
    run_flutter_e2e_verification()
