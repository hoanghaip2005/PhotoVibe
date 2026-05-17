from app.config import Settings
from app.services.ingestion_service import SpotifyIngestionService


def _service() -> SpotifyIngestionService:
    return SpotifyIngestionService(
        settings=Settings(),
        spotify=object(),  # type: ignore[arg-type]
        openai=object(),  # type: ignore[arg-type]
        songs=object(),  # type: ignore[arg-type]
        supabase=object(),  # type: ignore[arg-type]
    )


def test_csv_row_builds_pgvector_song_contract() -> None:
    service = _service()
    row = {
        "title": "Forest Song",
        "artist": "Artist A",
        "spotify_url": "https://open.spotify.com/track/abc123",
        "genres": "indie|acoustic",
        "mood_tags": "calm;healing",
        "age_affinity": '{"teen": 0.4, "young_adult": 0.8, "adult": 0.7}',
        "vibe_description": "Soft green acoustic music.",
    }

    normalized = service._csv_track_document(row)
    metadata = service._csv_metadata(row)
    document = service._song_document(normalized, metadata)

    assert document["song_id"] == "spotify:track:abc123"
    assert document["spotify_search_url"].startswith("https://open.spotify.com/search/")
    assert document["genres"] == ["indie", "acoustic"]
    assert document["mood_tags"] == ["calm", "healing"]
    assert document["age_affinity"]["young_adult"] == 0.8
    assert document["$vectorize"] == "Soft green acoustic music."


def test_csv_metadata_does_not_override_generated_defaults_with_empty_cells() -> None:
    service = _service()
    provided = service._csv_metadata({"title": "A", "artist": "B"})
    generated = {
        "language": "vi",
        "popularity_tier": "mainstream",
        "energy_level": 0.7,
        "vibe_description": "Generated vibe.",
    }

    merged = service._merge_metadata(generated, provided)

    assert merged["language"] == "vi"
    assert merged["popularity_tier"] == "mainstream"
    assert merged["energy_level"] == 0.7
    assert merged["vibe_description"] == "Generated vibe."
