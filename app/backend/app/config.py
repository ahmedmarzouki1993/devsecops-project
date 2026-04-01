"""
App configuration — all values from environment variables.
12-factor app principle: config in the environment, not in code.
In K8s (Phase 6), secrets come from Key Vault via CSI driver mounted as env vars.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # PostgreSQL connection URL.
    # Format: postgresql://user:password@host:port/dbname
    # In K8s (Phase 6): injected from Key Vault secret via CSI driver
    # Locally: set in .env file (gitignored) or docker-compose environment block
    database_url: str = "postgresql://postgres:postgres@localhost:5432/devsecops"

    app_env: str = "development"  # development | production
    log_level: str = "info"

    # Pydantic v2 settings config — replaces the deprecated inner `class Config`
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
