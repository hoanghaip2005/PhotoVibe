import asyncio
import base64
from urllib.parse import quote
from typing import Any

import httpx

from ..config import Settings
from ..errors import AppError


class SpotifyClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._access_token: str | None = None

    def _ensure_configured(self) -> None:
        if not self.settings.has_spotify:
            raise AppError(
                "SPOTIFY_NOT_CONFIGURED",
                "Spotify client credentials are missing.",
                status_code=503,
            )

    async def access_token(self) -> str:
        self._ensure_configured()
        if self._access_token:
            return self._access_token
        raw = f"{self.settings.spotify_client_id}:{self.settings.spotify_client_secret}"
        auth = base64.b64encode(raw.encode()).decode()
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                "https://accounts.spotify.com/api/token",
                headers={"Authorization": f"Basic {auth}"},
                data={"grant_type": "client_credentials"},
            )
        if response.status_code >= 400:
            raise AppError(
                "SPOTIFY_AUTH_FAILED",
                "Could not get Spotify access token.",
                status_code=502,
                details=response.text[:500],
            )
        self._access_token = response.json()["access_token"]
        return self._access_token

    async def playlist_tracks(
        self,
        playlist_id: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        token = await self.access_token()
        tracks: list[dict[str, Any]] = []
        url: str | None = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks"
        params: dict[str, int] | None = {"limit": min(100, limit), "offset": 0}
        async with httpx.AsyncClient(timeout=30) as client:
            while url and len(tracks) < limit:
                response = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {token}"},
                    params=params,
                )
                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", "2"))
                    await asyncio.sleep(retry_after)
                    continue
                if response.status_code >= 400:
                    raise AppError(
                        "SPOTIFY_PLAYLIST_FETCH_FAILED",
                        "Could not fetch Spotify playlist tracks.",
                        status_code=502,
                        details=response.text[:500],
                    )
                data = response.json()
                tracks.extend(data.get("items", []))
                url = data.get("next")
                params = None
                if not url:
                    break
        return tracks[:limit]

    @staticmethod
    def normalize_track(item: dict[str, Any]) -> dict[str, Any] | None:
        track = item.get("track") or {}
        if not track or not track.get("id"):
            return None
        artists = track.get("artists") or []
        artist = artists[0].get("name") if artists else "Unknown"
        album = track.get("album") or {}
        images = album.get("images") or []
        return {
            "song_id": f"spotify:track:{track['id']}",
            "track_id": track["id"],
            "title": track.get("name") or "Unknown",
            "artist": artist,
            "spotify_url": (track.get("external_urls") or {}).get("spotify"),
            "spotify_search_url": "https://open.spotify.com/search/"
            + quote(f"{track.get('name', '')} {artist}".strip()),
            "album": album.get("name"),
            "artwork": images[0].get("url") if images else None,
            "duration_ms": track.get("duration_ms"),
            "explicit": bool(track.get("explicit") or False),
        }
