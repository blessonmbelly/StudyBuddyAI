from datetime import datetime, timezone
import logging
from typing import Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth import (
    create_access_token,
    create_refresh_token,
    get_current_user,
    get_optional_current_user,
    hash_password,
    hash_token,
    verify_password,
)
from ..config import settings
from ..database import get_db
from ..db_models import RefreshToken, User
from ..models import (
    LogoutRequest,
    MessageResponse,
    RefreshTokenRequest,
    TokenResponse,
    UserLoginRequest,
    UserRegisterRequest,
    UserResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new student account",
)
async def register_user(
    req: UserRegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Registers a new student account with validated, normalized email and salted bcrypt password.
    Returns the created user and a fresh session (access + refresh tokens).
    """
    # Check if user already exists
    stmt = select(User).where(User.email == req.email)
    res = await db.execute(stmt)
    existing_user = res.scalar_one_or_none()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email address already exists.",
        )

    # Create new user
    new_user = User(
        id=uuid.uuid4(),
        email=req.email,
        hashed_password=hash_password(req.password),
        full_name=req.full_name.strip() if req.full_name else None,
        is_active=True,
    )
    db.add(new_user)
    await db.flush()  # assign attributes before relationship creation

    # Create session tokens
    access_token = create_access_token(new_user.id, new_user.email)
    raw_refresh, refresh_hash, refresh_expires_at = create_refresh_token()

    refresh_record = RefreshToken(
        id=uuid.uuid4(),
        user_id=new_user.id,
        token_hash=refresh_hash,
        expires_at=refresh_expires_at,
        revoked=False,
    )
    db.add(refresh_record)
    await db.commit()
    await db.refresh(new_user)

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserResponse.model_validate(new_user),
    )


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Log in with email and password",
)
async def login_user(
    req: UserLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Authenticates a student by email and password.
    Returns fresh JWT access token and secure refresh token.
    Safe error messaging prevents email enumeration attacks.
    """
    stmt = select(User).where(User.email == req.email)
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()

    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been deactivated. Please contact support.",
        )

    access_token = create_access_token(user.id, user.email)
    raw_refresh, refresh_hash, refresh_expires_at = create_refresh_token()

    refresh_record = RefreshToken(
        id=uuid.uuid4(),
        user_id=user.id,
        token_hash=refresh_hash,
        expires_at=refresh_expires_at,
        revoked=False,
    )
    db.add(refresh_record)
    await db.commit()
    await db.refresh(user)

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Rotate refresh token and obtain fresh access token",
)
async def refresh_session(
    req: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Validates the supplied refresh token, revokes it (rotation),
    and generates a new access token and new refresh token.
    """
    token_hash = hash_token(req.refresh_token)

    stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    res = await db.execute(stmt)
    stored_token = res.scalar_one_or_none()

    now = datetime.now(timezone.utc)

    if not stored_token or stored_token.revoked:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or revoked refresh token. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if stored_token.expires_at < now:
        stored_token.revoked = True
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has expired. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Fetch associated user
    user_stmt = select(User).where(User.id == stored_token.user_id)
    user_res = await db.execute(user_stmt)
    user = user_res.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account associated with this session no longer exists or is inactive.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Token Rotation: Invalidate current token and generate brand new pair
    stored_token.revoked = True

    new_access_token = create_access_token(user.id, user.email)
    new_raw_refresh, new_refresh_hash, new_refresh_expires_at = create_refresh_token()

    new_refresh_record = RefreshToken(
        id=uuid.uuid4(),
        user_id=user.id,
        token_hash=new_refresh_hash,
        expires_at=new_refresh_expires_at,
        revoked=False,
    )
    db.add(new_refresh_record)
    await db.commit()
    await db.refresh(user)

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_raw_refresh,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="Log out and revoke refresh token",
)
async def logout_user(
    req: LogoutRequest,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Revokes the provided refresh token and invalidates active session tokens.
    """
    if req.refresh_token:
        token_hash = hash_token(req.refresh_token)
        stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        res = await db.execute(stmt)
        stored_token = res.scalar_one_or_none()
        if stored_token:
            stored_token.revoked = True

    await db.commit()
    return MessageResponse(message="Successfully logged out.")


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get authenticated student profile",
)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
):
    """
    Returns the profile information of the currently authenticated student.
    Requires a valid JWT Bearer token in the Authorization header.
    """
    return UserResponse.model_validate(current_user)
