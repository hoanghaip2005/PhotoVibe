from app.models import AgeAffinity, AgeGroup, SongCandidate, UserMusicPreferences
from app.services.reranker import SongReranker


def test_reranker_prefers_profile_match() -> None:
    candidates = [
        SongCandidate(
            song_id="spotify:track:a",
            title="Classic Calm",
            artist="Artist A",
            spotify_search_url="https://open.spotify.com/search/a",
            genres=["bolero"],
            mood_tags=["calm"],
            era_tags=["classic"],
            language="vi",
            age_affinity=AgeAffinity(teen=0.2, young_adult=0.4, adult=0.7, middle_age=0.9, senior=0.9),
            vector_similarity=0.8,
        ),
        SongCandidate(
            song_id="spotify:track:b",
            title="Neon Calm",
            artist="Artist B",
            spotify_search_url="https://open.spotify.com/search/b",
            genres=["edm"],
            mood_tags=["calm"],
            era_tags=["trending", "2020s"],
            language="en",
            age_affinity=AgeAffinity(teen=0.9, young_adult=0.8, adult=0.4, middle_age=0.2, senior=0.1),
            vector_similarity=0.8,
        ),
    ]

    result = SongReranker().rerank(
        candidates,
        mood_tags=["calm"],
        preferences=UserMusicPreferences(
            age_group=AgeGroup.middle_age,
            preferred_genres=["bolero"],
            preferred_languages=["vi"],
            music_era_preference="classic",
        ),
        limit=2,
    )

    assert result[0].title == "Classic Calm"
    assert "gu" in result[0].reason
