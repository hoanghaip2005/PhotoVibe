import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibelens/core/router/app_router.dart';
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
  test('router is stable when capture state changes', () async {
    SharedPreferences.setMockInitialValues({
      'vibelens.onboardingCompleted': true,
      'vibelens.authPromptCompleted': true,
      'vibelens.musicProfileCompleted': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        vibeAnalyzerProvider.overrideWithValue(_FakeAnalyzer()),
      ],
    );
    addTearDown(container.dispose);

    final routerBefore = container.read(appRouterProvider);
    container
        .read(appStateProvider)
        .startCapture(
          CaptureInput(
            id: 'capture_test',
            type: CaptureType.image,
            mediaPaths: const ['memory://image.jpg'],
            createdAt: DateTime(2026, 5, 17),
          ),
          mediaBytes: Uint8List.fromList([1, 2, 3]),
        );
    final routerAfter = container.read(appRouterProvider);

    expect(routerAfter, same(routerBefore));
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
      description: 'Da ca nhan hoa theo vibe anh va gu nghe nhac cua ban.',
      moodTags: const ['healing', 'calm'],
      sceneTags: const ['forest'],
      confidence: 0.9,
      paletteHex: const ['#355E3B', '#8FBC8F'],
      playlist: const VibePlaylist(
        id: 'playlist_test',
        name: 'Forest Healing Mix',
        description: 'Da ca nhan hoa theo vibe anh va gu nghe nhac cua ban.',
        moodTags: ['healing'],
        paletteHex: ['#355E3B', '#8FBC8F'],
        songs: [
          Song(
            title: 'Song',
            artist: 'Artist',
            matchPercent: 91,
            reason: 'Hop voi vibe anh va gu indie.',
            genres: ['indie'],
            spotifySearchUrl: 'https://open.spotify.com/search/Song%20Artist',
          ),
        ],
      ),
      quote: const MoodQuote(
        text: 'Co nhung ngay chi can mot khoang xanh.',
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
      createdAt: DateTime(2026, 5, 17),
    );
  }
}
