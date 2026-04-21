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
    agent_provider_mode: str = "local"
    open_food_facts_base_url: str = "https://world.openfoodfacts.org"
    open_food_facts_user_agent: str = "WellnessLensBackend/0.1 (dev@wellnesslens.local)"
    usda_api_key: str | None = None
    usda_base_url: str = "https://api.nal.usda.gov/fdc/v1"
    resolver_cache_ttl_seconds: int = 900
    resolver_cache_max_entries: int = 256
    resolver_request_timeout_seconds: int = 5

    @property
    def persistence_mode(self) -> str:
        return "firestore" if self.use_firestore else "in_memory"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
