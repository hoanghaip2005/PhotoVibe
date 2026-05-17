from scripts.seed_itunes_search import build_work_items, track_to_document
from scripts.seed_spotify_search import QuerySpec


def _spec() -> QuerySpec:
    return QuerySpec(
        query="indie pop sunset",
        genres=("indie", "pop"),
        mood_tags=("sunset", "hopeful"),
        scene_tags=("sunset", "drive"),
        era_tags=("modern", "2020s"),
        language="en",
        energy=0.5,
        valence=0.65,
        description="indie pop music for sunset visual moments.",
    )


def test_itunes_track_builds_pgvector_song_contract() -> None:
    track = {
        "trackId": 12345,
        "kind": "song",
        "trackName": "Golden Hour",
        "artistName": "Artist A",
        "collectionName": "Evening Album",
        "primaryGenreName": "Alternative",
        "trackTimeMillis": 210000,
        "trackExplicitness": "notExplicit",
        "releaseDate": "2024-04-01T12:00:00Z",
        "artworkUrl100": "https://example.test/100x100bb.jpg",
        "trackViewUrl": "https://music.apple.com/us/album/golden-hour/12345",
    }

    document = track_to_document(track, _spec(), "US")

    assert document is not None
    assert document.song_id == "itunes:track:12345"
    assert document.spotify_url == ""
    assert document.spotify_search_url.startswith("https://open.spotify.com/search/")
    assert document.genres == ["indie", "pop", "alternative"]
    assert "2024" in document.era_tags
    assert document.age_affinity["young_adult"] > 0.5
    assert "Apple iTunes Search API" in document.vibe_description


def test_itunes_work_items_prioritize_language_specific_countries() -> None:
    items = build_work_items([])

    first_vi = next(item for item in items if item.spec.language == "vi")
    first_ko = next(item for item in items if item.spec.language == "ko")

    assert first_vi.country == "VN"
    assert first_ko.country == "KR"
