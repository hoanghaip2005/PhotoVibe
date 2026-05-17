from __future__ import annotations

import argparse
import asyncio
import math
import random
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any
from urllib.parse import quote

import httpx

if __package__:
    from .seed_spotify_search import (
        ENV,
        GENRE_PROFILES,
        MOOD_PROFILES,
        YEAR_TERMS,
        QuerySpec,
        TrackDocument,
        clean_text,
        count_songs,
        db_connect,
        embed_documents,
        existing_song_ids,
        insert_documents,
    )
else:
    from seed_spotify_search import (
        ENV,
        GENRE_PROFILES,
        MOOD_PROFILES,
        YEAR_TERMS,
        QuerySpec,
        TrackDocument,
        clean_text,
        count_songs,
        db_connect,
        embed_documents,
        existing_song_ids,
        insert_documents,
    )


# Apple Search API supports music/song search with limit 1..200 and recommends
# roughly 20 calls/minute. Source:
# https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html
ITUNES_SEARCH_URL = "https://itunes.apple.com/search"
ITUNES_SOURCE = "itunes_search_seed"
ITUNES_MAX_LIMIT = 200


COUNTRIES_BY_LANGUAGE = {
    "vi": ("VN", "US", "SG"),
    "ko": ("KR", "US", "JP"),
    "ja": ("JP", "US", "KR"),
    "instrumental": ("US", "GB", "JP", "VN", "AU"),
    "en": ("US", "GB", "AU", "CA", "VN"),
}

BROAD_QUERY_SUFFIXES = (
    "songs",
    "hits",
    "best of",
    "essentials",
    "playlist",
    "new music",
    "top songs",
)

DECADE_TERMS = ("1990s", "2000s", "2010s", "2020s")


@dataclass(frozen=True)
class SearchWorkItem:
    spec: QuerySpec
    country: str


def dedupe(values: list[str] | tuple[str, ...]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        clean = clean_tag(value)
        if not clean or clean in seen:
            continue
        seen.add(clean)
        output.append(clean)
    return output


def clean_tag(value: str | None) -> str:
    return clean_text(value).lower().replace("&", "and")


def clamp(value: float) -> float:
    return max(0.0, min(1.0, round(value, 2)))


def age_affinity_for(spec: QuerySpec, era_tags: list[str]) -> dict[str, float]:
    genres = {clean_tag(item) for item in spec.genres}
    tags = {clean_tag(item) for item in era_tags}
    affinity = {
        "teen": 0.5,
        "young_adult": 0.55,
        "adult": 0.55,
        "middle_age": 0.5,
        "senior": 0.45,
    }
    if genres & {"k-pop", "j-pop", "edm", "dance", "hip-hop", "rap", "pop"}:
        affinity["teen"] += 0.15
        affinity["young_adult"] += 0.18
    if genres & {"jazz", "soul", "classical", "bolero", "oldies"}:
        affinity["adult"] += 0.15
        affinity["middle_age"] += 0.18
        affinity["senior"] += 0.1
    if tags & {"2020s", "2026", "2025", "2024", "2023", "2022", "2021", "2020"}:
        affinity["teen"] += 0.1
        affinity["young_adult"] += 0.12
    if tags & {"classic", "oldies", "1990s", "2000s"}:
        affinity["adult"] += 0.1
        affinity["middle_age"] += 0.12
        affinity["senior"] += 0.1
    return {key: clamp(value) for key, value in affinity.items()}


def popularity_tier_for(spec: QuerySpec, country: str) -> str:
    genres = {clean_tag(item) for item in spec.genres}
    if country in {"US", "GB", "JP", "KR", "VN"} and genres & {
        "pop",
        "v-pop",
        "k-pop",
        "j-pop",
        "hip-hop",
        "edm",
        "dance",
        "rock",
    }:
        return "medium"
    if genres & {"ambient", "instrumental", "classical", "lo-fi", "focus"}:
        return "niche"
    return "unknown"


def era_tags_for(track: dict[str, Any], spec: QuerySpec) -> list[str]:
    tags = list(spec.era_tags)
    release_date = str(track.get("releaseDate") or "")
    year = release_date[:4] if len(release_date) >= 4 and release_date[:4].isdigit() else ""
    if year:
        tags.append(year)
        decade = f"{year[:3]}0s"
        tags.append(decade)
        if int(year) >= 2020:
            tags.append("2020s")
            tags.append("trending")
        elif int(year) >= 2010:
            tags.append("2010s")
            tags.append("modern")
        elif int(year) <= 2009:
            tags.append("classic")
    return dedupe(tuple(tags))


def build_query_specs() -> list[QuerySpec]:
    specs: list[QuerySpec] = []
    for genre, language, genres, era_tags, base_energy, base_valence in GENRE_PROFILES:
        for suffix in BROAD_QUERY_SUFFIXES:
            specs.append(
                QuerySpec(
                    query=f"{genre} {suffix}",
                    genres=genres,
                    mood_tags=("discoverable", "daily"),
                    scene_tags=("playlist", "daily"),
                    era_tags=era_tags,
                    language=language,
                    energy=base_energy,
                    valence=base_valence,
                    description=f"{genre} catalog tracks for broad VibeLens matching.",
                )
            )
        for decade in DECADE_TERMS:
            specs.append(
                QuerySpec(
                    query=f"{genre} {decade}",
                    genres=genres,
                    mood_tags=("discoverable", "nostalgic"),
                    scene_tags=("playlist", "daily"),
                    era_tags=era_tags + (decade,),
                    language=language,
                    energy=base_energy,
                    valence=base_valence,
                    description=f"{genre} tracks from the {decade} for era-aware matching.",
                )
            )
        for mood, moods, scenes, mood_energy, mood_valence in MOOD_PROFILES:
            specs.append(
                QuerySpec(
                    query=f"{genre} {mood}",
                    genres=genres,
                    mood_tags=moods,
                    scene_tags=scenes,
                    era_tags=era_tags,
                    language=language,
                    energy=round((base_energy + mood_energy) / 2, 2),
                    valence=round((base_valence + mood_valence) / 2, 2),
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
    random.Random(84).shuffle(specs)
    priority_queries = {
        "v-pop songs",
        "vietnamese indie songs",
        "vietnamese ballad songs",
        "lofi beats study",
        "study focus study",
        "ambient forest",
        "acoustic coffee",
        "indie pop sunset",
        "k-pop songs",
        "j-pop songs",
        "pop top songs",
        "r&b songs",
        "edm top songs",
        "jazz coffee",
    }
    specs.sort(key=lambda item: 0 if item.query in priority_queries else 1)
    return specs


def countries_for(spec: QuerySpec, explicit_countries: list[str]) -> tuple[str, ...]:
    if explicit_countries:
        return tuple(explicit_countries)
    return COUNTRIES_BY_LANGUAGE.get(spec.language, COUNTRIES_BY_LANGUAGE["en"])


def build_work_items(explicit_countries: list[str]) -> list[SearchWorkItem]:
    items: list[SearchWorkItem] = []
    for spec in build_query_specs():
        for country in countries_for(spec, explicit_countries):
            items.append(SearchWorkItem(spec=spec, country=country))
    return items


def normalize_fingerprint(title: str, artist: str) -> str:
    return " ".join(f"{title} {artist}".lower().split())


def existing_fingerprints() -> set[str]:
    with db_connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute("select title, artist from songs")
            rows = cursor.fetchall()
    return {
        normalize_fingerprint(str(row["title"] or ""), str(row["artist"] or ""))
        for row in rows
    }


def artwork_url(track: dict[str, Any]) -> str | None:
    url = clean_text(track.get("artworkUrl100"))
    if not url:
        return None
    return url.replace("100x100bb", "600x600bb")


def track_to_document(track: dict[str, Any], spec: QuerySpec, country: str) -> TrackDocument | None:
    track_id = track.get("trackId")
    title = clean_text(track.get("trackName"))
    artist = clean_text(track.get("artistName"))
    if not track_id or not title or not artist:
        return None
    if clean_text(track.get("kind")) and clean_text(track.get("kind")) != "song":
        return None

    primary_genre = clean_tag(track.get("primaryGenreName"))
    genres = dedupe((*spec.genres, primary_genre))
    era_tags = era_tags_for(track, spec)
    release_date = clean_text(track.get("releaseDate"))[:10]
    explicit = clean_text(track.get("trackExplicitness")).lower() == "explicit"
    track_view_url = clean_text(track.get("trackViewUrl"))
    vibe_description = (
        f"{spec.description} Track: {title} by {artist}. "
        f"Album: {clean_text(track.get('collectionName'))}. "
        f"Primary genre: {primary_genre or 'unknown'}. "
        f"Genres: {', '.join(genres)}. "
        f"Moods: {', '.join(spec.mood_tags)}. "
        f"Scenes: {', '.join(spec.scene_tags)}. "
        f"Era tags: {', '.join(era_tags)}. "
        f"Release: {release_date or 'unknown'}. "
        f"Storefront: {country}. "
        f"Energy {spec.energy}; valence {spec.valence}. "
        f"Catalog source: Apple iTunes Search API. "
        f"Apple URL: {track_view_url or 'not provided'}."
    )
    return TrackDocument(
        song_id=f"itunes:track:{track_id}",
        track_id=str(track_id),
        title=title,
        artist=artist,
        spotify_url="",
        spotify_search_url="https://open.spotify.com/search/" + quote(f"{title} {artist}".strip()),
        album=clean_text(track.get("collectionName")) or None,
        artwork=artwork_url(track),
        duration_ms=int(track["trackTimeMillis"]) if track.get("trackTimeMillis") else None,
        explicit=explicit,
        genres=genres,
        mood_tags=dedupe(spec.mood_tags),
        scene_tags=dedupe(spec.scene_tags),
        era_tags=era_tags,
        language=spec.language,
        energy_level=spec.energy,
        valence_level=spec.valence,
        age_affinity=age_affinity_for(spec, era_tags),
        popularity_tier=popularity_tier_for(spec, country),
        vibe_description=vibe_description,
    )


async def itunes_get(
    client: httpx.AsyncClient,
    spec: QuerySpec,
    country: str,
    limit: int,
    explicit: str,
    max_retries: int,
) -> dict[str, Any]:
    params = {
        "term": spec.query,
        "country": country,
        "media": "music",
        "entity": "song",
        "limit": max(1, min(limit, ITUNES_MAX_LIMIT)),
        "lang": "en_us",
        "explicit": explicit,
    }
    response: httpx.Response | None = None
    for attempt in range(max_retries):
        response = await client.get(ITUNES_SEARCH_URL, params=params, timeout=30)
        if response.status_code in {403, 429}:
            wait_seconds = min(30.0, 5.0 + attempt * 5.0)
            print(
                f"itunes_throttle status={response.status_code} sleeping={wait_seconds} "
                f"country={country} query='{spec.query}'",
                flush=True,
            )
            await asyncio.sleep(wait_seconds)
            continue
        if response.status_code >= 500:
            await asyncio.sleep(min(30.0, 2.0**attempt))
            continue
        response.raise_for_status()
        return response.json()
    if response is not None:
        response.raise_for_status()
    return {"resultCount": 0, "results": []}


async def collect_tracks(
    target: int,
    existing_ids: set[str],
    fingerprints: set[str],
    explicit_countries: list[str],
    limit_per_query: int,
    explicit: str,
    delay_seconds: float,
    max_retries: int,
) -> list[TrackDocument]:
    docs: list[TrackDocument] = []
    seen_ids = set(existing_ids)
    seen_fingerprints = set(fingerprints)
    work_items = build_work_items(explicit_countries)
    async with httpx.AsyncClient(
        headers={"User-Agent": "VibeLens/1.0 music catalog ingestion"}
    ) as client:
        for index, item in enumerate(work_items, start=1):
            if len(docs) >= target:
                break
            payload = await itunes_get(
                client,
                item.spec,
                item.country,
                limit_per_query,
                explicit,
                max_retries,
            )
            added_for_query = 0
            for track in payload.get("results") or []:
                song_id = f"itunes:track:{track.get('trackId')}" if track.get("trackId") else ""
                if not song_id or song_id in seen_ids:
                    continue
                doc = track_to_document(track, item.spec, item.country)
                if doc is None:
                    continue
                fingerprint = normalize_fingerprint(doc.title, doc.artist)
                if fingerprint in seen_fingerprints:
                    continue
                seen_ids.add(song_id)
                seen_fingerprints.add(fingerprint)
                docs.append(doc)
                added_for_query += 1
                if len(docs) >= target:
                    break
            if index % 10 == 0 or added_for_query:
                print(
                    f"collect query={index}/{len(work_items)} added={added_for_query} "
                    f"total_new={len(docs)} country={item.country} q='{item.spec.query}'",
                    flush=True,
                )
            await asyncio.sleep(delay_seconds)
    return docs


def start_job(target: int, dry_run: bool) -> str | None:
    if dry_run:
        return None
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
                    ITUNES_SOURCE,
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


async def run(args: argparse.Namespace) -> None:
    total_before, embedded_before = count_songs()
    print(f"before songs={total_before} embedded={embedded_before}", flush=True)
    existing_ids = existing_song_ids()
    fingerprints = existing_fingerprints()
    countries = [
        country.strip().upper()
        for country in (args.countries or "").split(",")
        if country.strip()
    ]
    if args.delay_seconds < 3 and not args.dry_run:
        print(
            "warning=delay_seconds below Apple Search API guidance; "
            "consider at least 3.1 seconds for 20 calls/minute.",
            flush=True,
        )
    job_id = start_job(args.target, args.dry_run)
    imported = 0
    try:
        docs = await collect_tracks(
            target=args.target,
            existing_ids=existing_ids,
            fingerprints=fingerprints,
            explicit_countries=countries,
            limit_per_query=args.limit_per_query,
            explicit=args.explicit,
            delay_seconds=args.delay_seconds,
            max_retries=args.max_retries,
        )
        print(f"collected_new={len(docs)}", flush=True)
        if args.dry_run:
            print("dry_run=true skip_embeddings=true skip_insert=true", flush=True)
            return
        if not docs:
            finish_job(job_id, "completed", 0, 0, 0)
            return
        await embed_documents(docs, args.embedding_batch_size, args.embedding_model)
        imported = insert_documents(docs, args.insert_batch_size)
        total_after, embedded_after = count_songs()
        print(f"after songs={total_after} embedded={embedded_after}", flush=True)
        finish_job(job_id, "completed", imported, max(0, len(docs) - imported), 0)
    except Exception as exc:
        finish_job(job_id, "failed", imported, 0, 1, str(exc)[:500])
        raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Seed VibeLens Supabase songs from Apple iTunes Search API."
    )
    parser.add_argument("--target", type=int, default=10000)
    parser.add_argument("--countries", default="")
    parser.add_argument("--limit-per-query", type=int, default=ITUNES_MAX_LIMIT)
    parser.add_argument("--delay-seconds", type=float, default=3.2)
    parser.add_argument("--max-retries", type=int, default=5)
    parser.add_argument("--embedding-batch-size", type=int, default=128)
    parser.add_argument("--insert-batch-size", type=int, default=250)
    parser.add_argument(
        "--embedding-model",
        default=ENV.get("OPENAI_EMBEDDING_MODEL") or "text-embedding-3-small",
    )
    parser.add_argument("--explicit", choices=("Yes", "No"), default="No")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    started = time.time()
    asyncio.run(run(parse_args()))
    print(f"elapsed_seconds={round(time.time() - started, 1)}", flush=True)
