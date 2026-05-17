import base64
import json
from typing import Any

from openai import APIConnectionError, APIStatusError, AsyncOpenAI, RateLimitError

from ..config import Settings
from ..errors import AppError
from ..models import FilterPreset, MoodQuote, UserMusicPreferences, VisionVibe


VISION_PROMPT = """You are VibeLens AI, a visual mood and music recommendation assistant.

Analyze the uploaded image as a moment, not as a diagnosis of the user.
Return Vietnamese JSON only.

Your task:
1. Describe the overall vibe of the image.
2. Identify mood tags and scene tags.
3. Create a playlistQuery that can be used to search a vector database of songs.
4. Generate one short AI quote in Vietnamese.
5. Generate one color filter preset.
6. Extract or infer a color palette.
7. Return confidence from 0 to 1.

Rules:
- Do not infer gender; use self-declared gender only as a soft preference context.
- Do not stereotype by age.
- Use gender, age, and preferences only as soft personalization signals.
- Do not diagnose mental health.
- Do not infer sensitive traits.
- Use "khoảnh khắc này" instead of "bạn".
- Quote source must be "VibeLens AI".
- Output JSON only with camelCase keys.
"""

SONG_TAGGER_PROMPT = """You are VibeLens Music Tagger.

Create metadata for a song so it can be searched by visual vibe.
Return JSON only. Do not invent copyrighted lyrics. Use broad suitability, not stereotypes.
"""

VISION_JSON_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "vibeName",
        "description",
        "moodTags",
        "sceneTags",
        "playlistQuery",
        "quote",
        "filterPreset",
        "paletteHex",
        "confidence",
    ],
    "properties": {
        "vibeName": {"type": "string"},
        "description": {"type": "string"},
        "moodTags": {"type": "array", "items": {"type": "string"}},
        "sceneTags": {"type": "array", "items": {"type": "string"}},
        "playlistQuery": {"type": "string"},
        "quote": {
            "type": "object",
            "additionalProperties": False,
            "required": ["text", "source", "isAiGenerated"],
            "properties": {
                "text": {"type": "string"},
                "source": {"type": "string"},
                "isAiGenerated": {"type": "boolean"},
            },
        },
        "filterPreset": {
            "type": "object",
            "additionalProperties": False,
            "required": [
                "name",
                "brightness",
                "contrast",
                "saturation",
                "warmth",
                "fade",
                "grain",
                "vignette",
            ],
            "properties": {
                "name": {"type": "string"},
                "brightness": {"type": "number"},
                "contrast": {"type": "number"},
                "saturation": {"type": "number"},
                "warmth": {"type": "number"},
                "fade": {"type": "number"},
                "grain": {"type": "number"},
                "vignette": {"type": "number"},
            },
        },
        "paletteHex": {"type": "array", "items": {"type": "string"}},
        "confidence": {"type": "number"},
    },
}

SONG_TAGGER_JSON_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "vibe_description",
        "genres",
        "mood_tags",
        "scene_tags",
        "era_tags",
        "language",
        "energy_level",
        "valence_level",
        "age_affinity",
        "popularity_tier",
    ],
    "properties": {
        "vibe_description": {"type": "string"},
        "genres": {"type": "array", "items": {"type": "string"}},
        "mood_tags": {"type": "array", "items": {"type": "string"}},
        "scene_tags": {"type": "array", "items": {"type": "string"}},
        "era_tags": {"type": "array", "items": {"type": "string"}},
        "language": {"type": "string"},
        "energy_level": {"type": "number"},
        "valence_level": {"type": "number"},
        "age_affinity": {
            "type": "object",
            "additionalProperties": False,
            "required": ["teen", "young_adult", "adult", "middle_age", "senior"],
            "properties": {
                "teen": {"type": "number"},
                "young_adult": {"type": "number"},
                "adult": {"type": "number"},
                "middle_age": {"type": "number"},
                "senior": {"type": "number"},
            },
        },
        "popularity_tier": {"type": "string"},
    },
}


class OpenAIVibeService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._client = AsyncOpenAI(api_key=settings.openai_api_key) if settings.has_openai else None

    def _ensure_configured(self) -> AsyncOpenAI:
        if self._client is None:
            raise AppError(
                "OPENAI_NOT_CONFIGURED",
                "OpenAI API key is missing.",
                status_code=503,
            )
        return self._client

    async def analyze_image(
        self,
        image_bytes: bytes,
        mime_type: str,
        hint: str,
        mood_hints: list[str],
        analysis_mode: str,
        preferences: UserMusicPreferences,
    ) -> VisionVibe:
        client = self._ensure_configured()
        data_url = f"data:{mime_type};base64,{base64.b64encode(image_bytes).decode('ascii')}"
        profile = preferences.model_dump()
        user_text = {
            "hint": hint,
            "moodHints": mood_hints,
            "analysisMode": analysis_mode,
            "userProfile": profile,
        }
        try:
            response = await client.responses.create(
                model=self.settings.openai_vision_model,
                text={
                    "format": {
                        "type": "json_schema",
                        "name": "vibelens_vision_result",
                        "schema": VISION_JSON_SCHEMA,
                        "strict": True,
                    }
                },
                input=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "input_text", "text": VISION_PROMPT},
                            {"type": "input_text", "text": json.dumps(user_text, ensure_ascii=False)},
                            {"type": "input_image", "image_url": data_url},
                        ],
                    }
                ],
            )
        except RateLimitError as exc:
            raise AppError(
                "OPENAI_QUOTA_EXCEEDED",
                "OpenAI quota is exhausted or billing is not enabled for this project.",
                status_code=429,
                details=self._openai_error_detail(exc),
            ) from exc
        except APIConnectionError as exc:
            raise AppError(
                "OPENAI_CONNECTION_FAILED",
                "Could not connect to OpenAI.",
                status_code=502,
                details=str(exc)[:300],
            ) from exc
        except APIStatusError as exc:
            raise AppError(
                "OPENAI_REQUEST_FAILED",
                "OpenAI rejected the analysis request.",
                status_code=502,
                details=self._openai_error_detail(exc),
            ) from exc
        text = getattr(response, "output_text", "") or ""
        return self._parse_vision_json(text)

    async def tag_song(
        self,
        title: str,
        artist: str,
        album: str | None,
        genres: list[str],
        playlist_context: str | None = None,
    ) -> dict[str, Any]:
        client = self._ensure_configured()
        payload = {
            "title": title,
            "artist": artist,
            "album": album,
            "genres": genres,
            "playlistContext": playlist_context,
        }
        try:
            response = await client.responses.create(
                model=self.settings.openai_ingestion_model,
                text={
                    "format": {
                        "type": "json_schema",
                        "name": "vibelens_song_metadata",
                        "schema": SONG_TAGGER_JSON_SCHEMA,
                        "strict": True,
                    }
                },
                input=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "input_text", "text": SONG_TAGGER_PROMPT},
                            {"type": "input_text", "text": json.dumps(payload, ensure_ascii=False)},
                        ],
                    }
                ],
            )
        except RateLimitError as exc:
            raise AppError(
                "OPENAI_QUOTA_EXCEEDED",
                "OpenAI quota is exhausted or billing is not enabled for this project.",
                status_code=429,
                details=self._openai_error_detail(exc),
            ) from exc
        except APIConnectionError as exc:
            raise AppError(
                "OPENAI_CONNECTION_FAILED",
                "Could not connect to OpenAI.",
                status_code=502,
                details=str(exc)[:300],
            ) from exc
        except APIStatusError as exc:
            raise AppError(
                "OPENAI_REQUEST_FAILED",
                "OpenAI rejected the song tagging request.",
                status_code=502,
                details=self._openai_error_detail(exc),
            ) from exc
        text = getattr(response, "output_text", "") or ""
        try:
            return json.loads(self._strip_code_fence(text))
        except json.JSONDecodeError as exc:
            raise AppError(
                "SONG_TAGGER_PARSE_FAILED",
                "Could not parse song metadata JSON from LLM.",
                status_code=502,
                details=str(exc),
            ) from exc

    async def embed_text(self, text: str) -> list[float]:
        client = self._ensure_configured()
        try:
            response = await client.embeddings.create(
                model=self.settings.openai_embedding_model,
                input=text,
            )
        except RateLimitError as exc:
            raise AppError(
                "OPENAI_QUOTA_EXCEEDED",
                "OpenAI quota is exhausted or billing is not enabled for this project.",
                status_code=429,
                details=self._openai_error_detail(exc),
            ) from exc
        except APIConnectionError as exc:
            raise AppError(
                "OPENAI_CONNECTION_FAILED",
                "Could not connect to OpenAI embeddings.",
                status_code=502,
                details=str(exc)[:300],
            ) from exc
        except APIStatusError as exc:
            raise AppError(
                "OPENAI_EMBEDDING_FAILED",
                "OpenAI rejected the embedding request.",
                status_code=502,
                details=self._openai_error_detail(exc),
            ) from exc
        if not response.data:
            raise AppError(
                "EMBEDDING_FAILED",
                "OpenAI did not return an embedding.",
                status_code=502,
            )
        return list(response.data[0].embedding)

    def _parse_vision_json(self, text: str) -> VisionVibe:
        try:
            raw = json.loads(self._strip_code_fence(text))
        except json.JSONDecodeError as exc:
            raise AppError(
                "VISION_PARSE_FAILED",
                "Could not parse Vibe JSON from AI response.",
                status_code=502,
                details=str(exc),
            ) from exc
        if not isinstance(raw, dict):
            raise AppError(
                "VISION_PARSE_FAILED",
                "AI response was not a JSON object.",
                status_code=502,
            )
        missing = [
            key
            for key in (
                "vibeName",
                "description",
                "playlistQuery",
                "quote",
                "filterPreset",
            )
            if key not in raw
        ]
        if missing:
            raise AppError(
                "VISION_SCHEMA_MISMATCH",
                "AI response missed required VibeLens fields.",
                status_code=502,
                details={"missing": missing, "keys": sorted(raw.keys())},
            )
        filter_raw = raw.get("filterPreset") or raw.get("filter_preset") or {}
        quote_raw = raw.get("quote") or {}
        return VisionVibe(
            vibe_name=raw["vibeName"],
            description=raw["description"],
            mood_tags=list(raw.get("moodTags") or []),
            scene_tags=list(raw.get("sceneTags") or []),
            playlist_query=raw["playlistQuery"],
            quote=MoodQuote(
                text=quote_raw.get("text", ""),
                source="VibeLens AI",
                is_ai_generated=True,
            ),
            filter_preset=FilterPreset(
                name=filter_raw.get("name", "VibeLens Filter"),
                brightness=float(filter_raw.get("brightness", 0)),
                contrast=float(filter_raw.get("contrast", 0)),
                saturation=float(filter_raw.get("saturation", 0)),
                warmth=float(filter_raw.get("warmth", 0)),
                fade=float(filter_raw.get("fade", 0)),
                grain=float(filter_raw.get("grain", 0)),
                vignette=float(filter_raw.get("vignette", 0)),
                palette_hex=list(raw.get("paletteHex") or []),
            ),
            palette_hex=list(raw.get("paletteHex") or []),
            confidence=float(raw.get("confidence", 0.75)),
        )

    @staticmethod
    def _strip_code_fence(text: str) -> str:
        value = text.strip()
        if value.startswith("```"):
            value = value.removeprefix("```json").removeprefix("```").strip()
            value = value.removesuffix("```").strip()
        return value

    @staticmethod
    def _openai_error_detail(exc: APIStatusError) -> str:
        try:
            return exc.response.text[:500]
        except Exception:
            return str(exc)[:500]
