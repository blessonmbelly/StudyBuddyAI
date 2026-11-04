from datetime import datetime, timedelta, timezone
import hashlib
import logging
import secrets
from typing import Optional, Tuple, Union
import uuid

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import settings
from .database import get_db
from .db_models import User

logger = logging.getLogger(__name__)

# OAuth2 scheme for Swagger UI & Authorization header parsing
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)


# --- Password Hashing & Verification (Bcrypt) ---

def hash_password(password: str) -> str:
    """Hashes a plaintext password using bcrypt with a secure salt."""
    if not password:
        raise ValueError("Password cannot be empty.")
    # bcrypt max length is 72 bytes
    pwd_bytes = password.encode("utf-8")[:72]
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plaintext password against a stored bcrypt hash."""
    if not plain_password or not hashed_password:
        return False
    try:
        pwd_bytes = plain_password.encode("utf-8")[:72]
        hash_bytes = hashed_password.encode("utf-8")
        return bcrypt.checkpw(pwd_bytes, hash_bytes)
    except Exception as e:
        logger.warning(f"Password verification error: {e}")
        return False


# --- Token Helpers ---

def hash_token(raw_token: str) -> str:
    """Returns the SHA-256 hex digest of a raw token for secure database storage."""
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def create_access_token(
    user_id: Union[uuid.UUID, str],
    email: str,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Creates a signed, short-lived JWT access token."""
    now = datetime.now(timezone.utc)
    expire = now + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )

    payload = {
        "sub": str(user_id),
        "email": email.strip().lower(),
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }

    token = jwt.encode(payload, settings.secret_key, algorithm=settings.JWT_ALGORITHM)
    return token


def create_refresh_token() -> Tuple[str, str, datetime]:
    """
    Generates a secure, high-entropy refresh token.
    Returns: (raw_token, token_hash, expires_at)
    """
    raw_token = secrets.token_urlsafe(48)
    token_hash = hash_token(raw_token)
    expires_at = datetime.now(timezone.utc) + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS
    )
    return raw_token, token_hash, expires_at


def decode_access_token(token: str) -> dict:
    """Decodes and validates a JWT access token."""
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[settings.JWT_ALGORITHM],
        )
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type: expected access token.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        if not payload.get("sub"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is missing subject identifier.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access token has expired. Please refresh your session.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid access token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


# --- Dependencies ---

async def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    FastAPI dependency ensuring the request has a valid Bearer token
    and returns the authenticated, active User record from the database.
    """
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required. Please provide a valid Bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(token)
    user_id_str = payload.get("sub")

    try:
        user_uuid = uuid.UUID(user_id_str)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user identifier in token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    stmt = select(User).where(User.id == user_uuid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account associated with this token no longer exists.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account has been deactivated.",
        )

    return user


# --- Firebase & Google ID Token Verification ---

try:
    import firebase_admin
    from firebase_admin import auth as fb_auth, credentials as fb_credentials
except ImportError:
    firebase_admin = None
    fb_auth = None
    fb_credentials = None

_firebase_initialized = False


def _ensure_firebase_initialized():
    global _firebase_initialized
    if _firebase_initialized or not firebase_admin:
        return
    try:
        import os
        if not firebase_admin._apps:
            if settings.FIREBASE_CREDENTIALS_PATH and os.path.exists(settings.FIREBASE_CREDENTIALS_PATH):
                cred = fb_credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred)
            elif settings.FIREBASE_PROJECT_ID:
                firebase_admin.initialize_app(options={"projectId": settings.FIREBASE_PROJECT_ID})
            else:
                try:
                    firebase_admin.initialize_app()
                except Exception:
                    pass
        _firebase_initialized = True
    except Exception as e:
        logger.debug(f"Firebase Admin SDK initialization notice: {e}")


def verify_firebase_or_google_token(id_token_str: str) -> dict:
    """
    Verifies a Firebase or Google OAuth ID token.
    1. If in development/testing and a mock test token is supplied ('mock-firebase-token:<email>:<name>'), decodes it.
    2. Attempts verification with firebase_admin if initialized.
    3. Attempts verification with google.oauth2.id_token.verify_firebase_token.
    4. Attempts verification with google.oauth2.id_token.verify_oauth2_token.
    Returns: {"email": str, "name": Optional[str], "uid": str, "email_verified": bool}
    Raises HTTPException 401 on verification failure.
    """
    raw_token = (id_token_str or "").strip()
    if not raw_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ID token cannot be empty.",
        )

    # 1. Dev / Test mock token support for automated tests
    if settings.ENVIRONMENT != "production" and raw_token.startswith("mock-firebase-token:"):
        parts = raw_token.split(":")
        email = parts[1] if len(parts) > 1 else "test@example.com"
        name = parts[2] if len(parts) > 2 else "Test User"
        uid = parts[3] if len(parts) > 3 else "mock-uid-123"
        return {
            "email": email.strip().lower(),
            "name": name.strip(),
            "uid": uid.strip(),
            "email_verified": True,
        }

    # 2. Firebase Admin SDK verification (if initialized)
    _ensure_firebase_initialized()
    if firebase_admin and firebase_admin._apps and fb_auth:
        try:
            decoded = fb_auth.verify_id_token(raw_token)
            email = decoded.get("email")
            if email:
                return {
                    "email": email.strip().lower(),
                    "name": decoded.get("name"),
                    "uid": decoded.get("uid") or decoded.get("sub"),
                    "email_verified": decoded.get("email_verified", True),
                }
        except Exception as e:
            logger.info(f"Firebase Admin SDK token verification fell through: {e}")

    # 3. Google OAuth / Firebase ID token public cert verification
    try:
        from google.oauth2 import id_token as google_id_token
        from google.auth.transport import requests as google_requests

        req = google_requests.Request()
        audience = settings.FIREBASE_PROJECT_ID or None

        # Try verify_firebase_token
        try:
            decoded = google_id_token.verify_firebase_token(raw_token, req, audience=audience)
            email = decoded.get("email")
            if email:
                return {
                    "email": email.strip().lower(),
                    "name": decoded.get("name"),
                    "uid": decoded.get("uid") or decoded.get("sub"),
                    "email_verified": decoded.get("email_verified", True),
                }
        except Exception as e1:
            logger.debug(f"verify_firebase_token fell through: {e1}")

        # Try verify_oauth2_token (for raw Google ID token from GoogleSignIn)
        try:
            decoded = google_id_token.verify_oauth2_token(raw_token, req)
            email = decoded.get("email")
            if email:
                return {
                    "email": email.strip().lower(),
                    "name": decoded.get("name"),
                    "uid": decoded.get("sub"),
                    "email_verified": decoded.get("email_verified", True),
                }
        except Exception as e2:
            logger.debug(f"verify_oauth2_token fell through: {e2}")

    except Exception as e:
        logger.warning(f"Google auth token verification failed: {e}")

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired Google / Firebase authentication token.",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_optional_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    """
    Optional authentication dependency.
    Returns the User if valid Bearer token is provided, or None if unauthenticated.
    """
    if not token:
        return None
    try:
        return await get_current_user(token=token, db=db)
    except HTTPException:
        return None

