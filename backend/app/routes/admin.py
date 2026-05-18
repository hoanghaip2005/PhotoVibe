import csv
from io import StringIO
from typing import Annotated

from fastapi import APIRouter, Depends, File, UploadFile

from ..deps import ingestion_service_dep, require_admin_token
from ..errors import AppError
from ..models import IngestSpotifyPlaylistRequest, IngestionResponse
from ..services.ingestion_service import SpotifyIngestionService

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post(
    "/ingest-spotify-playlist",
    response_model=IngestionResponse,
    dependencies=[Depends(require_admin_token)],
)
async def ingest_spotify_playlist(
    request: IngestSpotifyPlaylistRequest,
    service: Annotated[SpotifyIngestionService, Depends(ingestion_service_dep)],
) -> IngestionResponse:
    return await service.ingest_playlists(
        playlist_ids=request.playlist_ids,
        limit_per_playlist=request.limit_per_playlist,
        regenerate_vibe_description=request.regenerate_vibe_description,
        regenerate_embedding=request.regenerate_embedding,
    )


@router.post(
    "/ingest-songs-csv",
    response_model=IngestionResponse,
    dependencies=[Depends(require_admin_token)],
)
async def ingest_songs_csv(
    service: Annotated[SpotifyIngestionService, Depends(ingestion_service_dep)],
    file: UploadFile = File(...),
    regenerateVibeDescription: bool = False,
    regenerateEmbedding: bool = False,
) -> IngestionResponse:
    raw = (await file.read()).decode("utf-8-sig")
    rows = [
        {str(key).strip().lower(): (value or "").strip() for key, value in row.items()}
        for row in csv.DictReader(StringIO(raw))
    ]
    required = {"title", "artist"}
    if rows and not required.issubset(rows[0].keys()):
        raise AppError(
            "INVALID_CSV",
            "CSV must include title and artist columns.",
            status_code=422,
        )
    return await service.ingest_csv_rows(
        rows,
        regenerate_vibe_description=regenerateVibeDescription,
        regenerate_embedding=regenerateEmbedding,
    )
