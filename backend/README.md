# VibeLens Backend

FastAPI backend for the production VibeLens flow:

- Runtime `/analyze` accepts an image, calls OpenAI vision, searches Supabase Postgres pgvector `songs`, reranks by music profile, and returns a `VibeResult`.
- Spotify API is used only by admin ingestion endpoints. Runtime recommendations
  are read from Supabase pgvector, never scraped live from Spotify.
- Runtime `/analyze` embeds only the AI-generated `playlistQuery` once per request.
  Song embeddings are generated only by admin ingestion or explicit regeneration.
- Supabase stores app data: profiles, preferences, results, generated playlists, playlist songs, filters, usage, and ingestion jobs.
- Flutter must not contain OpenAI, Spotify client secret, Supabase DB URL, or Supabase service role keys.

## Setup

```powershell
cd backend
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Use Python 3.12 or 3.13 for the backend environment. The local Python 3.14
beta can currently trip FastAPI/Pydantic typing internals.

## Required Env

Fill `.env` with OpenAI, `SUPABASE_DB_URL` for pgvector, optional Supabase REST
keys, Spotify client credentials, and `ADMIN_INGESTION_TOKEN`.

Embedding controls:

```powershell
AI_PROVIDER=openai
EMBEDDING_PROVIDER=openai
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_DIMENSION=768
MAX_RUNTIME_EMBEDDING_CALLS_PER_ANALYZE=1
ENABLE_SONG_EMBEDDING_IN_RUNTIME=false
ALLOW_EMBEDDING_REGENERATION=false
```

## Endpoints

- `POST /analyze`
- `GET /results`
- `GET /results/{id}`
- `POST /results/{id}/save`
- `GET /playlists`
- `GET /playlists/{id}`
- `GET /filters`
- `POST /filters`
- `POST /admin/ingest-spotify-playlist`
- `POST /admin/ingest-songs-csv`

Use `regenerateEmbedding=true` only with `ALLOW_EMBEDDING_REGENERATION=true` when
an admin intentionally wants to replace stored song embeddings.

Runtime `/analyze` does not call Spotify.

## Catalog Seed Scripts

Spotify search/playlist ingestion is useful for small curated batches, but it
can rate-limit hard. For larger offline catalog seeding, use Apple iTunes Search
API metadata and store Spotify search links for playback discovery:

```powershell
$venv = Join-Path $env:TEMP 'photovibe-backend-venv-312'
$py = Join-Path $venv 'Scripts\python.exe'
& $py D:\PhotoVibe\backend\scripts\seed_itunes_search.py --target 10000
```

The script follows Apple Search API parameters for `media=music`,
`entity=song`, `limit<=200`, and throttles by default to roughly 20 calls/minute:
https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html

## CSV Song Ingestion

`POST /admin/ingest-songs-csv` accepts a CSV with `title` and `artist`.
Recommended optional columns: `song_id`, `track_id`, `spotify_url`,
`spotify_search_url`, `album`, `genres`, `mood_tags`, `scene_tags`,
`era_tags`, `language`, `energy_level`, `valence_level`, `age_affinity`,
`popularity_tier`, `vibe_description`, `explicit`. List columns may be JSON
arrays or separated with `|`, `;`, or `,`. Rows without `vibe_description`
are tagged by the ingestion LLM before being written to Supabase pgvector.
