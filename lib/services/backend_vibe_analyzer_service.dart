import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/analysis_preferences.dart';
import '../models/capture_input.dart';
import '../models/filter_preset.dart';
import '../models/mood_quote.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/user_preferences.dart';
import '../models/vibe_result.dart';
import 'vibe_analyzer.dart';

class BackendVibeAnalyzerService implements VibeAnalyzer {
  BackendVibeAnalyzerService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          (baseUrl ?? const String.fromEnvironment('VIBELENS_API_BASE_URL'))
              .trim()
              .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<VibeResult> analyze({
    required CaptureInput capture,
    required AnalysisPreferences preferences,
    required UserPreferences userPreferences,
    Uint8List? mediaBytes,
  }) async {
    if (_baseUrl.isEmpty) {
      throw const VibeAnalyzerException(
        'Thiếu VIBELENS_API_BASE_URL. Hãy cấu hình backend production bằng --dart-define.',
      );
    }
    if (_baseUrl.contains('example.com') || _baseUrl.contains('your-domain')) {
      throw const VibeAnalyzerException(
        'Backend chưa được cấu hình. Hãy build lại với VIBELENS_API_BASE_URL trỏ đến API thật.',
      );
    }
    if (mediaBytes == null || mediaBytes.isEmpty) {
      throw const VibeAnalyzerException(
        'Cần ảnh thật để gửi backend production.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/analyze'),
    );
    request.fields.addAll({
      'hint': preferences.hint,
      'analysisMode': preferences.mode.apiValue,
      'anonymousId': userPreferences.anonymousId,
      'saveResult': 'false',
      'moodHintsJson': jsonEncode(preferences.moodHints),
      'userProfileJson': jsonEncode(userPreferences.toBackendJson()),
    });

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        mediaBytes,
        filename: 'vibelens-image.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final http.Response response;
    try {
      final streamed = await _client.send(request);
      response = await http.Response.fromStream(streamed);
    } on http.ClientException catch (error) {
      throw VibeAnalyzerException(
        'Không kết nối được backend VibeLens ($_baseUrl). Hãy kiểm tra API đang chạy và CORS đã cho phép web app. ${error.message}',
      );
    }
    if (response.statusCode >= 400) {
      throw VibeAnalyzerException(_errorMessage(response));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _resultFromBackend(data, capture);
  }

  VibeResult _resultFromBackend(
    Map<String, dynamic> json,
    CaptureInput capture,
  ) {
    final palette = _stringList(json['palette_hex']);
    final filterJson = json['filter_preset'] as Map<String, dynamic>? ?? {};
    final playlistJson = json['playlist'] as Map<String, dynamic>? ?? {};
    final songs = (playlistJson['songs'] as List<dynamic>? ?? const [])
        .map((item) => _songFromBackend(item as Map<String, dynamic>))
        .toList();
    final filter = FilterPreset(
      id: filterJson['id'] as String? ?? 'backend_filter',
      name: filterJson['name'] as String? ?? 'VibeLens Filter',
      paletteHex: _stringList(filterJson['palette_hex']).isEmpty
          ? palette
          : _stringList(filterJson['palette_hex']),
      brightness: _double(filterJson['brightness']),
      contrast: _double(filterJson['contrast']),
      saturation: _double(filterJson['saturation']),
      warmth: _double(filterJson['warmth']),
      fade: _double(filterJson['fade']),
      grain: _double(filterJson['grain']),
      vignette: _double(filterJson['vignette']),
    );
    return VibeResult(
      id: json['id'] as String,
      capture: capture,
      vibeName: json['vibe_name'] as String,
      description: json['description'] as String,
      moodTags: _stringList(json['mood_tags']),
      sceneTags: _stringList(json['scene_tags']),
      confidence: _double(json['confidence']),
      paletteHex: palette,
      playlist: VibePlaylist(
        id: playlistJson['id'] as String,
        name: playlistJson['name'] as String,
        description:
            playlistJson['description'] as String? ??
            'Đã cá nhân hóa theo vibe ảnh và gu nghe nhạc của bạn.',
        moodTags: _stringList(playlistJson['mood_tags']),
        paletteHex: palette,
        songs: songs,
        spotifyUrl: songs.isEmpty
            ? null
            : (songs.first.spotifyUrl ?? songs.first.spotifySearchUrl),
      ),
      quote: MoodQuote(
        text:
            (json['quote'] as Map<String, dynamic>?)?['text'] as String? ?? '',
        source: 'VibeLens AI',
        isAiGenerated: true,
      ),
      filters: [filter],
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  Song _songFromBackend(Map<String, dynamic> json) {
    return Song(
      title: json['title'] as String,
      artist: json['artist'] as String,
      matchPercent: json['match_percent'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      genres: _stringList(json['genres']),
      spotifyUrl: json['spotify_url'] as String?,
      spotifySearchUrl: json['spotify_search_url'] as String?,
    );
  }

  List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
  }

  double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      return error?['message'] as String? ?? 'Backend analyze failed.';
    } catch (_) {
      return 'Backend analyze failed (${response.statusCode}).';
    }
  }
}

class VibeAnalyzerException implements Exception {
  const VibeAnalyzerException(this.message);

  final String message;

  @override
  String toString() => message;
}
