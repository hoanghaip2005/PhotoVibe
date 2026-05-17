from functools import lru_cache

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "backend/.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    openai_api_key: str = ""
    openai_vision_model: str = "gpt-5.4-mini"
    openai_ingestion_model: str = "gpt-5.4-mini"
    openai_embedding_model: str = "text-embedding-3-small"

    supabase_db_url: str = Field(
        default="",
        validation_alias=AliasChoices("SUPABASE_DB_URL", "DATABASE_URL"),
    )
    song_collection: str = "songs"
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_anon_key: str = ""

    spotify_client_id: str = ""
    spotify_client_secret: str = ""
    spotify_redirect_uri: str = ""

    admin_ingestion_token: str = ""
    app_env: str = "development"
    cors_origins: str = Field(
        default="http://localhost:53125,http://127.0.0.1:53125"
    )

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def has_openai(self) -> bool:
        return bool(self.openai_api_key)

    @property
    def has_pgvector(self) -> bool:
        return bool(self.supabase_db_url)

    @property
    def has_supabase_rest(self) -> bool:
        return bool(self.supabase_url and self.supabase_service_role_key)

    @property
    def has_supabase(self) -> bool:
        return self.has_supabase_rest or self.has_pgvector

    @property
    def has_spotify(self) -> bool:
        return bool(self.spotify_client_id and self.spotify_client_secret)


@lru_cache
def get_settings() -> Settings:
    return Settings()
