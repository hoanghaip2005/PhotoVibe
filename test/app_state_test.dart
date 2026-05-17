import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibelens/models/analysis_preferences.dart';
import 'package:vibelens/models/capture_input.dart';
import 'package:vibelens/models/filter_preset.dart';
import 'package:vibelens/models/mood_quote.dart';
import 'package:vibelens/models/playlist.dart';
import 'package:vibelens/models/song.dart';
import 'package:vibelens/models/user_preferences.dart';
import 'package:vibelens/models/vibe_result.dart';
import 'package:vibelens/services/vibe_analyzer.dart';
import 'package:vibelens/state/app_state.dart';

void main() {
  test('saves analyzed backend result to diary persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = VibeAppState(preferences: prefs, analyzer: _FakeAnalyzer())
      ..load();

    state.startCapture(
      CaptureInput(
        id: 'capture_test',
        type: CaptureType.image,
        mediaPaths: const ['memory://image.jpg'],
        createdAt: DateTime(2026, 5, 16),
      ),
      mediaBytes: Uint8List.fromList([1, 2, 3]),
    );
    state.updateAnalysisPreferences(
      const AnalysisPreferences(
        hint: 'rừng chiều',
        mode: AnalysisMode.autoVibe,
        moodHints: ['Healing'],
      ),
    );

    final result = await state.analyzeCurrentCapture();
    expect(result, isNotNull);

    await state.saveResult(result!.id);
    expect(state.diaryEntries, hasLength(1));

    final reloaded = VibeAppState(preferences: prefs, analyzer: _FakeAnalyzer())
      ..load();
    expect(reloaded.diaryEntries, hasLength(1));
  });

  test('persists local email sign in state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = VibeAppState(preferences: prefs, analyzer: _FakeAnalyzer())
      ..load();

    await state.signInWithEmail(email: 'lan@example.com', displayName: 'Lan');

    expect(state.authPromptCompleted, isTrue);
    expect(state.userPreferences.isSignedIn, isTrue);
    expect(state.userPreferences.email, 'lan@example.com');

    final reloaded = VibeAppState(preferences: prefs, analyzer: _FakeAnalyzer())
      ..load();
    expect(reloaded.authPromptCompleted, isTrue);
    expect(reloaded.userPreferences.isSignedIn, isTrue);
    expect(reloaded.userPreferences.displayName, 'Lan');
  });
}

class _FakeAnalyzer implements VibeAnalyzer {
  @override
  Future<VibeResult> analyze({
    required CaptureInput capture,
    required AnalysisPreferences preferences,
    required UserPreferences userPreferences,
    Uint8List? mediaBytes,
  }) async {
    return VibeResult(
      id: 'result_test',
      capture: capture,
      vibeName: 'Forest Healing',
      description: 'Đã cá nhân hóa theo vibe ảnh và gu nghe nhạc của bạn.',
      moodTags: const ['healing', 'calm'],
      sceneTags: const ['forest'],
      confidence: 0.9,
      paletteHex: const ['#355E3B', '#8FBC8F'],
      playlist: const VibePlaylist(
        id: 'playlist_test',
        name: 'Forest Healing Mix',
        description: 'Đã cá nhân hóa theo vibe ảnh và gu nghe nhạc của bạn.',
        moodTags: ['healing'],
        paletteHex: ['#355E3B', '#8FBC8F'],
        songs: [
          Song(
            title: 'Song',
            artist: 'Artist',
            matchPercent: 91,
            reason: 'Hợp với vibe ảnh và gu indie.',
            genres: ['indie'],
            spotifySearchUrl: 'https://open.spotify.com/search/Song%20Artist',
          ),
        ],
      ),
      quote: const MoodQuote(
        text: 'Có những ngày chỉ cần một khoảng xanh.',
        source: 'VibeLens AI',
        isAiGenerated: true,
      ),
      filters: const [
        FilterPreset(
          id: 'filter_test',
          name: 'Forest Glow',
          paletteHex: ['#355E3B', '#8FBC8F'],
          brightness: 0.1,
          contrast: 0.1,
          saturation: 0.1,
          warmth: 0,
          fade: 0,
          grain: 0,
          vignette: 0,
        ),
      ],
      createdAt: DateTime(2026, 5, 16),
    );
  }
}
