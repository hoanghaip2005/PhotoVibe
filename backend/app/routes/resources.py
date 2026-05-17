from typing import Annotated

from fastapi import APIRouter, Depends, Query

from ..deps import supabase_dep
from ..errors import AppError
from ..models import PaginatedResponse, SavedFilterCreate
from ..repositories.supabase import SupabaseRepository

router = APIRouter(tags=["resources"])


@router.get("/results", response_model=PaginatedResponse)
async def list_results(
    supabase: Annotated[SupabaseRepository, Depends(supabase_dep)],
    userId: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    pageSize: int = Query(default=20, ge=1, le=100),
) -> PaginatedResponse:
    rows = await supabase.select(
        "vibe_results",
        filters={"user_id": userId} if userId else None,
        limit=pageSize,
        offset=(page - 1) * pageSize,
    )
    return PaginatedResponse(
        data=rows,
        pagination={"page": page, "pageSize": pageSize, "totalItems": len(rows), "totalPages": 1},
    )


@router.get("/results/{result_id}")
async def get_result(
    result_id: str,
    supabase: Annotated[SupabaseRepository, Depends(supabase_dep)],
) -> dict:
    rows = await supabase.select("vibe_results", filters={"id": result_id}, limit=1)
    if not rows:
        raise AppError("RESULT_NOT_FOUND", "Vibe result was not found.", status_code=404)
    return rows[0]


@router.post("/results/{result_id}/save")
async def save_result(
    result_id: str,
    supabase: Annotated[SupabaseRepository, Depends(supabase_dep)],
) -> dict[str, bool]:
    await supabase.update("vibe_results", {"id": result_id}, {"is_saved": True})
    return {"saved": True}


@router.get("/playlists", response_model=PaginatedResponse)
async def list_playlists(
    supabase: Annotated[SupabaseRepository, Depends(supabase_dep)],
    userId: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    pageSize: int = Query(default=20, ge=1, le=100),
) -> PaginatedResponse:
    rows = await supabase.select(
        "generated_playlists",
        filters={"user_id": userId} if userId else None,
        limit=pageSize,
        offset=(page - 1) * pageSize,
    )
    return PaginatedResponse(
        data=rows,
        pagination={"page": page, "pageSize": pageSize, "totalItems": len(rows), "totalPages": 1},
    )


@router.get("/playlists/{playlist_id}")
async def get_playlist(
    playlist_id: str,
    supabase: Annotated[SupabaseRepository, Depends(supabase_dep)],
) -> dict:
    playlists = await supabase.select("generated_playlists", filters={"id": playlist_id}, limit=1)
    songs = await supabase.select(
        "playlist_songs",
        filters={"playlist_id": playlist_id},
        limit=50,
        order="position.asc",
    )
    if not playlists:
        raise AppError("PLAYLIST_NOT_FOUND", "Playlist was not found.", status_code=404)
    return {**playlists[0], "songs": songs}


@router.get("/filters", response_model=PaginatedResponse)
async def list_filters(
    supabase: Annotated[SupabaseRepository, Depends(supabase_dep)],
    userId: str | None = Query(default=None),
) -> PaginatedResponse:
    rows = await supabase.select(
        "saved_filters",
        filters={"user_id": userId} if userId else None,
        limit=50,
    )
    return PaginatedResponse(
        data=rows,
        pagination={"page": 1, "pageSize": 50, "totalItems": len(rows), "totalPages": 1},
    )


@router.post("/filters")
async def create_filter(
    payload: SavedFilterCreate,
    supabase: Annotated[SupabaseRepository, Depends(supabase_dep)],
) -> dict:
    return await supabase.insert(
        "saved_filters",
        {
            "user_id": payload.user_id,
            "name": payload.name,
            "brightness": payload.brightness,
            "contrast": payload.contrast,
            "saturation": payload.saturation,
            "warmth": payload.warmth,
            "fade": payload.fade,
            "grain": payload.grain,
            "vignette": payload.vignette,
            "palette_hex": payload.palette_hex,
        },
    )
