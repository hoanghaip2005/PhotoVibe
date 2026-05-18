import base64
import json
from typing import Any

import httpx

from ..config import Settings
from ..errors import AppError
from ..models import UserMusicPreferences, VisionVibe
from .openai_service import OpenAIVibeService, SONG_TAGGER_PROMPT, VISION_PROMPT


class GeminiVibeService(OpenAIVibeService):
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def analyze_image(
        self,
        image_bytes: bytes,
        mime_type: str,
        hint: str,
        mood_hints: list[str],
        analysis_mode: str,
        preferences: UserMusicPreferences,
    ) -> VisionVibe:
        user_text = {
            "hint": hint,
            "moodHints": mood_hints,
            "analysisMode": analysis_mode,
            "userProfile": preferences.model_dump(),
        }
        text = await self._generate_json(
            model=self.settings.gemini_vision_model,
            parts=[
                {"text": VISION_PROMPT},
                {"text": json.dumps(user_text, ensure_ascii=False)},
                {
                    "inlineData": {
                        "mimeType": mime_type,
                        "data": base64.b64encode(image_bytes).decode("ascii"),
                    }
                },
            ],
        )
        return self._parse_vision_json(text)

    async def tag_song(
        self,
        title: str,
        artist: str,
        album: str | None,
        genres: list[str],
        playlist_context: str | None = None,
    ) -> dict[str, Any]:
        payload = {
            "title": title,
            "artist": artist,
            "album": album,
            "genres": genres,
            "playlistContext": playlist_context,
        }
        text = await self._generate_json(
            model=self.settings.gemini_ingestion_model,
            parts=[
                {"text": SONG_TAGGER_PROMPT},
                {"text": json.dumps(payload, ensure_ascii=False)},
            ],
        )
        try:
            return json.loads(self._strip_code_fence(text))
        except json.JSONDecodeError as exc:
            raise AppError(
                "SONG_TAGGER_PARSE_FAILED",
                "Could not parse song metadata JSON from Gemini.",
                status_code=502,
                details=str(exc),
            ) from exc

    async def _generate_json(self, model: str, parts: list[dict[str, Any]]) -> str:
        if not self.settings.has_gemini:
            raise AppError(
                "GEMINI_NOT_CONFIGURED",
                "GEMINI_API_KEY is missing.",
                status_code=503,
            )
        model_name = model.removeprefix("models/")
        payload = {
            "contents": [{"role": "user", "parts": parts}],
            "generationConfig": {"responseMimeType": "application/json"},
        }
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent",
                params={"key": self.settings.gemini_api_key},
                json=payload,
            )
        if response.status_code >= 400:
            raise AppError(
                "GEMINI_REQUEST_FAILED",
                "Gemini rejected the generation request.",
                status_code=502,
                details=response.text[:500],
            )
        data = response.json()
        try:
            parts = data["candidates"][0]["content"]["parts"]
            text = "".join(str(part.get("text") or "") for part in parts)
        except (KeyError, IndexError, TypeError) as exc:
            raise AppError(
                "GEMINI_RESPONSE_MISSING_TEXT",
                "Gemini did not return text output.",
                status_code=502,
                details=json.dumps(data)[:500],
            ) from exc
        return text
