"""
StudyBuddy AI - Backend Authentication Test Suite
Tests:
1. Password hashing, salt randomness, verification, and bcrypt constraints.
2. JWT access token generation, claims, and signature verification.
3. Token expiration rejection (ExpiredSignatureError -> HTTP 401).
4. Tampered / invalid token rejection (InvalidTokenError -> HTTP 401).
5. Refresh token generation, entropy, and SHA-256 hash verification.
6. Email normalization and validation (case-folding, whitespace trimming, malformed formats).
7. Production secret fail-safe behavior.
8. Registration flow and duplicate email conflict (HTTP 409).
9. Login flow (success, wrong password, non-existent user) with safe error messages.
10. Refresh token rotation (old token invalidated, new tokens issued).
11. Expired and revoked refresh token rejections (HTTP 401).
12. Logout flow (refresh token revocation).
13. Protected route (/api/auth/me) with get_current_user dependency.
"""
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock
import uuid

import pytest
from fastapi import HTTPException

# Ensure backend root is in sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.auth import (
    create_access_token,
    create_refresh_token,
    decode_access_token,
    get_current_user,
    hash_password,
    hash_token,
    verify_password,
)
from app.config import settings
from app.db_models import RefreshToken, User
from app.models import (
    LogoutRequest,
    RefreshTokenRequest,
    UserLoginRequest,
    UserRegisterRequest,
)
from app.routes.auth import (
    get_my_profile,
    login_user,
    logout_user,
    refresh_session,
    register_user,
)


# --- 1. Password Hashing Tests ---

def test_password_hashing_and_verification():
    raw = "SuperSecretPassword123!"
    hashed = hash_password(raw)
    assert hashed != raw
    assert hashed.startswith("$2b$") or hashed.startswith("$2a$")
    assert verify_password(raw, hashed) is True
    assert verify_password("WrongPassword!", hashed) is False
    assert verify_password("", hashed) is False
    assert verify_password(raw, "") is False


def test_password_salting_unique():
    raw = "IdenticalPasswordForTwoUsers"
    hash1 = hash_password(raw)
    hash2 = hash_password(raw)
    assert hash1 != hash2, "Bcrypt salt must produce unique hashes for identical passwords."
    assert verify_password(raw, hash1) is True
    assert verify_password(raw, hash2) is True


def test_password_empty_rejected():
    with pytest.raises(ValueError):
        hash_password("")


# --- 2. Token Creation & Validation Tests ---

def test_access_token_creation_and_decoding():
    user_id = uuid.uuid4()
    email = "Student@StudyBuddy.AI"
    token = create_access_token(user_id=user_id, email=email)
    payload = decode_access_token(token)

    assert payload["sub"] == str(user_id)
    assert payload["email"] == "student@studybuddy.ai"
    assert payload["type"] == "access"
    assert "exp" in payload
    assert "iat" in payload


def test_expired_token_rejected():
    user_id = uuid.uuid4()
    email = "expired@studybuddy.ai"
    # Create token expired 10 minutes ago
    expired_token = create_access_token(
        user_id=user_id,
        email=email,
        expires_delta=timedelta(minutes=-10),
    )
    with pytest.raises(HTTPException) as exc_info:
        decode_access_token(expired_token)
    assert exc_info.value.status_code == 401
    assert "expired" in exc_info.value.detail.lower()


def test_tampered_token_rejected():
    user_id = uuid.uuid4()
    valid_token = create_access_token(user_id=user_id, email="tamper@studybuddy.ai")
    # Mutate characters in the signature segment
    parts = valid_token.split(".")
    tampered_sig = ("A" if parts[2][0] != "A" else "B") + parts[2][1:]
    tampered_token = f"{parts[0]}.{parts[1]}.{tampered_sig}"

    with pytest.raises(HTTPException) as exc_info:
        decode_access_token(tampered_token)
    assert exc_info.value.status_code == 401
    assert "invalid" in exc_info.value.detail.lower()


# --- 3. Refresh Token Generation & Hashing Tests ---

def test_refresh_token_generation_and_hashing():
    raw_token, token_hash, expires_at = create_refresh_token()
    assert len(raw_token) >= 48
    assert token_hash == hash_token(raw_token)
    assert expires_at > datetime.now(timezone.utc)
    # Never store raw token in hash
    assert raw_token != token_hash


# --- 4. Email Normalization & Validation Tests ---

def test_email_normalization_on_registration_and_login():
    req_reg = UserRegisterRequest(
        email="  STUDENT.Test@Domain.COM  ",
        password="ValidPassword123!",
        full_name="Test Student",
    )
    assert req_reg.email == "student.test@domain.com"

    req_login = UserLoginRequest(
        email="  STUDENT.Test@Domain.COM  ",
        password="ValidPassword123!",
    )
    assert req_login.email == "student.test@domain.com"


def test_invalid_email_format_rejected():
    with pytest.raises(Exception):
        UserRegisterRequest(
            email="not-a-valid-email",
            password="ValidPassword123!",
        )


def test_short_password_rejected():
    with pytest.raises(Exception):
        UserRegisterRequest(
            email="valid@example.com",
            password="short",  # < 8 chars
        )


# --- 5. Secret Key Production Fail-Safe Test ---

def test_production_secret_fail_safe():
    orig_env = settings.ENVIRONMENT
    orig_key = settings.JWT_SECRET_KEY
    try:
        # Simulate production with missing key
        settings.ENVIRONMENT = "production"
        settings.JWT_SECRET_KEY = ""
        with pytest.raises(ValueError) as exc:
            _ = settings.secret_key
        assert "CRITICAL" in str(exc.value)

        # Simulate production with insecurely short key
        settings.JWT_SECRET_KEY = "short_insecure_key"
        with pytest.raises(ValueError) as exc2:
            _ = settings.secret_key
        assert "at least 32 characters" in str(exc2.value)
    finally:
        settings.ENVIRONMENT = orig_env
        settings.JWT_SECRET_KEY = orig_key


# --- 6. Registration Route Tests ---

@pytest.mark.anyio
async def test_register_user_success():
    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    # Mock no existing user
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_res

    req = UserRegisterRequest(
        email="new_student@example.com",
        password="SecurePassword2026!",
        full_name="New Student",
    )

    response = await register_user(req, db=mock_db)

    assert response.access_token
    assert response.refresh_token
    assert response.user.email == "new_student@example.com"
    assert response.user.full_name == "New Student"
    assert mock_db.add.call_count == 2  # Added User and RefreshToken
    assert mock_db.commit.called


@pytest.mark.anyio
async def test_register_duplicate_email_conflict():
    mock_db = AsyncMock()
    # Mock existing user found
    existing_user = User(
        id=uuid.uuid4(),
        email="existing@example.com",
        hashed_password="hash",
    )
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = existing_user
    mock_db.execute.return_value = mock_res

    req = UserRegisterRequest(
        email="existing@example.com",
        password="SecurePassword2026!",
    )

    with pytest.raises(HTTPException) as exc:
        await register_user(req, db=mock_db)
    assert exc.value.status_code == 409
    assert "already exists" in exc.value.detail


# --- 7. Login Route Tests ---

@pytest.mark.anyio
async def test_login_user_success():
    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    pwd = "StudentPassword123!"
    user = User(
        id=uuid.uuid4(),
        email="student@example.com",
        hashed_password=hash_password(pwd),
        is_active=True,
    )
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = user
    mock_db.execute.return_value = mock_res

    req = UserLoginRequest(email="student@example.com", password=pwd)
    response = await login_user(req, db=mock_db)

    assert response.access_token
    assert response.refresh_token
    assert response.user.email == "student@example.com"
    assert mock_db.commit.called


@pytest.mark.anyio
async def test_login_wrong_password_rejected():
    mock_db = AsyncMock()
    user = User(
        id=uuid.uuid4(),
        email="student@example.com",
        hashed_password=hash_password("CorrectPassword123!"),
        is_active=True,
    )
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = user
    mock_db.execute.return_value = mock_res

    req = UserLoginRequest(email="student@example.com", password="WrongPassword999!")
    with pytest.raises(HTTPException) as exc:
        await login_user(req, db=mock_db)
    assert exc.value.status_code == 401
    assert "invalid email or password" in exc.value.detail.lower()


@pytest.mark.anyio
async def test_login_nonexistent_email_rejected():
    mock_db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_res

    req = UserLoginRequest(email="nobody@example.com", password="AnyPassword123!")
    with pytest.raises(HTTPException) as exc:
        await login_user(req, db=mock_db)
    assert exc.value.status_code == 401
    assert "invalid email or password" in exc.value.detail.lower()


# --- 8. Refresh Token Rotation Tests ---

@pytest.mark.anyio
async def test_refresh_token_rotation_success():
    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    raw_token, token_hash, _ = create_refresh_token()
    user = User(
        id=uuid.uuid4(),
        email="refresh_student@example.com",
        is_active=True,
    )
    token_record = RefreshToken(
        id=uuid.uuid4(),
        user_id=user.id,
        token_hash=token_hash,
        expires_at=datetime.now(timezone.utc) + timedelta(days=7),
        revoked=False,
    )

    # First call returns token_record, second returns user
    mock_res_token = MagicMock()
    mock_res_token.scalar_one_or_none.return_value = token_record
    mock_res_user = MagicMock()
    mock_res_user.scalar_one_or_none.return_value = user

    mock_db.execute.side_effect = [mock_res_token, mock_res_user]

    req = RefreshTokenRequest(refresh_token=raw_token)
    response = await refresh_session(req, db=mock_db)

    assert response.access_token
    assert response.refresh_token
    assert response.refresh_token != raw_token, "Rotated refresh token must be different from original."
    assert token_record.revoked is True, "Old refresh token must be invalidated upon rotation."
    assert mock_db.commit.called


@pytest.mark.anyio
async def test_refresh_revoked_token_rejected():
    mock_db = AsyncMock()
    raw_token, token_hash, _ = create_refresh_token()
    token_record = RefreshToken(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        token_hash=token_hash,
        expires_at=datetime.now(timezone.utc) + timedelta(days=7),
        revoked=True,  # Already revoked
    )

    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = token_record
    mock_db.execute.return_value = mock_res

    req = RefreshTokenRequest(refresh_token=raw_token)
    with pytest.raises(HTTPException) as exc:
        await refresh_session(req, db=mock_db)
    assert exc.value.status_code == 401
    assert "revoked" in exc.value.detail.lower() or "invalid" in exc.value.detail.lower()


# --- 9. Logout Test ---

@pytest.mark.anyio
async def test_logout_revokes_refresh_token():
    mock_db = AsyncMock()
    raw_token, token_hash, _ = create_refresh_token()
    token_record = RefreshToken(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        token_hash=token_hash,
        revoked=False,
    )
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = token_record
    mock_db.execute.return_value = mock_res

    req = LogoutRequest(refresh_token=raw_token)
    response = await logout_user(req, current_user=None, db=mock_db)

    assert token_record.revoked is True
    assert "logged out" in response.message.lower()
    assert mock_db.commit.called


# --- 10. Protected Route /api/auth/me Tests ---

@pytest.mark.anyio
async def test_get_my_profile_authenticated():
    user = User(
        id=uuid.uuid4(),
        email="me@studybuddy.ai",
        full_name="Me Student",
        is_active=True,
        created_at=datetime.now(timezone.utc),
    )
    profile = await get_my_profile(current_user=user)
    assert profile.email == "me@studybuddy.ai"
    assert profile.full_name == "Me Student"
    assert profile.id == user.id


@pytest.mark.anyio
async def test_get_current_user_missing_token():
    mock_db = AsyncMock()
    with pytest.raises(HTTPException) as exc:
        await get_current_user(token=None, db=mock_db)
    assert exc.value.status_code == 401
    assert "authentication required" in exc.value.detail.lower()
