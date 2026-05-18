import asyncio
from datetime import UTC, datetime
from typing import Any
from urllib.parse import quote

import psycopg
from psycopg import rows, sql
from psycopg.types.json import Jsonb

from ..config import Settings
from ..errors import AppError
from ..models import SongCandidate


class SupabaseVectorSongRepository:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def _ensure_configured(self) -> None:
        if not self.settings.has_pgvector:
            raise AppError(
                "PGVECTOR_NOT_CONFIGURED",
                "SUPABASE_DB_URL or DATABASE_URL is missing.",
                status_code=503,
            )

    def _connection(self) -> psycopg.Connection:
        self._ensure_configured()
        return psycopg.connect(
            self.settings.supabase_db_url,
            autocommit=True,
            row_factory=rows.dict_row,
        )

    async def search(
        self,
        query: str,
        embedding: list[float],
        limit: int = 50,
    ) -> list[SongCandidate]:
        return await asyncio.to_thread(self._search_sync, query, embedding, limit)

    def _search_sync(
        self,
        query: str,
        embedding: list[float],
        limit: int = 50,
    ) -> list[SongCandidate]:
        del query
        vector = self._vector_literal(embedding)
        query_sql = """
            select *
            from match_songs(%s::vector, %s)
        """
        with self._connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(query_sql, (vector, limit))
                documents = cursor.fetchall()
        return [self._candidate_from_document(dict(doc)) for doc in documents]

    async def upsert_song(self, document: dict[str, Any], replace_existing: bool = False) -> bool:
        return await asyncio.to_thread(self._upsert_song_sync, document, replace_existing)

    def _upsert_song_sync(
        self,
        document: dict[str, Any],
        replace_existing: bool = False,
    ) -> bool:
        self._ensure_configured()
        existing = self._find_existing_song_sync(
            song_id=document.get("song_id"),
            title=document.get("title") or "",
            artist=document.get("artist") or "",
        )
        if existing and not replace_existing:
            return False

        payload = self._song_payload(document)
        columns = list(payload.keys())
        values = [self._adapt_value(payload[column]) for column in columns]
        assignments = [
            sql.SQL("{} = excluded.{}").format(sql.Identifier(column), sql.Identifier(column))
            for column in columns
            if column != "song_id"
        ]
        statement = sql.SQL(
            "insert into songs ({columns}) values ({placeholders}) "
            "on conflict (normalized_key) do update set {assignments}"
        ).format(
            columns=sql.SQL(", ").join(sql.Identifier(column) for column in columns),
            placeholders=sql.SQL(", ").join(sql.Placeholder() for _ in columns),
            assignments=sql.SQL(", ").join(assignments),
        )
        with self._connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(statement, values)
        return True

    async def find_by_song_id(self, song_id: str) -> dict[str, Any] | None:
        return await asyncio.to_thread(self._find_by_song_id_sync, song_id)

    def _find_by_song_id_sync(self, song_id: str) -> dict[str, Any] | None:
        self._ensure_configured()
        with self._connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    select *
                    from songs
                    where song_id = %s
                    limit 1
                    """,
                    (song_id,),
                )
                row = cursor.fetchone()
        return dict(row) if row else None

    async def find_existing_song(
        self,
        *,
        song_id: str | None,
        title: str,
        artist: str,
    ) -> dict[str, Any] | None:
        return await asyncio.to_thread(
            self._find_existing_song_sync,
            song_id,
            title,
            artist,
        )

    def _find_existing_song_sync(
        self,
        song_id: str | None,
        title: str,
        artist: str,
    ) -> dict[str, Any] | None:
        self._ensure_configured()
        normalized_key = self.normalized_key(title, artist)
        with self._connection() as connection:
            with connection.cursor() as cursor:
                if song_id:
                    cursor.execute(
                        """
                        select *
                        from songs
                        where song_id = %s or normalized_key = %s
                        limit 1
                        """,
                        (song_id, normalized_key),
                    )
                else:
                    cursor.execute(
                        """
                        select *
                        from songs
                        where normalized_key = %s
                        limit 1
                        """,
                        (normalized_key,),
                    )
                row = cursor.fetchone()
        return dict(row) if row else None

    def _song_payload(self, document: dict[str, Any]) -> dict[str, Any]:
        title = document.get("title") or "Unknown"
        artist = document.get("artist") or "Unknown"
        return {
            "song_id": document.get("song_id"),
            "track_id": document.get("track_id"),
            "title": title,
            "artist": artist,
            "normalized_key": document.get("normalized_key") or self.normalized_key(title, artist),
            "spotify_url": document.get("spotify_url"),
            "spotify_search_url": document.get("spotify_search_url")
            or self.spotify_search_url(title, artist),
            "album": document.get("album"),
            "artwork": document.get("artwork"),
            "duration_ms": document.get("duration_ms"),
            "explicit": bool(document.get("explicit") or False),
            "genres": document.get("genres") or [],
            "mood_tags": document.get("mood_tags") or [],
            "scene_tags": document.get("scene_tags") or [],
            "era_tags": document.get("era_tags") or [],
            "language": document.get("language") or "unknown",
            "energy_level": float(document.get("energy_level") or 0.5),
            "valence_level": float(document.get("valence_level") or 0.5),
            "age_affinity": document.get("age_affinity") or self._neutral_age_affinity(),
            "popularity_tier": document.get("popularity_tier") or "unknown",
            "vibe_description": document.get("vibe_description") or document.get("$vectorize") or "",
            "embedding": self._vector_literal(document["embedding"]),
            "embedding_model": document.get("embedding_model") or self.settings.embedding_model,
            "embedding_created_at": document.get("embedding_created_at")
            or datetime.now(UTC).isoformat(),
            "source": document.get("source") or "spotify_ingestion",
            "ingested_at": document.get("ingested_at") or datetime.now(UTC).isoformat(),
            "updated_at": datetime.now(UTC).isoformat(),
        }

    def _candidate_from_document(self, doc: dict[str, Any]) -> SongCandidate:
        return SongCandidate(
            song_id=str(doc.get("song_id") or ""),
            title=str(doc.get("title") or "Unknown"),
            artist=str(doc.get("artist") or "Unknown"),
            spotify_url=doc.get("spotify_url"),
            spotify_search_url=doc.get("spotify_search_url")
            or self.spotify_search_url(doc.get("title") or "", doc.get("artist") or ""),
            album=doc.get("album"),
            genres=list(doc.get("genres") or []),
            mood_tags=list(doc.get("mood_tags") or []),
            scene_tags=list(doc.get("scene_tags") or []),
            era_tags=list(doc.get("era_tags") or []),
            language=str(doc.get("language") or "unknown"),
            energy_level=float(doc.get("energy_level") or 0.5),
            valence_level=float(doc.get("valence_level") or 0.5),
            age_affinity=doc.get("age_affinity") or self._neutral_age_affinity(),
            popularity_tier=str(doc.get("popularity_tier") or "unknown"),
            vibe_description=str(doc.get("vibe_description") or ""),
            vector_similarity=float(doc.get("similarity") or doc.get("vector_similarity") or 0),
            explicit=bool(doc.get("explicit") or False),
        )

    @staticmethod
    def _adapt_value(value: Any) -> Any:
        if isinstance(value, dict):
            return Jsonb(value)
        return value

    @staticmethod
    def _neutral_age_affinity() -> dict[str, float]:
        return {
            "teen": 0.5,
            "young_adult": 0.5,
            "adult": 0.5,
            "middle_age": 0.5,
            "senior": 0.5,
        }

    @staticmethod
    def _vector_literal(vector: list[float]) -> str:
        return "[" + ",".join(f"{value:.8f}" for value in vector) + "]"

    @staticmethod
    def spotify_search_url(title: str, artist: str) -> str:
        return "https://open.spotify.com/search/" + quote(f"{title} {artist}".strip())

    @staticmethod
    def normalized_key(title: str, artist: str) -> str:
        value = f"{title}-{artist}".lower()
        value = "".join(character if character.isalnum() else "-" for character in value)
        normalized = "-".join(part for part in value.split("-") if part)
        return normalized or "song"
