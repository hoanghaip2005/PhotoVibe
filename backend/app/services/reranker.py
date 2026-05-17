from collections import Counter

from ..models import AgeGroup, MusicEraPreference, SongCandidate, SongResult, UserMusicPreferences


class SongReranker:
    def rerank(
        self,
        candidates: list[SongCandidate],
        mood_tags: list[str],
        preferences: UserMusicPreferences,
        limit: int = 8,
    ) -> list[SongResult]:
        scored: list[tuple[float, SongCandidate, dict[str, float]]] = []
        artist_counts: Counter[str] = Counter()
        genre_counts: Counter[str] = Counter()

        for candidate in candidates:
            components = self._score_components(candidate, mood_tags, preferences)
            penalty = 0.0
            if candidate.explicit and not preferences.explicit_content_allowed:
                penalty += 0.35
            if artist_counts[candidate.artist.lower()] >= 1:
                penalty += 0.08
            primary_genre = candidate.genres[0].lower() if candidate.genres else ""
            if primary_genre and genre_counts[primary_genre] >= 3:
                penalty += 0.05

            final_score = (
                0.45 * components["vector"]
                + 0.20 * components["mood"]
                + 0.15 * components["genre"]
                + 0.10 * components["age"]
                + 0.05 * components["era"]
                + 0.05 * components["language"]
                - penalty
            )
            scored.append((max(0.0, min(final_score, 1.0)), candidate, components))
            artist_counts[candidate.artist.lower()] += 1
            if primary_genre:
                genre_counts[primary_genre] += 1

        scored.sort(key=lambda item: item[0], reverse=True)
        return [
            SongResult(
                song_id=candidate.song_id,
                title=candidate.title,
                artist=candidate.artist,
                match_percent=max(50, min(99, round(score * 100))),
                reason=self._reason(candidate, mood_tags, preferences, components),
                genres=candidate.genres,
                spotify_url=candidate.spotify_url,
                spotify_search_url=candidate.spotify_search_url,
            )
            for score, candidate, components in scored[:limit]
        ]

    def _score_components(
        self,
        candidate: SongCandidate,
        mood_tags: list[str],
        preferences: UserMusicPreferences,
    ) -> dict[str, float]:
        mood = self._overlap_score(mood_tags, candidate.mood_tags + candidate.scene_tags)
        genre = self._overlap_score(preferences.preferred_genres, candidate.genres)
        language = 0.5
        if preferences.preferred_languages:
            language = 1.0 if candidate.language in preferences.preferred_languages else 0.2
        era = self._era_score(candidate.era_tags, preferences.music_era_preference)
        age = self._age_score(candidate, preferences.age_group)
        vector = candidate.vector_similarity or 0.5
        return {
            "vector": max(0, min(vector, 1)),
            "mood": mood,
            "genre": genre,
            "age": age,
            "era": era,
            "language": language,
        }

    def _overlap_score(self, desired: list[str], actual: list[str]) -> float:
        if not desired:
            return 0.5
        desired_set = {item.lower().strip() for item in desired if item.strip()}
        actual_set = {item.lower().strip() for item in actual if item.strip()}
        if not desired_set:
            return 0.5
        return len(desired_set & actual_set) / len(desired_set)

    def _age_score(self, candidate: SongCandidate, age_group: AgeGroup) -> float:
        if age_group == AgeGroup.unknown:
            return 0.5
        return float(getattr(candidate.age_affinity, age_group.value, 0.5))

    def _era_score(self, era_tags: list[str], preference: MusicEraPreference) -> float:
        tags = {tag.lower() for tag in era_tags}
        if preference in (MusicEraPreference.balanced, MusicEraPreference.mood_based):
            return 0.5
        if preference == MusicEraPreference.trending:
            return 1.0 if "trending" in tags or "2020s" in tags else 0.35
        if preference == MusicEraPreference.modern:
            return 1.0 if tags & {"modern", "modern_indie", "2010s", "2020s"} else 0.45
        if preference == MusicEraPreference.classic:
            return 1.0 if tags & {"classic", "oldies", "1990s", "2000s"} else 0.35
        return 0.5

    def _reason(
        self,
        candidate: SongCandidate,
        mood_tags: list[str],
        preferences: UserMusicPreferences,
        components: dict[str, float],
    ) -> str:
        mood = ", ".join(mood_tags[:2]) or "vibe ảnh"
        clauses = [f"Hợp với vibe {mood}"]
        if components["genre"] > 0:
            clauses.append("khớp gu " + "/".join(preferences.preferred_genres[:2]))
        if components["language"] > 0.7 and preferences.preferred_languages:
            clauses.append("đúng ngôn ngữ nhạc bạn ưu tiên")
        if components["era"] > 0.7:
            clauses.append("hợp gu nhạc mới/cũ của bạn")
        if components["genre"] == 0 and not preferences.preferred_genres:
            clauses.append("dựa trên mood và bối cảnh ảnh")
        return ", ".join(clauses) + "."
