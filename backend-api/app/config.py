from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="WELLNESSLENS_",
        extra="ignore",
    )

    env: str = "dev"
    use_firestore: bool = False
    firebase_auth_enabled: bool = False
    app_check_enforced: bool = False
    minimum_supported_version: str = "1.0"
    minimum_supported_build: int = 1
    copy_version: str = "soft-launch-v1"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
