from fastapi import Header

from .config import Settings, get_settings
from .errors import AppError
from .repositories.pgvector import SupabaseVectorSongRepository
from .repositories.supabase import SupabaseRepository
from .repositories.usage_repository import EmbeddingUsageRepository
from .services.analysis_service import AnalysisService
from .services.embedding_service import EmbeddingService, embedding_service_from_settings
from .services.gemini_service import GeminiVibeService
from .services.ingestion_service import SpotifyIngestionService
from .services.openai_service import OpenAIVibeService
from .services.reranker import SongReranker
from .services.spotify_service import SpotifyClient


def settings_dep() -> Settings:
    return get_settings()


def openai_dep() -> OpenAIVibeService:
    settings = get_settings()
    if settings.ai_provider.lower().strip() == "gemini":
        return GeminiVibeService(settings)
    return OpenAIVibeService(settings)


def embedding_dep() -> EmbeddingService:
    return embedding_service_from_settings(get_settings())


def song_repository_dep() -> SupabaseVectorSongRepository:
    return SupabaseVectorSongRepository(get_settings())


def supabase_dep() -> SupabaseRepository:
    return SupabaseRepository(get_settings())


def embedding_usage_dep() -> EmbeddingUsageRepository:
    settings = get_settings()
    return EmbeddingUsageRepository(settings, supabase_dep())


def analysis_service_dep() -> AnalysisService:
    settings = get_settings()
    return AnalysisService(
        openai=openai_dep(),
        embeddings=embedding_dep(),
        songs=song_repository_dep(),
        supabase=supabase_dep(),
        reranker=SongReranker(),
        usage=embedding_usage_dep(),
        settings=settings,
    )


def ingestion_service_dep() -> SpotifyIngestionService:
    settings = get_settings()
    return SpotifyIngestionService(
        settings=settings,
        spotify=SpotifyClient(settings),
        openai=OpenAIVibeService(settings),
        embeddings=embedding_service_from_settings(settings),
        songs=SupabaseVectorSongRepository(settings),
        supabase=SupabaseRepository(settings),
        usage=EmbeddingUsageRepository(settings, SupabaseRepository(settings)),
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
