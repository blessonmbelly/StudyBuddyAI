import os
from pathlib import Path
from dotenv import load_dotenv

# Locate .env in backend directory
BASE_DIR = Path(__file__).resolve().parent.parent
ENV_PATH = BASE_DIR / ".env"
load_dotenv(dotenv_path=ENV_PATH)

class Settings:
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "").strip()
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite").strip()
    HOST: str = os.getenv("HOST", "0.0.0.0").strip()
    PORT: int = int(os.getenv("PORT", "8000"))
    MAX_UPLOAD_SIZE_MB: int = int(os.getenv("MAX_UPLOAD_SIZE_MB", "25"))
    MAX_UPLOAD_SIZE_BYTES: int = MAX_UPLOAD_SIZE_MB * 1024 * 1024

    # Database Settings
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://postgres:postgres@localhost:5432/studybuddy",
    ).strip()

    # Authentication & JWT Settings
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "").strip()
    JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256").strip()
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development").strip().lower()

    @property
    def secret_key(self) -> str:
        """
        Retrieves the JWT secret key.
        Fails safely in production if the key is missing or shorter than 32 characters.
        """
        key = self.JWT_SECRET_KEY
        is_prod = self.ENVIRONMENT in ("production", "prod")
        if not key:
            if is_prod:
                raise ValueError("CRITICAL: JWT_SECRET_KEY environment variable is required in production.")
            return "studybuddy_dev_jwt_secret_key_minimum_32_characters_long_for_security"
        if len(key) < 32 and is_prod:
            raise ValueError("CRITICAL: JWT_SECRET_KEY must be at least 32 characters long in production.")
        return key

    @property
    def async_database_url(self) -> str:
        """Returns asyncpg-compatible SQLAlchemy URL."""
        url = self.DATABASE_URL
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        if url.startswith("postgresql://") and not url.startswith("postgresql+asyncpg://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url

    @property
    def sync_database_url(self) -> str:
        """Returns sync psycopg-compatible URL for Alembic migrations if needed."""
        url = self.DATABASE_URL
        if url.startswith("postgresql+asyncpg://"):
            return url.replace("postgresql+asyncpg://", "postgresql://", 1)
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql://", 1)
        return url

    @property
    def is_gemini_configured(self) -> bool:
        return bool(self.GEMINI_API_KEY and not self.GEMINI_API_KEY.startswith("your_"))

settings = Settings()
