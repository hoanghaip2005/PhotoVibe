import asyncio
from typing import Any

from app.config import Settings
from app.models import (
    AnalysisMode,
    FilterPreset,
    MoodQuote,
    UserMusicPreferences,
    VisionVibe,
)
from app.services.analysis_service import AnalysisService
from app.services.ingestion_service import SpotifyIngestionService
from app.services.reranker import SongReranker


class FakeVibeService:
    def __init__(self) -> None:
        self.settings = Settings()

    async def analyze_image(self, **_: Any) -> VisionVibe:
        return VisionVibe(
            vibe_name="Quiet Neon",
            description="Night city calm.",
            mood_tags=["calm", "neon"],
            scene_tags=["city"],
            playlist_query="calm neon night drive",
            quote=MoodQuote(text="Dem nay thanh pho diu lai."),
            filter_preset=FilterPreset(name="Neon Soft"),
            palette_hex=["#111111", "#44ccff"],
            confidence=0.88,
        )


class CountingEmbeddingService:
    def __init__(self) -> None:
        self.calls: list[str] = []

    async def embed_text(self, text: str) -> list[float]:
        self.calls.append(text)
        return [0.1] * 768


class FakeUsageRepository:
    def __init__(self) -> None:
        self.rows: list[dict[str, Any]] = []

    async def log_embedding_call(
        self,
        *,
        operation: str,
        context: str,
        model: str,
        input_text_count: int,
        user_id: str | None = None,
        estimated_tokens: int | None = None,
        estimated_cost: float | None = None,
    ) -> None:
        self.rows.append(
            {
                "operation": operation,
                "context": context,
                "model": model,
                "input_text_count": input_text_count,
                "user_id": user_id,
                "estimated_tokens": estimated_tokens,
                "estimated_cost": estimated_cost,
            }
        )


class FakeSongRepository:
    def __init__(self, existing: dict[str, Any] | None = None) -> None:
        self.existing = existing
        self.search_calls: list[dict[str, Any]] = []
        self.upserts: list[dict[str, Any]] = []

    async def search(self, query: str, embedding: list[float], limit: int = 50) -> list[Any]:
        self.search_calls.append({"query": query, "embedding": embedding, "limit": limit})
        return []

    async def find_existing_song(
        self,
        *,
        song_id: str | None,
        title: str,
        artist: str,
    ) -> dict[str, Any] | None:
        return self.existing

    async def upsert_song(self, document: dict[str, Any], replace_existing: bool = False) -> bool:
        self.upserts.append({"document": document, "replace_existing": replace_existing})
        return True


class FakeSupabase:
    def __init__(self) -> None:
        self.settings = Settings()

    async def maybe_user_preferences(self, user_id: str | None) -> None:
        return None

    async def insert(self, table: str, payload: dict[str, Any]) -> dict[str, Any]:
        return payload


def test_analyze_embeds_only_playlist_query_once_and_logs_usage() -> None:
    embedding = CountingEmbeddingService()
    usage = FakeUsageRepository()
    songs = FakeSongRepository()
    service = AnalysisService(
        openai=FakeVibeService(),  # type: ignore[arg-type]
        embeddings=embedding,  # type: ignore[arg-type]
        songs=songs,  # type: ignore[arg-type]
        supabase=FakeSupabase(),  # type: ignore[arg-type]
        reranker=SongReranker(),
        usage=usage,  # type: ignore[arg-type]
        settings=Settings(),
    )

    asyncio.run(service.analyze(
        image_bytes=b"fake",
        mime_type="image/jpeg",
        hint="",
        mood_hints=[],
        analysis_mode=AnalysisMode.auto,
        user_id="user-1",
        anonymous_id=None,
        save_result=False,
    ))

    assert embedding.calls == ["calm neon night drive"]
    assert songs.search_calls[0]["query"] == "calm neon night drive"
    assert songs.search_calls[0]["limit"] == 50
    assert usage.rows == [
        {
            "operation": "embedding",
            "context": "runtime_playlist_query",
            "model": "text-embedding-3-small",
            "input_text_count": 1,
            "user_id": "user-1",
            "estimated_tokens": None,
            "estimated_cost": None,
        }
    ]


def test_csv_ingestion_skips_existing_song_with_embedding() -> None:
    existing = {
        "song_id": "spotify:track:abc123",
        "title": "Forest Song",
        "artist": "Artist A",
        "vibe_description": "Already tagged.",
        "embedding": [0.1] * 768,
    }
    embedding = CountingEmbeddingService()
    songs = FakeSongRepository(existing=existing)
    service = SpotifyIngestionService(
        settings=Settings(),
        spotify=object(),  # type: ignore[arg-type]
        openai=object(),  # type: ignore[arg-type]
        embeddings=embedding,  # type: ignore[arg-type]
        songs=songs,  # type: ignore[arg-type]
        supabase=FakeSupabase(),  # type: ignore[arg-type]
        usage=FakeUsageRepository(),  # type: ignore[arg-type]
    )

    response = asyncio.run(service.ingest_csv_rows(
        [
            {
                "title": "Forest Song",
                "artist": "Artist A",
                "spotify_url": "https://open.spotify.com/track/abc123",
                "vibe_description": "Soft green acoustic music.",
            }
        ],
        regenerate_vibe_description=False,
        regenerate_embedding=False,
    ))

    assert response.imported == 0
    assert response.skipped_existing_embedding == 1
    assert response.skipped_duplicates == 0
    assert response.failed == 0
    assert embedding.calls == []
    assert songs.upserts == []
