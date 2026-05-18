from __future__ import annotations

import argparse
import asyncio
import json
import math
import random
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx
import psycopg
from dotenv import dotenv_values
from openai import APIConnectionError, APIStatusError, AsyncOpenAI, RateLimitError
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb


ROOT = Path(__file__).resolve().parents[2]
ENV = dotenv_values(ROOT / "backend" / ".env")


@dataclass(frozen=True)
class QuerySpec:
    query: str
    genres: tuple[str, ...]
    mood_tags: tuple[str, ...]
    scene_tags: tuple[str, ...]
    era_tags: tuple[str, ...]
    language: str
    energy: float
    valence: float
    description: str


@dataclass
class TrackDocument:
    song_id: str
    track_id: str
    title: str
    artist: str
    spotify_url: str
    spotify_search_url: str
    album: str | None
    artwork: str | None
    duration_ms: int | None
    explicit: bool
    genres: list[str]
    mood_tags: list[str]
    scene_tags: list[str]
    era_tags: list[str]
    language: str
    energy_level: float
    valence_level: float
    age_affinity: dict[str, float]
    popularity_tier: str
    vibe_description: str
    embedding: list[float] | None = None


GENRE_PROFILES = [
    ("v-pop", "vi", ("v-pop", "pop"), ("modern", "2020s"), 0.55, 0.58),
    ("vietnamese indie", "vi", ("indie", "v-pop"), ("modern_indie", "2020s"), 0.46, 0.54),
    ("vietnamese ballad", "vi", ("ballad", "pop"), ("modern",), 0.35, 0.34),
    ("bolero", "vi", ("bolero", "oldies"), ("classic", "oldies"), 0.34, 0.42),
    ("lofi beats", "instrumental", ("lo-fi", "instrumental"), ("modern", "2020s"), 0.32, 0.50),
    ("study focus", "instrumental", ("focus", "ambient"), ("modern",), 0.28, 0.50),
    ("ambient", "instrumental", ("ambient", "instrumental"), ("modern",), 0.20, 0.52),
    ("piano", "instrumental", ("piano", "classical"), ("modern",), 0.25, 0.55),
    ("classical", "instrumental", ("classical", "orchestral"), ("classic",), 0.30, 0.50),
    ("jazz", "instrumental", ("jazz", "soul"), ("classic", "modern"), 0.42, 0.58),
    ("acoustic", "en", ("acoustic", "singer-songwriter"), ("modern",), 0.38, 0.60),
    ("indie pop", "en", ("indie", "pop"), ("modern", "2020s"), 0.52, 0.62),
    ("chill pop", "en", ("chill pop", "pop"), ("modern", "2020s"), 0.48, 0.62),
    ("r&b", "en", ("r&b", "soul"), ("modern", "2020s"), 0.52, 0.60),
    ("hip hop", "en", ("hip-hop", "rap"), ("modern", "2020s"), 0.70, 0.58),
    ("edm", "en", ("edm", "dance"), ("modern", "2020s"), 0.82, 0.70),
    ("house", "en", ("house", "dance"), ("modern",), 0.74, 0.68),
    ("rock", "en", ("rock", "alternative"), ("modern", "classic"), 0.74, 0.55),
    ("folk", "en", ("folk", "acoustic"), ("modern",), 0.34, 0.58),
    ("soul", "en", ("soul", "r&b"), ("classic", "modern"), 0.45, 0.62),
    ("k-pop", "ko", ("k-pop", "pop"), ("modern", "2020s"), 0.66, 0.68),
    ("j-pop", "ja", ("j-pop", "pop"), ("modern", "2020s"), 0.60, 0.66),
    ("city pop", "ja", ("city pop", "retro pop"), ("classic", "modern"), 0.56, 0.66),
    ("latin pop", "en", ("latin", "pop"), ("modern",), 0.68, 0.72),
    ("reggae", "en", ("reggae", "chill"), ("classic", "modern"), 0.48, 0.72),
]

MOOD_PROFILES = [
    ("chill", ("calm", "easy"), ("home", "cafe"), 0.40, 0.60),
    ("rainy", ("rainy", "cozy", "melancholic"), ("rain", "window"), 0.32, 0.42),
    ("sunset", ("sunset", "nostalgic", "hopeful"), ("sunset", "drive"), 0.48, 0.66),
    ("morning", ("fresh", "clear", "hopeful"), ("morning", "home"), 0.44, 0.68),
    ("night", ("moody", "intimate"), ("night", "city"), 0.46, 0.48),
    ("study", ("focus", "steady"), ("study", "workspace"), 0.30, 0.50),
    ("coffee", ("cozy", "warm"), ("cafe", "morning"), 0.42, 0.62),
    ("forest", ("healing", "grounded"), ("forest", "nature"), 0.26, 0.56),
    ("ocean", ("peaceful", "spacious"), ("sea", "beach"), 0.26, 0.60),
    ("romantic", ("romantic", "soft"), ("portrait", "cafe"), 0.44, 0.62),
    ("sad", ("sad", "reflective"), ("night", "rain"), 0.32, 0.30),
    ("happy", ("bright", "happy"), ("street", "party"), 0.66, 0.78),
    ("dreamy", ("dreamy", "soft"), ("bedroom", "blue hour"), 0.34, 0.56),
    ("workout", ("energetic", "confident"), ("gym", "street"), 0.86, 0.70),
    ("travel", ("open", "adventurous"), ("road", "beach"), 0.58, 0.70),
]

YEAR_TERMS = ["2026", "2025", "2024", "2023", "2022", "2021", "2020", "2010s", "2000s"]


def build_query_specs() -> list[QuerySpec]:
    specs: list[QuerySpec] = []
    for genre, language, genres, era_tags, base_energy, base_valence in GENRE_PROFILES:
        for mood, moods, scenes, mood_energy, mood_valence in MOOD_PROFILES:
            energy = round((base_energy + mood_energy) / 2, 2)
            valence = round((base_valence + mood_valence) / 2, 2)
            specs.append(
                QuerySpec(
                    query=f"{genre} {mood}",
                    genres=genres,
                    mood_tags=moods,
                    scene_tags=scenes,
                    era_tags=era_tags,
                    language=language,
                    energy=energy,
                    valence=valence,
                    description=(
                        f"{genre} music for {mood} visual moments, "
                        f"{', '.join(moods)} moods and {', '.join(scenes)} scenes."
                    ),
                )
            )
        for year in YEAR_TERMS:
            specs.append(
                QuerySpec(
                    query=f"{genre} {year}",
                    genres=genres,
                    mood_tags=("modern", "discoverable"),
                    scene_tags=("daily", "playlist"),
                    era_tags=era_tags + (year,),
                    language=language,
                    energy=base_energy,
                    valence=base_valence,
                    description=f"{genre} tracks around {year} for broad VibeLens music matching.",
                )
            )
    random.Random(42).shuffle(specs)
    priority = [
        "v-pop chill",
        "vietnamese indie chill",
        "lofi beats study",
        "study focus study",
        "acoustic coffee",
        "k-pop romantic",
        "jazz coffee",
        "ambient forest",
        "indie pop sunset",
    ]
    specs.sort(key=lambda item: 0 if item.query in priority else 1)
    return specs


def env_required(name: str) -> str:
    value = ENV.get(name)
    if not value:
        raise RuntimeError(f"{name} is missing from backend/.env")
    return value


def vector_literal(vector: list[float]) -> str:
    return "[" + ",".join(f"{value:.8f}" for value in vector) + "]"


def normalized_key(title: str, artist: str) -> str:
    value = f"{title}-{artist}".lower()
    normalized = "".join(character if character.isalnum() else "-" for character in value)
    return "-".join(part for part in normalized.split("-") if part) or "song"


def age_affinity() -> dict[str, float]:
    return {
        "teen": 0.5,
        "young_adult": 0.5,
        "adult": 0.5,
        "middle_age": 0.5,
        "senior": 0.5,
    }


def clean_text(value: str | None) -> str:
    return (value or "").replace("\n", " ").strip()


def popularity_tier(popularity: int | None) -> str:
    value = popularity or 0
    if value >= 75:
        return "high"
    if value >= 45:
        return "medium"
    if value > 0:
        return "niche"
    return "unknown"


def track_to_document(track: dict[str, Any], spec: QuerySpec) -> TrackDocument | None:
    track_id = track.get("id")
    title = clean_text(track.get("name"))
    artists = ", ".join(
        clean_text(artist.get("name"))
        for artist in track.get("artists", [])
        if artist.get("name")
    )
    if not track_id or not title or not artists:
        return None
    album = track.get("album") or {}
    images = album.get("images") or []
    vibe_description = (
        f"{spec.description} Track: {title} by {artists}. "
        f"Album: {clean_text(album.get('name'))}. "
        f"Genres: {', '.join(spec.genres)}. "
        f"Moods: {', '.join(spec.mood_tags)}. "
        f"Scenes: {', '.join(spec.scene_tags)}."
    )
    return TrackDocument(
        song_id=f"spotify:track:{track_id}",
        track_id=track_id,
        title=title,
        artist=artists,
        spotify_url=(track.get("external_urls") or {}).get("spotify") or "",
        spotify_search_url="https://open.spotify.com/search/" + quote(f"{title} {artists}".strip()),
        album=clean_text(album.get("name")) or None,
        artwork=images[0].get("url") if images else None,
        duration_ms=track.get("duration_ms"),
        explicit=bool(track.get("explicit") or False),
        genres=list(spec.genres),
        mood_tags=list(spec.mood_tags),
        scene_tags=list(spec.scene_tags),
        era_tags=list(spec.era_tags),
        language=spec.language,
        energy_level=spec.energy,
        valence_level=spec.valence,
        age_affinity=age_affinity(),
        popularity_tier=popularity_tier(track.get("popularity")),
        vibe_description=vibe_description,
    )


async def spotify_token(client: httpx.AsyncClient) -> str:
    response = await client.post(
        "https://accounts.spotify.com/api/token",
        data={"grant_type": "client_credentials"},
        auth=(env_required("SPOTIFY_CLIENT_ID"), env_required("SPOTIFY_CLIENT_SECRET")),
        timeout=20,
    )
    response.raise_for_status()
    return response.json()["access_token"]


async def spotify_get(
    client: httpx.AsyncClient,
    url: str,
    *,
    headers: dict[str, str],
    params: dict[str, Any],
    max_retries: int = 5,
) -> httpx.Response:
    for attempt in range(max_retries):
        response = await client.get(url, headers=headers, params=params, timeout=30)
        if response.status_code == 429:
            retry_after = float(response.headers.get("Retry-After") or 2)
            sleep_for = min(retry_after + 0.5, 30)
            print(
                f"spotify_rate_limit retry_after={retry_after} "
                f"sleeping={sleep_for} query='{params.get('q', '')}'",
                flush=True,
            )
            await asyncio.sleep(sleep_for)
            continue
        if response.status_code >= 500:
            await asyncio.sleep(2**attempt)
            continue
        return response
    return response


async def collect_tracks(
    target: int,
    existing_ids: set[str],
    max_per_query: int,
    market: str,
    spotify_delay: float,
) -> list[TrackDocument]:
    token: str
    docs: list[TrackDocument] = []
    seen = set(existing_ids)
    specs = build_query_specs()
    async with httpx.AsyncClient() as client:
        token = await spotify_token(client)
        headers = {"Authorization": f"Bearer {token}"}
        page_size = 10
        for index, spec in enumerate(specs, start=1):
            if len(docs) >= target:
                break
            added_for_query = 0
            offsets = range(0, max_per_query, page_size)
            for offset in offsets:
                if len(docs) >= target:
                    break
                response = await spotify_get(
                    client,
                    "https://api.spotify.com/v1/search",
                    headers=headers,
                    params={
                        "q": spec.query,
                        "type": "track",
                        "limit": page_size,
                        "offset": offset,
                        "market": market,
                    },
                )
                if response.status_code >= 400:
                    break
                items = (response.json().get("tracks") or {}).get("items") or []
                if not items:
                    break
                for track in items:
                    if not track:
                        continue
                    track_id = track.get("id")
                    song_id = f"spotify:track:{track_id}" if track_id else ""
                    if not song_id or song_id in seen:
                        continue
                    doc = track_to_document(track, spec)
                    if doc is None:
                        continue
                    seen.add(song_id)
                    docs.append(doc)
                    added_for_query += 1
                    if len(docs) >= target:
                        break
                await asyncio.sleep(spotify_delay)
            if index % 10 == 0 or added_for_query:
                print(
                    f"collect query={index}/{len(specs)} added={added_for_query} "
                    f"total_new={len(docs)} q='{spec.query}'",
                    flush=True,
                )
    return docs


def db_connect() -> psycopg.Connection:
    return psycopg.connect(env_required("SUPABASE_DB_URL"), autocommit=True, row_factory=dict_row)


def existing_song_ids() -> set[str]:
    with db_connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute("select song_id from songs")
            return {row["song_id"] for row in cursor.fetchall()}


def count_songs() -> tuple[int, int]:
    with db_connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute("select count(*) as count from songs")
            total = int(cursor.fetchone()["count"])
            cursor.execute("select count(*) as count from songs where embedding is not null")
            embedded = int(cursor.fetchone()["count"])
    return total, embedded


def start_job(target: int) -> str | None:
    with db_connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                insert into ingestion_jobs
                  (source, playlist_ids, status, started_at, created_at)
                values (%s, %s, %s, %s, %s)
                returning id
                """,
                (
                    "spotify_search_seed",
                    [f"target:{target}"],
                    "running",
                    datetime.now(UTC).isoformat(),
                    datetime.now(UTC).isoformat(),
                ),
            )
            row = cursor.fetchone()
            return str(row["id"]) if row else None


def finish_job(
    job_id: str | None,
    status: str,
    imported: int,
    skipped: int,
    failed: int,
    error_message: str | None = None,
) -> None:
    if not job_id:
        return
    with db_connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                update ingestion_jobs
                set status = %s,
                    imported_count = %s,
                    skipped_count = %s,
                    failed_count = %s,
                    error_message = %s,
                    finished_at = %s
                where id = %s
                """,
                (
                    status,
                    imported,
                    skipped,
                    failed,
                    error_message,
                    datetime.now(UTC).isoformat(),
                    job_id,
                ),
            )


async def embed_documents(
    docs: list[TrackDocument],
    batch_size: int,
    model: str,
    dimensions: int,
) -> None:
    client = AsyncOpenAI(api_key=env_required("OPENAI_API_KEY"))
    total_batches = math.ceil(len(docs) / batch_size)
    for batch_index in range(total_batches):
        start = batch_index * batch_size
        batch = docs[start : start + batch_size]
        inputs = [doc.vibe_description for doc in batch]
        for attempt in range(6):
            try:
                response = await client.embeddings.create(
                    model=model,
                    input=inputs,
                    dimensions=dimensions,
                )
                break
            except RateLimitError:
                if attempt == 5:
                    raise
                await asyncio.sleep(5 + 5 * attempt)
            except (APIConnectionError, APIStatusError):
                if attempt == 5:
                    raise
                await asyncio.sleep(2 + 2 * attempt)
        for doc, item in zip(batch, response.data, strict=True):
            embedding = list(item.embedding)
            if len(embedding) != dimensions:
                raise RuntimeError(
                    f"embedding dimension mismatch: got {len(embedding)}, expected {dimensions}"
                )
            doc.embedding = embedding
        print(
            f"embedded_batch={batch_index + 1}/{total_batches} "
            f"embedded={min(start + len(batch), len(docs))}/{len(docs)}",
            flush=True,
        )


def insert_documents(docs: list[TrackDocument], batch_size: int, embedding_model: str) -> int:
    statement = """
        insert into songs (
          song_id,
          track_id,
          title,
          artist,
          normalized_key,
          spotify_url,
          spotify_search_url,
          album,
          artwork,
          duration_ms,
          explicit,
          genres,
          mood_tags,
          scene_tags,
          era_tags,
          language,
          energy_level,
          valence_level,
          age_affinity,
          popularity_tier,
          vibe_description,
          embedding,
          embedding_model,
          embedding_created_at,
          source,
          ingested_at
        )
        values (
          %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
          %s, %s, %s, %s, %s::vector, %s, %s, %s, %s
        )
        on conflict (normalized_key) do nothing
    """
    inserted = 0
    with db_connect() as connection:
        with connection.cursor() as cursor:
            total_batches = math.ceil(len(docs) / batch_size)
            for batch_index in range(total_batches):
                before_total, _ = count_songs()
                batch = docs[batch_index * batch_size : (batch_index + 1) * batch_size]
                rows = []
                for doc in batch:
                    if doc.embedding is None:
                        continue
                    rows.append(
                        (
                            doc.song_id,
                            doc.track_id,
                            doc.title,
                            doc.artist,
                            normalized_key(doc.title, doc.artist),
                            doc.spotify_url or None,
                            doc.spotify_search_url,
                            doc.album,
                            doc.artwork,
                            doc.duration_ms,
                            doc.explicit,
                            doc.genres,
                            doc.mood_tags,
                            doc.scene_tags,
                            doc.era_tags,
                            doc.language,
                            doc.energy_level,
                            doc.valence_level,
                            Jsonb(doc.age_affinity),
                            doc.popularity_tier,
                            doc.vibe_description,
                            vector_literal(doc.embedding),
                            embedding_model,
                            datetime.now(UTC).isoformat(),
                            "spotify_ingestion",
                            datetime.now(UTC).isoformat(),
                        )
                    )
                cursor.executemany(statement, rows)
                after_total, _ = count_songs()
                batch_inserted = after_total - before_total
                inserted += batch_inserted
                print(
                    f"insert_batch={batch_index + 1}/{total_batches} "
                    f"batch_inserted={batch_inserted} total_inserted={inserted}",
                    flush=True,
                )
    return inserted


async def run(args: argparse.Namespace) -> None:
    total_before, embedded_before = count_songs()
    print(f"before songs={total_before} embedded={embedded_before}", flush=True)
    existing = existing_song_ids()
    job_id = start_job(args.target)
    imported = 0
    try:
        docs = await collect_tracks(
            target=args.target,
            existing_ids=existing,
            max_per_query=args.max_per_query,
            market=args.market,
            spotify_delay=args.spotify_delay,
        )
        print(f"collected_new={len(docs)}", flush=True)
        if not docs:
            finish_job(job_id, "completed", 0, 0, 0)
            return
        if args.dry_run:
            finish_job(job_id, "completed", 0, len(docs), 0)
            return
        await embed_documents(
            docs,
            args.embedding_batch_size,
            args.embedding_model,
            args.embedding_dimension,
        )
        imported = insert_documents(docs, args.insert_batch_size, args.embedding_model)
        total_after, embedded_after = count_songs()
        print(f"after songs={total_after} embedded={embedded_after}", flush=True)
        finish_job(job_id, "completed", imported, max(0, len(docs) - imported), 0)
    except Exception as exc:
        finish_job(job_id, "failed", imported, 0, 1, str(exc)[:500])
        raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Seed VibeLens Supabase songs from Spotify track search."
    )
    parser.add_argument("--target", type=int, default=10000)
    parser.add_argument("--market", default="VN")
    parser.add_argument("--max-per-query", type=int, default=250)
    parser.add_argument("--spotify-delay", type=float, default=0.12)
    parser.add_argument("--embedding-batch-size", type=int, default=128)
    parser.add_argument("--insert-batch-size", type=int, default=250)
    parser.add_argument(
        "--embedding-model",
        default=ENV.get("EMBEDDING_MODEL")
        or ENV.get("OPENAI_EMBEDDING_MODEL")
        or "text-embedding-3-small",
    )
    parser.add_argument(
        "--embedding-dimension",
        type=int,
        default=int(ENV.get("EMBEDDING_DIMENSION") or 768),
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    started = time.time()
    asyncio.run(run(parse_args()))
    print(f"elapsed_seconds={round(time.time() - started, 1)}", flush=True)
