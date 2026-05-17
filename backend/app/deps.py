from fastapi import Header

from .config import Settings, get_settings
from .errors import AppError
from .repositories.pgvector import SupabaseVectorSongRepository
from .repositories.supabase import SupabaseRepository
from .services.analysis_service import AnalysisService
from .services.ingestion_service import SpotifyIngestionService
from .services.openai_service import OpenAIVibeService
from .services.reranker import SongReranker
from .services.spotify_service import SpotifyClient


def settings_dep() -> Settings:
    return get_settings()


def openai_dep() -> OpenAIVibeService:
    return OpenAIVibeService(get_settings())


def song_repository_dep() -> SupabaseVectorSongRepository:
    return SupabaseVectorSongRepository(get_settings())


def supabase_dep() -> SupabaseRepository:
    return SupabaseRepository(get_settings())


def analysis_service_dep() -> AnalysisService:
    return AnalysisService(
        openai=openai_dep(),
        songs=song_repository_dep(),
        supabase=supabase_dep(),
        reranker=SongReranker(),
    )


def ingestion_service_dep() -> SpotifyIngestionService:
    settings = get_settings()
    return SpotifyIngestionService(
        settings=settings,
        spotify=SpotifyClient(settings),
        openai=OpenAIVibeService(settings),
        songs=SupabaseVectorSongRepository(settings),
        supabase=SupabaseRepository(settings),
    )


def require_admin_token(x_admin_token: str | None = Header(default=None)) -> None:
    settings = get_settings()
    if not settings.admin_ingestion_token:
        raise AppError(
            "ADMIN_TOKEN_NOT_CONFIGURED",
            "ADMIN_INGESTION_TOKEN is missing.",
            status_code=503,
        )
    if x_admin_token != settings.admin_ingestion_token:
        raise AppError("FORBIDDEN", "Invalid admin ingestion token.", status_code=403)
