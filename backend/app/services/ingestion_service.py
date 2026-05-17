import json
import re
from datetime import UTC, datetime
from typing import Any
from urllib.parse import quote

from ..config import Settings
from ..models import IngestionResponse
from ..repositories.pgvector import SupabaseVectorSongRepository
from ..repositories.supabase import SupabaseRepository
from .openai_service import OpenAIVibeService
from .spotify_service import SpotifyClient


class SpotifyIngestionService:
    def __init__(
        self,
        settings: Settings,
        spotify: SpotifyClient,
        openai: OpenAIVibeService,
        songs: SupabaseVectorSongRepository,
        supabase: SupabaseRepository,
    ) -> None:
        self.settings = settings
        self.spotify = spotify
        self.openai = openai
        self.songs = songs
        self.supabase = supabase

    async def ingest_playlists(
        self,
        playlist_ids: list[str],
        limit_per_playlist: int,
        regenerate_vibe_description: bool,
        admin_user_id: str | None = None,
    ) -> IngestionResponse:
        job_id = await self._start_job("spotify", playlist_ids, admin_user_id)
        imported = 0
        skipped = 0
        failed = 0
        try:
            seen: set[str] = set()
            for playlist_id in playlist_ids:
                items = await self.spotify.playlist_tracks(playlist_id, limit_per_playlist)
                for item in items:
                    normalized = self.spotify.normalize_track(item)
                    if not normalized:
                        failed += 1
                        continue
                    key = normalized["song_id"]
                    if key in seen:
                        skipped += 1
                        continue
                    seen.add(key)
                    existing = await self.songs.find_by_song_id(key)
                    if existing and not regenerate_vibe_description:
                        skipped += 1
                        continue
                    try:
                        metadata = await self.openai.tag_song(
                            title=normalized["title"],
                            artist=normalized["artist"],
                            album=normalized.get("album"),
                            genres=[],
                            playlist_context=playlist_id,
                        )
                        document = self._song_document(normalized, metadata)
                        await self._attach_embedding(document)
                        inserted = await self.songs.upsert_song(
                            document,
                            replace_existing=regenerate_vibe_description,
                        )
                        imported += 1 if inserted else 0
                        skipped += 0 if inserted else 1
                    except Exception:
                        failed += 1
            await self._finish_job(job_id, "completed", imported, skipped, failed)
        except Exception as exc:
            await self._finish_job(job_id, "failed", imported, skipped, failed, str(exc))
            raise
        return IngestionResponse(
            imported=imported,
            skippedDuplicates=skipped,
            failed=failed,
            collection=self.settings.song_collection,
        )

    async def ingest_csv_rows(
        self,
        rows: list[dict[str, str]],
        regenerate_vibe_description: bool = False,
        admin_user_id: str | None = None,
    ) -> IngestionResponse:
        job_id = await self._start_job("csv", [], admin_user_id)
        imported = 0
        skipped = 0
        failed = 0
        try:
            seen: set[str] = set()
            for row in rows:
                try:
                    normalized = self._csv_track_document(row)
                    key = normalized["song_id"]
                    if key in seen:
                        skipped += 1
                        continue
                    seen.add(key)
                    existing = await self.songs.find_by_song_id(key)
                    if existing and not regenerate_vibe_description:
                        skipped += 1
                        continue

                    metadata = self._csv_metadata(row)
                    if not metadata.get("vibe_description"):
                        generated = await self.openai.tag_song(
                            title=normalized["title"],
                            artist=normalized["artist"],
                            album=normalized.get("album"),
                            genres=metadata.get("genres") or [],
                            playlist_context="csv",
                        )
                        metadata = self._merge_metadata(generated, metadata)
                    document = self._song_document(normalized, metadata)
                    await self._attach_embedding(document)
                    inserted = await self.songs.upsert_song(
                        document,
                        replace_existing=regenerate_vibe_description,
                    )
                    imported += 1 if inserted else 0
                    skipped += 0 if inserted else 1
                except Exception:
                    failed += 1
            await self._finish_job(job_id, "completed", imported, skipped, failed)
        except Exception as exc:
            await self._finish_job(job_id, "failed", imported, skipped, failed, str(exc))
            raise
        return IngestionResponse(
            imported=imported,
            skippedDuplicates=skipped,
            failed=failed,
            collection=self.settings.song_collection,
        )

    def _song_document(self, normalized: dict[str, Any], metadata: dict[str, Any]) -> dict[str, Any]:
        vibe_description = metadata.get("vibe_description") or ""
        return {
            **normalized,
            "genres": metadata.get("genres") or [],
            "mood_tags": metadata.get("mood_tags") or [],
            "scene_tags": metadata.get("scene_tags") or [],
            "era_tags": metadata.get("era_tags") or [],
            "language": metadata.get("language") or "unknown",
            "energy_level": metadata.get("energy_level") or 0.5,
            "valence_level": metadata.get("valence_level") or 0.5,
            "age_affinity": metadata.get("age_affinity")
            or {
                "teen": 0.5,
                "young_adult": 0.5,
                "adult": 0.5,
                "middle_age": 0.5,
                "senior": 0.5,
            },
            "popularity_tier": metadata.get("popularity_tier") or "unknown",
            "vibe_description": vibe_description,
            "$vectorize": vibe_description,
            "ingested_at": datetime.now(UTC).isoformat(),
        }

    async def _attach_embedding(self, document: dict[str, Any]) -> None:
        source_text = document.get("vibe_description") or document.get("$vectorize")
        if not source_text:
            source_text = f"{document.get('title', '')} {document.get('artist', '')}".strip()
        document["embedding"] = await self.openai.embed_text(source_text)

    def _csv_track_document(self, row: dict[str, str]) -> dict[str, Any]:
        title = self._cell(row, "title")
        artist = self._cell(row, "artist")
        if not title or not artist:
            raise ValueError("CSV row must include title and artist.")
        track_id = self._cell(row, "track_id") or self._track_id_from_url(
            self._cell(row, "spotify_url")
        )
        song_id = self._cell(row, "song_id") or (
            f"spotify:track:{track_id}" if track_id else f"manual:{self._slug(title, artist)}"
        )
        spotify_search_url = self._cell(row, "spotify_search_url") or (
            "https://open.spotify.com/search/" + quote(f"{title} {artist}".strip())
        )
        return {
            "song_id": song_id,
            "track_id": track_id,
            "title": title,
            "artist": artist,
            "spotify_url": self._cell(row, "spotify_url") or None,
            "spotify_search_url": spotify_search_url,
            "album": self._cell(row, "album") or None,
            "artwork": self._cell(row, "artwork") or None,
            "duration_ms": self._int_cell(row, "duration_ms"),
            "explicit": self._bool_cell(row, "explicit", False),
        }

    def _csv_metadata(self, row: dict[str, str]) -> dict[str, Any]:
        metadata: dict[str, Any] = {}
        for key in ("genres", "mood_tags", "scene_tags", "era_tags"):
            values = self._list_cell(row, key)
            if values:
                metadata[key] = values
        for key in ("language", "popularity_tier", "vibe_description"):
            value = self._cell(row, key)
            if value:
                metadata[key] = value
        for key in ("energy_level", "valence_level"):
            value = self._cell(row, key)
            if value:
                metadata[key] = self._float_value(value, 0.5)
        age_affinity = self._age_affinity(row)
        if age_affinity:
            metadata["age_affinity"] = age_affinity
        return metadata

    def _merge_metadata(
        self,
        generated: dict[str, Any],
        provided: dict[str, Any],
    ) -> dict[str, Any]:
        merged = {**generated}
        for key, value in provided.items():
            if value in (None, "", []):
                continue
            merged[key] = value
        return merged

    def _age_affinity(self, row: dict[str, str]) -> dict[str, float] | None:
        raw = self._cell(row, "age_affinity")
        if raw:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                return {key: float(parsed.get(key, 0.5)) for key in self._age_keys()}
        values: dict[str, float] = {}
        for key in self._age_keys():
            value = self._cell(row, f"age_affinity_{key}") or self._cell(row, key)
            if value:
                values[key] = self._float_value(value, 0.5)
        return values or None

    @staticmethod
    def _age_keys() -> tuple[str, ...]:
        return ("teen", "young_adult", "adult", "middle_age", "senior")

    @staticmethod
    def _cell(row: dict[str, str], key: str) -> str:
        value = row.get(key) or row.get(key.lower()) or ""
        return value.strip() if isinstance(value, str) else str(value).strip()

    def _list_cell(self, row: dict[str, str], key: str) -> list[str]:
        value = self._cell(row, key)
        if not value:
            return []
        if value.startswith("["):
            parsed = json.loads(value)
            if isinstance(parsed, list):
                return [str(item).strip() for item in parsed if str(item).strip()]
        return [item.strip() for item in re.split(r"[|;,]", value) if item.strip()]

    def _float_cell(self, row: dict[str, str], key: str, default: float) -> float:
        return self._float_value(self._cell(row, key), default)

    @staticmethod
    def _float_value(value: str, default: float) -> float:
        try:
            return float(value)
        except (TypeError, ValueError):
            return default

    def _int_cell(self, row: dict[str, str], key: str) -> int | None:
        value = self._cell(row, key)
        if not value:
            return None
        try:
            return int(value)
        except ValueError:
            return None

    def _bool_cell(self, row: dict[str, str], key: str, default: bool) -> bool:
        value = self._cell(row, key).lower()
        if not value:
            return default
        return value in {"1", "true", "yes", "y"}

    @staticmethod
    def _track_id_from_url(url: str) -> str | None:
        match = re.search(r"open\.spotify\.com/track/([A-Za-z0-9]+)", url)
        return match.group(1) if match else None

    @staticmethod
    def _slug(title: str, artist: str) -> str:
        value = re.sub(r"[^a-z0-9]+", "-", f"{title}-{artist}".lower()).strip("-")
        return value or "song"

    async def _start_job(
        self,
        source: str,
        playlist_ids: list[str],
        admin_user_id: str | None,
    ) -> str | None:
        if not self.settings.has_supabase:
            return None
        row = await self.supabase.insert(
            "ingestion_jobs",
            {
                "admin_user_id": admin_user_id,
                "source": source,
                "playlist_ids": playlist_ids,
                "status": "running",
                "started_at": datetime.now(UTC).isoformat(),
                "created_at": datetime.now(UTC).isoformat(),
            },
        )
        return row.get("id")

    async def _finish_job(
        self,
        job_id: str | None,
        status: str,
        imported: int,
        skipped: int,
        failed: int,
        error_message: str | None = None,
    ) -> None:
        if not job_id or not self.settings.has_supabase:
            return
        await self.supabase.update(
            "ingestion_jobs",
            {"id": job_id},
            {
                "status": status,
                "imported_count": imported,
                "skipped_count": skipped,
                "failed_count": failed,
                "error_message": error_message,
                "finished_at": datetime.now(UTC).isoformat(),
            },
        )
