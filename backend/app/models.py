from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field, HttpUrl


class AgeGroup(StrEnum):
    teen = "teen"
    young_adult = "young_adult"
    adult = "adult"
    middle_age = "middle_age"
    senior = "senior"
    unknown = "unknown"


class MusicEraPreference(StrEnum):
    trending = "trending"
    modern = "modern"
    balanced = "balanced"
    classic = "classic"
    mood_based = "mood_based"


class DiscoveryLevel(StrEnum):
    familiar = "familiar"
    balanced = "balanced"
    adventurous = "adventurous"


class AnalysisMode(StrEnum):
    auto = "auto"
    music_first = "music_first"
    quote_first = "quote_first"
    filter_first = "filter_first"
    deep_mood = "deep_mood"


class UserMusicPreferences(BaseModel):
    gender: str = "unknown"
    age_group: AgeGroup = AgeGroup.unknown
    preferred_genres: list[str] = Field(default_factory=list)
    preferred_languages: list[str] = Field(default_factory=list)
    music_era_preference: MusicEraPreference = MusicEraPreference.mood_based
    favorite_artists: list[str] = Field(default_factory=list)
    favorite_songs: list[str] = Field(default_factory=list)
    explicit_content_allowed: bool = False
    discovery_level: DiscoveryLevel = DiscoveryLevel.balanced


class MoodQuote(BaseModel):
    text: str
    source: str = "VibeLens AI"
    is_ai_generated: bool = True


class FilterPreset(BaseModel):
    id: str | None = None
    name: str
    brightness: float = 0
    contrast: float = 0
    saturation: float = 0
    warmth: float = 0
    fade: float = 0
    grain: float = 0
    vignette: float = 0
    palette_hex: list[str] = Field(default_factory=list)


class VisionVibe(BaseModel):
    vibe_name: str
    description: str
    mood_tags: list[str]
    scene_tags: list[str]
    playlist_query: str
    quote: MoodQuote
    filter_preset: FilterPreset
    palette_hex: list[str]
    confidence: float = Field(ge=0, le=1)


class AgeAffinity(BaseModel):
    teen: float = 0.5
    young_adult: float = 0.5
    adult: float = 0.5
    middle_age: float = 0.5
    senior: float = 0.5


class SongCandidate(BaseModel):
    song_id: str
    title: str
    artist: str
    spotify_url: str | None = None
    spotify_search_url: str
    album: str | None = None
    genres: list[str] = Field(default_factory=list)
    mood_tags: list[str] = Field(default_factory=list)
    scene_tags: list[str] = Field(default_factory=list)
    era_tags: list[str] = Field(default_factory=list)
    language: str = "unknown"
    energy_level: float = 0.5
    valence_level: float = 0.5
    age_affinity: AgeAffinity = Field(default_factory=AgeAffinity)
    popularity_tier: str = "unknown"
    vibe_description: str = ""
    vector_similarity: float = 0.0
    explicit: bool = False


class SongResult(BaseModel):
    song_id: str | None = None
    title: str
    artist: str
    match_percent: int
    reason: str
    genres: list[str] = Field(default_factory=list)
    spotify_url: str | None = None
    spotify_search_url: str


class VibePlaylist(BaseModel):
    id: str
    name: str
    description: str
    mood_tags: list[str]
    songs: list[SongResult]


class PersonalizationInfo(BaseModel):
    age_group_used: AgeGroup = AgeGroup.unknown
    genre_preferences_used: list[str] = Field(default_factory=list)
    era_preference_used: MusicEraPreference = MusicEraPreference.mood_based
    language_preferences_used: list[str] = Field(default_factory=list)


class VibeResult(BaseModel):
    id: str
    vibe_name: str
    description: str
    mood_tags: list[str]
    scene_tags: list[str]
    confidence: float
    palette_hex: list[str]
    personalization: PersonalizationInfo
    quote: MoodQuote
    filter_preset: FilterPreset
    playlist: VibePlaylist
    created_at: str
    is_saved: bool = False


class IngestSpotifyPlaylistRequest(BaseModel):
    playlist_ids: list[str] = Field(alias="playlistIds", min_length=1)
    limit_per_playlist: int = Field(default=100, alias="limitPerPlaylist", ge=1, le=500)
    regenerate_vibe_description: bool = Field(
        default=False, alias="regenerateVibeDescription"
    )

    model_config = {"populate_by_name": True}


class IngestionResponse(BaseModel):
    imported: int
    skipped_duplicates: int = Field(alias="skippedDuplicates")
    failed: int
    collection: str

    model_config = {"populate_by_name": True}


class SavedFilterCreate(BaseModel):
    user_id: str | None = None
    anonymous_id: str | None = None
    name: str
    brightness: float = 0
    contrast: float = 0
    saturation: float = 0
    warmth: float = 0
    fade: float = 0
    grain: float = 0
    vignette: float = 0
    palette_hex: list[str] = Field(default_factory=list)


class PaginatedResponse(BaseModel):
    data: list[dict[str, Any]]
    pagination: dict[str, int]
