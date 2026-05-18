import json
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime

from ..models import (
    AnalysisMode,
    FilterPreset,
    PersonalizationInfo,
    UserMusicPreferences,
    VibePlaylist,
    VibeResult,
)
from ..repositories.pgvector import SupabaseVectorSongRepository
from ..repositories.supabase import SupabaseRepository
from ..repositories.usage_repository import EmbeddingUsageRepository
from ..config import Settings
from ..errors import AppError
from .embedding_service import EmbeddingService
from .openai_service import OpenAIVibeService
from .reranker import SongReranker


@dataclass
class _RuntimeEmbeddingBudget:
    max_calls: int
    calls: int = 0

    def consume(self) -> None:
        self.calls += 1
        if self.calls > self.max_calls:
            raise AppError(
                "RUNTIME_EMBEDDING_LIMIT_EXCEEDED",
                "Runtime /analyze attempted too many embedding calls.",
                status_code=500,
            )


class AnalysisService:
    def __init__(
        self,
        openai: OpenAIVibeService,
        embeddings: EmbeddingService,
        songs: SupabaseVectorSongRepository,
        supabase: SupabaseRepository,
        reranker: SongReranker,
        usage: EmbeddingUsageRepository,
        settings: Settings,
    ) -> None:
        self.openai = openai
        self.embeddings = embeddings
        self.songs = songs
        self.supabase = supabase
        self.reranker = reranker
        self.usage = usage
        self.settings = settings

    async def analyze(
        self,
        image_bytes: bytes,
        mime_type: str,
        hint: str,
        mood_hints: list[str],
        analysis_mode: AnalysisMode,
        user_id: str | None,
        anonymous_id: str | None,
        save_result: bool,
        inline_preferences_json: str | None = None,
    ) -> VibeResult:
        preferences = await self._load_preferences(user_id, inline_preferences_json)
        vibe = await self.openai.analyze_image(
            image_bytes=image_bytes,
            mime_type=mime_type,
            hint=hint,
            mood_hints=mood_hints,
            analysis_mode=analysis_mode.value,
            preferences=preferences,
        )
        embedding_budget = _RuntimeEmbeddingBudget(
            max_calls=self.settings.max_runtime_embedding_calls_per_analyze
        )
        query_embedding = await self._embed_runtime_playlist_query(
            vibe.playlist_query,
            user_id=user_id,
            budget=embedding_budget,
        )
        candidates = await self.songs.search(
            vibe.playlist_query,
            embedding=query_embedding,
            limit=50,
        )
        songs = self.reranker.rerank(candidates, vibe.mood_tags, preferences, limit=8)
        result_id = str(uuid.uuid4())
        playlist = VibePlaylist(
            id=str(uuid.uuid4()),
            name=f"{vibe.vibe_name} Mix",
            description="Đã cá nhân hóa theo vibe ảnh và gu nghe nhạc của bạn.",
            mood_tags=vibe.mood_tags[:4],
            songs=songs,
        )
        result = VibeResult(
            id=result_id,
            vibe_name=vibe.vibe_name,
            description=vibe.description,
            mood_tags=vibe.mood_tags,
            scene_tags=vibe.scene_tags,
            confidence=vibe.confidence,
            palette_hex=vibe.palette_hex,
            personalization=PersonalizationInfo(
                age_group_used=preferences.age_group,
                genre_preferences_used=preferences.preferred_genres,
                era_preference_used=preferences.music_era_preference,
                language_preferences_used=preferences.preferred_languages,
            ),
            quote=vibe.quote,
            filter_preset=vibe.filter_preset,
            playlist=playlist,
            created_at=datetime.now(UTC).isoformat(),
            is_saved=save_result,
        )
        await self._log_usage(user_id, anonymous_id)
        if save_result:
            await self._save_result(result, user_id)
        return result

    async def _embed_runtime_playlist_query(
        self,
        playlist_query: str,
        user_id: str | None,
        budget: _RuntimeEmbeddingBudget,
    ) -> list[float]:
        if budget.max_calls < 1:
            raise AppError(
                "RUNTIME_EMBEDDING_LIMIT_EXCEEDED",
                "Runtime embedding budget does not allow playlist query embedding.",
                status_code=500,
            )
        budget.consume()
        embedding = await self.embeddings.embed_text(playlist_query)
        await self.usage.log_embedding_call(
            operation="embedding",
            context="runtime_playlist_query",
            model=getattr(self.embeddings, "model", self.settings.embedding_model),
            input_text_count=1,
            user_id=user_id,
        )
        return embedding

    async def _load_preferences(
        self,
        user_id: str | None,
        inline_preferences_json: str | None,
    ) -> UserMusicPreferences:
        if inline_preferences_json:
            return UserMusicPreferences.model_validate_json(inline_preferences_json)
        row = await self.supabase.maybe_user_preferences(user_id)
        if row:
            return UserMusicPreferences(
                gender=row.get("gender") or "unknown",
                age_group=row.get("age_group") or "unknown",
                preferred_genres=row.get("preferred_genres") or [],
                preferred_languages=row.get("preferred_languages") or [],
                music_era_preference=row.get("music_era_preference") or "mood_based",
                favorite_artists=row.get("favorite_artists") or [],
                favorite_songs=row.get("favorite_songs") or [],
                explicit_content_allowed=bool(row.get("explicit_content_allowed") or False),
                discovery_level=row.get("discovery_level") or "balanced",
            )
        return UserMusicPreferences()

    async def _log_usage(self, user_id: str | None, anonymous_id: str | None) -> None:
        if not self.supabase.settings.has_supabase:
            return
        await self.supabase.insert(
            "ai_usage",
            {
                "user_id": user_id,
                "anonymous_id": anonymous_id,
                "date": date.today().isoformat(),
                "model": self.openai.settings.openai_vision_model,
                "check_count": 1,
                "created_at": datetime.now(UTC).isoformat(),
            },
        )

    async def _save_result(self, result: VibeResult, user_id: str | None) -> None:
        if not self.supabase.settings.has_supabase:
            return
        result_row = await self.supabase.insert(
            "vibe_results",
            {
                "id": result.id,
                "user_id": user_id,
                "vibe_name": result.vibe_name,
                "description": result.description,
                "mood_tags": result.mood_tags,
                "scene_tags": result.scene_tags,
                "confidence": result.confidence,
                "palette_hex": result.palette_hex,
                "quote_text": result.quote.text,
                "quote_source": result.quote.source,
                "quote_is_ai_generated": result.quote.is_ai_generated,
                "filter_preset": result.filter_preset.model_dump(),
                "playlist_query": "",
                "personalization": result.personalization.model_dump(mode="json"),
                "is_saved": result.is_saved,
                "created_at": result.created_at,
            },
        )
        playlist_row = await self.supabase.insert(
            "generated_playlists",
            {
                "id": result.playlist.id,
                "user_id": user_id,
                "vibe_result_id": result_row.get("id") or result.id,
                "name": result.playlist.name,
                "description": result.playlist.description,
                "mood_tags": result.playlist.mood_tags,
                "source": "vibelens",
                "created_at": result.created_at,
            },
        )
        playlist_id = playlist_row.get("id") or result.playlist.id
        for index, song in enumerate(result.playlist.songs):
            await self.supabase.insert(
                "playlist_songs",
                {
                    "playlist_id": playlist_id,
                    "song_id": song.song_id,
                    "title": song.title,
                    "artist": song.artist,
                    "spotify_url": song.spotify_url,
                    "spotify_search_url": song.spotify_search_url,
                    "match_percent": song.match_percent,
                    "reason": song.reason,
                    "genres": song.genres,
                    "position": index,
                    "created_at": result.created_at,
                },
            )
